#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Khong tim thay file .env tai $ENV_FILE"
    echo "Hay copy .env.example thanh .env va dien IP:"
    echo "  cp .env.example .env && nano .env"
    exit 1
fi

source "$ENV_FILE"

if [ -z "$MASTER_IP" ] || [ -z "$WORKER1_IP" ] || [ -z "$WORKER2_IP" ]; then
    echo "ERROR: Thieu MASTER_IP, WORKER1_IP hoac WORKER2_IP trong .env"
    exit 1
fi

SSH_USER="${SSH_USER:-ubuntu}"
HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
JAVA_HOME_PATH="${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}"

TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

cat > "$TMP_DIR/core-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${MASTER_IP}:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/opt/hadoop/tmp</value>
    </property>
</configuration>
EOF

cat > "$TMP_DIR/hdfs-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>/opt/hadoop/data/nameNode</value>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>/opt/hadoop/data/dataNode</value>
    </property>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.namenode.rpc-bind-host</name>
        <value>0.0.0.0</value>
    </property>
    <property>
        <name>dfs.namenode.http-bind-host</name>
        <value>0.0.0.0</value>
    </property>
</configuration>
EOF

cat > "$TMP_DIR/yarn-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>yarn.acl.enable</name>
        <value>0</value>
    </property>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>${MASTER_IP}</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>1536</value>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>1536</value>
    </property>
    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>128</value>
    </property>
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>yarn.nodemanager.pmem-check-enabled</name>
        <value>false</value>
    </property>
</configuration>
EOF

cat > "$TMP_DIR/mapred-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>
    </property>
    <property>
        <name>mapreduce.map.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>
    </property>
    <property>
        <name>mapreduce.reduce.env</name>
        <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.resource.mb</name>
        <value>512</value>
    </property>
    <property>
        <name>mapreduce.map.memory.mb</name>
        <value>512</value>
    </property>
    <property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>512</value>
    </property>
</configuration>
EOF

printf "%s\n" "$WORKER1_IP" "$WORKER2_IP" > "$TMP_DIR/workers"

cat > "$TMP_DIR/hadoop-env.sh" <<EOF
export JAVA_HOME=${JAVA_HOME_PATH}
export HADOOP_HOME=${HADOOP_HOME}
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
EOF

echo "=== Cau hinh Hadoop Cluster ==="
echo "Master  : $MASTER_IP"
echo "Worker 1: $WORKER1_IP"
echo "Worker 2: $WORKER2_IP"
echo "SSH User: $SSH_USER"
echo "HADOOP  : $HADOOP_HOME"
echo "JAVA    : $JAVA_HOME_PATH"
echo ""

echo "[1/3] Cap nhat cau hinh tren Master ($MASTER_IP)..."
sudo mkdir -p "$HADOOP_CONF_DIR"
sudo cp "$TMP_DIR"/*.xml "$TMP_DIR/workers" "$HADOOP_CONF_DIR/"
echo "  -> Da cap nhat $HADOOP_CONF_DIR/"

echo "[2/3] Dong bo cau hinh sang Worker 1 ($WORKER1_IP)..."
rsync -avz --delete \
    "$TMP_DIR/core-site.xml" \
    "$TMP_DIR/hdfs-site.xml" \
    "$TMP_DIR/yarn-site.xml" \
    "$TMP_DIR/mapred-site.xml" \
    "$TMP_DIR/workers" \
    "$TMP_DIR/hadoop-env.sh" \
    ${SSH_USER}@${WORKER1_IP}:${HADOOP_CONF_DIR}/
echo "  -> Done Worker 1"

echo "[3/3] Dong bo cau hinh sang Worker 2 ($WORKER2_IP)..."
rsync -avz --delete \
    "$TMP_DIR/core-site.xml" \
    "$TMP_DIR/hdfs-site.xml" \
    "$TMP_DIR/yarn-site.xml" \
    "$TMP_DIR/mapred-site.xml" \
    "$TMP_DIR/workers" \
    "$TMP_DIR/hadoop-env.sh" \
    ${SSH_USER}@${WORKER2_IP}:${HADOOP_CONF_DIR}/
echo "  -> Done Worker 2"

echo ""
echo "=== HOAN THANH: Cau hinh da dong bo len ca 3 nodes ==="
