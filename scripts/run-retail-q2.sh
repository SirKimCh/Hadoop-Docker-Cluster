#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_nodes>"
    echo "Example: $0 3"
    exit 1
fi

NODES=$1
cd /data

hdfs dfs -mkdir -p /data/input/retail
hdfs dfs -test -e /data/input/retail/online_retail_II.csv || hdfs dfs -put online_retail_II.csv /data/input/retail/

hdfs dfs -rm -r -f /data/output/retail-q2

javac -classpath $(hadoop classpath) OnlineRetailQ2.java
jar cf retail-q2.jar OnlineRetailQ2*.class

START_TIME=$(date +%s)
hadoop jar retail-q2.jar OnlineRetailQ2 /data/input/retail/online_retail_II.csv /data/output/retail-q2
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

mkdir -p /result
echo "$NODES,$ELAPSED" >> /result/q2_execution_times.csv

RES_DIR="/result/$(date +%d-%m-%Y_%H-%M)_Q2_${1}Nodes"
mkdir -p $RES_DIR

hdfs dfs -get /data/output/retail-q2/part-r-00000 $RES_DIR/

echo "===== HOAN THANH ====="
echo "So Node: $NODES"
echo "Thoi gian: ${ELAPSED} giay"
echo "Ket qua: $RES_DIR/part-r-00000"
echo ""
cat $RES_DIR/part-r-00000
