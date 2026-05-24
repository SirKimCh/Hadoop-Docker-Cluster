#!/bin/bash
set -e

MAPPERS=(1 2 5 10 20 30)
RUNS=3
TIMESTAMP=$(date +'%d-%m-%Y_%H-%M')
RAW_CSV="/result/q1_raw_times.csv"
RES_DIR="/result/${TIMESTAMP}_Q1"
HDFS_INPUT="/data/input/retail/online_retail_II.csv"
HDFS_OUTPUT="/data/output/retail-q1"
LOCAL_DATA="/data/online_retail_II.csv"

mkdir -p /result

hdfs dfs -mkdir -p /data/input/retail
hdfs dfs -test -e "$HDFS_INPUT" || hdfs dfs -put "$LOCAL_DATA" "$HDFS_INPUT"

cd /data
javac -classpath $(hadoop classpath) OnlineRetailQ1.java
jar cf retail-q1.jar OnlineRetailQ1*.class

echo "Mapper,Run,Time" > "$RAW_CSV"

for NMAP in "${MAPPERS[@]}"; do
    for RUN in $(seq 1 $RUNS); do
        hdfs dfs -rm -r -f "$HDFS_OUTPUT"

        START=$(date +%s)
        hadoop jar retail-q1.jar OnlineRetailQ1 "$HDFS_INPUT" "$HDFS_OUTPUT" "$NMAP"
        END=$(date +%s)
        ELAPSED=$((END - START))

        echo "${NMAP},${RUN},${ELAPSED}" >> "$RAW_CSV"
        echo "Mapper=${NMAP} | Run=${RUN} | Time=${ELAPSED}s"
    done
done

mkdir -p "$RES_DIR"
hdfs dfs -get -f "${HDFS_OUTPUT}/part-r-00000" "$RES_DIR/"
cp "$RAW_CSV" "$RES_DIR/"

echo ""
echo "===== BENCHMARK Q1 HOAN THANH ====="
echo "Raw CSV      : $RAW_CSV"
echo "Ket qua MR   : $RES_DIR/part-r-00000"
echo ""

python3 "$(dirname "$0")/plot_speedup_q1.py" "$RES_DIR"
