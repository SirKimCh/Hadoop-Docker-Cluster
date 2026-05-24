#!/bin/bash
set -e

export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root

HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
WORKERS_FILE="$HADOOP_HOME/etc/hadoop/workers"

sed -i 's/\r//' "$WORKERS_FILE"
sed -i 's/\r//' "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"

WORKERS=()
while IFS= read -r line; do
    trimmed=$(echo "$line" | tr -d '[:space:]')
    [ -n "$trimmed" ] && WORKERS+=("$trimmed")
done < "$WORKERS_FILE"

echo "=== Khoi dong Hadoop Cluster ==="
echo "Workers: ${WORKERS[*]}"
echo ""

$HADOOP_HOME/bin/hdfs namenode -format -force

$HADOOP_HOME/bin/hdfs --daemon start namenode
$HADOOP_HOME/bin/hdfs --daemon start secondarynamenode
echo "[Master] NameNode + SecondaryNameNode started"

for W in "${WORKERS[@]}"; do
    ssh "$W" "$HADOOP_HOME/bin/hdfs --daemon start datanode"
    echo "[$W] DataNode started"
done

$HADOOP_HOME/bin/yarn --daemon start resourcemanager
echo "[Master] ResourceManager started"

for W in "${WORKERS[@]}"; do
    ssh "$W" "$HADOOP_HOME/bin/yarn --daemon start nodemanager"
    echo "[$W] NodeManager started"
done

sleep 5
echo ""
echo "=== jps ==="
jps
