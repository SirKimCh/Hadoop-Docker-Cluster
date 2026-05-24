#!/bin/bash

MAPPER_COUNTS="1 2 5 10 20 30"
RUNS=3
TIMESTAMP=$(date +'%d-%m-%Y_%H-%M')
LOG_FILE="/result/q1_execution_times.csv"

cd /data

hdfs dfs -mkdir -p /data/input/retail
hdfs dfs -test -e /data/input/retail/online_retail_II.csv || hdfs dfs -put online_retail_II.csv /data/input/retail/

javac -classpath $(hadoop classpath) OnlineRetailQ1.java
jar cf retail-q1.jar OnlineRetailQ1*.class

TOTAL_LINES=$(wc -l < /data/online_retail_II.csv)

mkdir -p /result
echo "Mapper,Run,Time" > $LOG_FILE

for MAPPERS in $MAPPER_COUNTS; do
    LINES_PER_MAP=$((TOTAL_LINES / MAPPERS))
    for RUN in $(seq 1 $RUNS); do
        hdfs dfs -rm -r -f /data/output/retail-q1

        START_TIME=$(date +%s)
        hadoop jar retail-q1.jar OnlineRetailQ1 /data/input/retail/online_retail_II.csv /data/output/retail-q1 $LINES_PER_MAP
        END_TIME=$(date +%s)
        EXEC_TIME=$((END_TIME - START_TIME))

        echo "$MAPPERS,$RUN,$EXEC_TIME" >> $LOG_FILE
        echo "Mapper: $MAPPERS | Run: $RUN | Time: ${EXEC_TIME}s"
    done
done

RES_DIR="/result/${TIMESTAMP}_Q1_Experiment"
mkdir -p $RES_DIR
hdfs dfs -get -f /data/output/retail-q1/part-r-00000 $RES_DIR/
cp $LOG_FILE $RES_DIR/

echo "===== HOAN THANH ====="
echo "Log: $LOG_FILE"
echo "Ket qua MapReduce: $RES_DIR/part-r-00000"
echo ""
cat $RES_DIR/part-r-00000
