#!/bin/bash
set -euo pipefail

cd /data

INPUT_DIR=/data/online_retail/input
OUTPUT_DIR=/data/online_retail/output
TEMP_DIR=/data/online_retail/tmp
INPUT_FILE=${INPUT_DIR}/online_retail_II.csv
SOURCE_FILE=${1:-/data/online_retail_II.csv}
TIMES_FILE=/data/online_retail_times.tsv
MAPPER_COUNT=${MAPPER_COUNT:-0}

elapsed_seconds() {
  local start_ms=$1
  local end_ms
  end_ms=$(date +%s%3N)
  awk -v start="${start_ms}" -v end="${end_ms}" 'BEGIN { printf "%.3f", (end - start) / 1000 }'
}

run_job() {
  local label=$1
  shift
  local start_ms
  local seconds
  start_ms=$(date +%s%3N)
  "$@"
  seconds=$(elapsed_seconds "${start_ms}")
  printf "%s\t%s\n" "${label}" "${seconds}" | tee -a "${TIMES_FILE}"
}

if [ ! -f "${SOURCE_FILE}" ]; then
  echo "Input CSV not found: ${SOURCE_FILE}" >&2
  echo "Run scripts/prepare-online-retail-data.py on the host first." >&2
  exit 1
fi

rm -f "${TIMES_FILE}"

javac -classpath "$(hadoop classpath)" OnlineRetailAnalysis.java
jar cf online-retail-analysis.jar OnlineRetailAnalysis*.class

hdfs dfs -mkdir -p "${INPUT_DIR}"
hdfs dfs -put -f "${SOURCE_FILE}" "${INPUT_FILE}"
hdfs dfs -rm -r -f "${OUTPUT_DIR}" "${TEMP_DIR}"

echo "===== Mapper count: ${MAPPER_COUNT} (0 = Hadoop default split) ====="

run_job "q1_invoice_count_by_country" \
  hadoop jar online-retail-analysis.jar OnlineRetailAnalysis invoiceCount \
  "${INPUT_FILE}" "${TEMP_DIR}/q1_distinct_invoice" "${OUTPUT_DIR}/q1" "${MAPPER_COUNT}"

run_job "q2_distinct_customer_count_by_country" \
  hadoop jar online-retail-analysis.jar OnlineRetailAnalysis customerCount \
  "${INPUT_FILE}" "${TEMP_DIR}/q2_distinct_customer" "${OUTPUT_DIR}/q2" "${MAPPER_COUNT}"

echo "===== Cau 1: So luong hoa don theo tung quoc gia ====="
hdfs dfs -cat "${OUTPUT_DIR}/q1/part-r-*"

echo
echo "===== Cau 2: So khach hang khac nhau theo tung quoc gia ====="
hdfs dfs -cat "${OUTPUT_DIR}/q2/part-r-*"

echo
echo "===== Thoi gian thuc thi ====="
cat "${TIMES_FILE}"
