#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$PROJECT_ROOT/data"

# Load environment
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
fi
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-8-openjdk-amd64}"
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
export PATH="$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH"
RESULT_DIR="$PROJECT_ROOT/result"

MAPPERS=(1 2 5 10 20 30)
RUNS=3
TIMESTAMP=$(date +'%d-%m-%Y_%H-%M')
RAW_CSV="$RESULT_DIR/q1_raw_times.csv"
RES_DIR="$RESULT_DIR/${TIMESTAMP}_Q1"
LOCAL_DATA="$DATA_DIR/online_retail_II.csv"
HDFS_INPUT="/data/input/retail/online_retail_II.csv"
HDFS_OUTPUT="/data/output/retail-q1"

if [ ! -f "$LOCAL_DATA" ]; then
    echo "ERROR: Khong tim thay du lieu tai $LOCAL_DATA"
    exit 1
fi

mkdir -p "$RESULT_DIR"

hdfs dfs -mkdir -p /data/input/retail
hdfs dfs -test -e "$HDFS_INPUT" || hdfs dfs -put "$LOCAL_DATA" "$HDFS_INPUT"

cd "$DATA_DIR"
javac -classpath $(hadoop classpath) OnlineRetailQ1.java
jar cf retail-q1.jar OnlineRetailQ1*.class

echo "So Mapper,Lan chay,Thoi gian" > "$RAW_CSV"

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

python3 "$SCRIPT_DIR/plot_speedup_q1.py" "$RES_DIR"
