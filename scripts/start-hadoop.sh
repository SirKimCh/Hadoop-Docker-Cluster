#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi

JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}"
HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
SSH_USER="${SSH_USER:-ubuntu}"

if [ ! -d "$JAVA_HOME" ]; then
    echo "ERROR: Khong tim thay Java tai $JAVA_HOME"
    echo "Hay cai dat: sudo apt install -y openjdk-8-jdk"
    exit 1
fi

if [ ! -d "$HADOOP_HOME" ]; then
    echo "ERROR: Khong tim thay Hadoop tai $HADOOP_HOME"
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Hadoop daemon can chi chay voi root. Tu dong chay lai voi sudo..."
    exec sudo JAVA_HOME="$JAVA_HOME" HADOOP_HOME="$HADOOP_HOME" SSH_USER="$SSH_USER" "$0" "$@"
fi

export JAVA_HOME
export HADOOP_HOME
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

WORKERS_FILE="$HADOOP_HOME/etc/hadoop/workers"

if [ ! -f "$WORKERS_FILE" ]; then
    echo "ERROR: Khong tim thay file workers tai $WORKERS_FILE"
    exit 1
fi

sed -i 's/\r//' "$WORKERS_FILE"
sed -i 's/\r//' "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"

WORKERS=()
while IFS= read -r line; do
    trimmed=$(echo "$line" | tr -d '[:space:]')
    [ -n "$trimmed" ] && WORKERS+=("$trimmed")
done < "$WORKERS_FILE"

echo "=== Kiem tra ket noi SSH va Java tren Workers ==="
for W in "${WORKERS[@]}"; do
    echo -n "  $SSH_USER@$W ... "
    if ssh $SSH_OPTS "$SSH_USER@$W" "test -d $JAVA_HOME && echo 'OK (Java found)'" 2>/dev/null; then
        :
    else
        echo "FAIL"
        echo "ERROR: Khong the SSH hoac khong tim thay Java tren $W"
        echo "  -> Kiem tra: ssh $SSH_USER@$W 'ls $JAVA_HOME'"
        exit 1
    fi
done
echo ""

echo "=== Khoi dong Hadoop Cluster ==="
echo "JAVA_HOME  : $JAVA_HOME"
echo "HADOOP_HOME: $HADOOP_HOME"
echo "SSH_USER   : $SSH_USER"
echo "Workers    : ${WORKERS[*]}"
echo ""

echo "[1/5] Format HDFS..."
$HADOOP_HOME/bin/hdfs namenode -format -force

echo "[2/5] Start NameNode + SecondaryNameNode..."
$HADOOP_HOME/bin/hdfs --daemon start namenode
$HADOOP_HOME/bin/hdfs --daemon start secondarynamenode
echo "  -> Master: NameNode + SecondaryNameNode started"

echo "[3/5] Start DataNode tren Workers..."
for W in "${WORKERS[@]}"; do
    ssh $SSH_OPTS "$SSH_USER@$W" "export JAVA_HOME=$JAVA_HOME && $HADOOP_HOME/bin/hdfs --daemon start datanode"
    echo "  -> $SSH_USER@$W: DataNode started"
done

echo "[4/5] Start ResourceManager..."
$HADOOP_HOME/bin/yarn --daemon start resourcemanager
echo "  -> Master: ResourceManager started"

echo "[5/5] Start NodeManager tren Workers..."
for W in "${WORKERS[@]}"; do
    ssh $SSH_OPTS "$SSH_USER@$W" "export JAVA_HOME=$JAVA_HOME && $HADOOP_HOME/bin/yarn --daemon start nodemanager"
    echo "  -> $SSH_USER@$W: NodeManager started"
done

sleep 5
echo ""
echo "=== jps (Master) ==="
jps
echo ""
echo "=== Cluster Status ==="
hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" || echo "Dang khoi dong, doi vai giay..."
