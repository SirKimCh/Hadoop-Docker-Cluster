#!/bin/bash
set -e

cd /data

INPUT_DIR=/data/beer/input
OUTPUT_DIR=/data/beer/output
INPUT_FILE=${INPUT_DIR}/data.csv

javac -classpath "$(hadoop classpath)" BeerAnalysis.java
jar cf beer-analysis.jar BeerAnalysis*.class

hdfs dfs -mkdir -p "${INPUT_DIR}"
hdfs dfs -put -f data.csv "${INPUT_FILE}"
hdfs dfs -rm -r -f "${OUTPUT_DIR}"

hadoop jar beer-analysis.jar BeerAnalysis countByAlcohol "${INPUT_FILE}" "${OUTPUT_DIR}/q1"
hadoop jar beer-analysis.jar BeerAnalysis mostCommon "${OUTPUT_DIR}/q1" "${OUTPUT_DIR}/q2"

MOST_COMMON_PERCENTAGE=$(hdfs dfs -cat "${OUTPUT_DIR}/q2/part-r-00000" | awk 'NR==1 {print $1}')
hadoop jar beer-analysis.jar BeerAnalysis beersByAlcohol "${INPUT_FILE}" "${OUTPUT_DIR}/q3" "${MOST_COMMON_PERCENTAGE}"
hadoop jar beer-analysis.jar BeerAnalysis beerAndBreweryCount "${INPUT_FILE}" "${OUTPUT_DIR}/q4"
hadoop jar beer-analysis.jar BeerAnalysis highestAlcohol "${INPUT_FILE}" "${OUTPUT_DIR}/q5"

echo "===== Cau 1: Co bao nhieu loai bia cho moi nong do con? ====="
hdfs dfs -cat "${OUTPUT_DIR}/q1/part-r-*"

echo
echo "===== Cau 2: Nong do con nao pho bien nhat? ====="
hdfs dfs -cat "${OUTPUT_DIR}/q2/part-r-*"

echo
echo "===== Cau 3: Nhung loai bia co nong do con pho bien nhat (${MOST_COMMON_PERCENTAGE}) ====="
hdfs dfs -cat "${OUTPUT_DIR}/q3/part-r-*"

echo
echo "===== Cau 4: Moi nong do con co bao nhieu loai bia va bao nhieu nha may bia? ====="
hdfs dfs -cat "${OUTPUT_DIR}/q4/part-r-*"

echo
echo "===== Cau 5: Nhung loai bia co nong do con cao nhat va duoc san xuat o dau? ====="
hdfs dfs -cat "${OUTPUT_DIR}/q5/part-r-*"
