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

SSH_KEY="/home/$SSH_USER/.ssh/id_rsa"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10"
if [ -f "$SSH_KEY" ]; then
    SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

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

# ============================================================
# Kiem tra SSH + Java tren Workers
# ============================================================
echo "=== Kiem tra ket noi SSH va Java tren Workers ==="
for W in "${WORKERS[@]}"; do
    echo -n "  $SSH_USER@$W ... "
    if ssh $SSH_OPTS "$SSH_USER@$W" "test -d $JAVA_HOME && echo 'OK (Java found)'" 2>/dev/null; then
        :
    else
        echo "FAIL"
        echo "ERROR: Khong the SSH hoac khong tim thay Java tren $W"
        echo "  -> Dam bao SSH key da duoc cau hinh tu Master sang Worker"
        echo "  -> Dam bao Java 8 da duoc cai dat tren Worker"
        exit 1
    fi
done
echo ""

# ============================================================
# Dung toan bo daemon cu
# ============================================================
echo "=== Dung toan bo daemon cu (neu co) ==="

# Stop Master daemons
for svc in namenode secondarynamenode resourcemanager; do
    if jps 2>/dev/null | grep -qi "$svc"; then
        echo "  Dung $svc tren Master..."
        if [ "$svc" = "resourcemanager" ]; then
            $HADOOP_HOME/bin/yarn --daemon stop resourcemanager 2>/dev/null || true
        else
            $HADOOP_HOME/bin/hdfs --daemon stop $svc 2>/dev/null || true
        fi
    fi
done

# Stop Worker daemons
for W in "${WORKERS[@]}"; do
    echo "  Dung daemon tren $SSH_USER@$W..."
    ssh $SSH_OPTS "$SSH_USER@$W" "
        sudo $HADOOP_HOME/bin/hdfs --daemon stop datanode 2>/dev/null || true
        sudo $HADOOP_HOME/bin/yarn --daemon stop nodemanager 2>/dev/null || true
    "
done

# Doi cac process ket thuc hoan toan
sleep 3
echo "  -> Da dung tat ca daemon cu"
echo ""

# ============================================================
# Kiem tra port 9000 trong truoc khi format
# ============================================================
if ss -tlnp 2>/dev/null | grep -q ":9000 " || netstat -tlnp 2>/dev/null | grep -q ":9000 "; then
    echo "WARNING: Port 9000 van dang bi chiem. Doi them 5 giay..."
    sleep 5
fi

# ============================================================
# Khoi dong Hadoop Cluster
# ============================================================
echo "=== Khoi dong Hadoop Cluster ==="
echo "JAVA_HOME  : $JAVA_HOME"
echo "HADOOP_HOME: $HADOOP_HOME"
echo "SSH_USER   : $SSH_USER"
echo "Workers    : ${WORKERS[*]}"
echo ""

echo "[1/5] Format HDFS..."
$HADOOP_HOME/bin/hdfs namenode -format -force
echo ""

echo "[2/5] Start NameNode + SecondaryNameNode..."
$HADOOP_HOME/bin/hdfs --daemon start namenode
$HADOOP_HOME/bin/hdfs --daemon start secondarynamenode
echo "  -> Dang khoi dong NameNode..."

# Cho NameNode san sang (kiem tra port 9000)
NN_READY=false
for i in $(seq 1 15); do
    if ss -tlnp 2>/dev/null | grep -q ":9000 " || netstat -tlnp 2>/dev/null | grep -q ":9000 "; then
        NN_READY=true
        break
    fi
    sleep 2
done

if [ "$NN_READY" = true ]; then
    echo "  -> Master: NameNode + SecondaryNameNode started (port 9000 OK)"
else
    echo "  -> WARNING: NameNode chua san sang sau 30s. Kiem tra log:"
    echo "     cat $HADOOP_HOME/logs/*namenode*.log | tail -50"
    echo "  -> Van tiep tuc..."
fi
echo ""

echo "[3/5] Start DataNode tren Workers..."
for W in "${WORKERS[@]}"; do
    ssh $SSH_OPTS "$SSH_USER@$W" "sudo JAVA_HOME=$JAVA_HOME $HADOOP_HOME/bin/hdfs --daemon start datanode"
    echo "  -> $SSH_USER@$W: DataNode started"
done
echo ""

echo "[4/5] Start ResourceManager..."
$HADOOP_HOME/bin/yarn --daemon start resourcemanager
echo "  -> Dang khoi dong ResourceManager..."

# Cho ResourceManager san sang (kiem tra port 8088)
RM_READY=false
for i in $(seq 1 15); do
    if ss -tlnp 2>/dev/null | grep -q ":8088 " || netstat -tlnp 2>/dev/null | grep -q ":8088 "; then
        RM_READY=true
        break
    fi
    sleep 2
done

if [ "$RM_READY" = true ]; then
    echo "  -> Master: ResourceManager started (port 8088 OK)"
else
    echo "  -> WARNING: ResourceManager chua san sang sau 30s. Kiem tra log:"
    echo "     cat $HADOOP_HOME/logs/*resourcemanager*.log | tail -50"
fi
echo ""

echo "[5/5] Start NodeManager tren Workers..."
for W in "${WORKERS[@]}"; do
    ssh $SSH_OPTS "$SSH_USER@$W" "sudo JAVA_HOME=$JAVA_HOME $HADOOP_HOME/bin/yarn --daemon start nodemanager"
    echo "  -> $SSH_USER@$W: NodeManager started"
done
echo ""

# Doi tat ca daemon on dinh
echo "Doi cac daemon on dinh (10 giay)..."
sleep 10

# ============================================================
# Phan quyen HDFS
# ============================================================
echo ""
echo "=== Phan quyen HDFS cho user $SSH_USER ==="

# Kiem tra HDFS da san sang chua
HDFS_OK=false
for i in $(seq 1 5); do
    if hdfs dfs -ls / 2>/dev/null; then
        HDFS_OK=true
        break
    fi
    echo "  HDFS chua san sang, doi 5 giay..."
    sleep 5
done

if [ "$HDFS_OK" = true ]; then
    hdfs dfs -mkdir -p /data/input/retail
    hdfs dfs -chmod -R 777 /data
    hdfs dfs -chown -R "$SSH_USER":"$SSH_USER" /data
    echo "  -> /data da duoc chown cho $SSH_USER"
else
    echo "  -> WARNING: HDFS chua san sang. Chay lai sau:"
    echo "     hdfs dfs -mkdir -p /data/input/retail"
    echo "     hdfs dfs -chmod -R 777 /data"
    echo "     hdfs dfs -chown -R $SSH_USER /data"
fi

mkdir -p "$PROJECT_ROOT/result"

# ============================================================
# Kiem tra ket qua
# ============================================================
echo ""
echo "=== jps (Master) ==="
jps
echo ""

echo "=== jps (Workers) ==="
for W in "${WORKERS[@]}"; do
    echo "  $SSH_USER@$W:"
    ssh $SSH_OPTS "$SSH_USER@$W" "sudo JAVA_HOME=$JAVA_HOME jps" 2>/dev/null | grep -E "DataNode|NodeManager" || echo "    (chua khoi dong)"
done
echo ""

echo "=== Cluster Status ==="
hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" || echo "Dang khoi dong, doi vai giay..."

echo ""
echo "=== HOAN THANH ==="
echo "Kiem tra tai: http://$(hostname -I | awk '{print $1}'):9870 (HDFS)"
echo "             http://$(hostname -I | awk '{print $1}'):8088 (YARN)"
