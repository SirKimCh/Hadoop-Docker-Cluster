#!/bin/bash
cd /data
wget -O alice.txt https://www.gutenberg.org/files/11/11-0.txt
wget -O holmes.txt https://www.gutenberg.org/files/1661/1661-0.txt
wget -O frankenstein.txt https://www.gutenberg.org/files/84/84-0.txt
javac -classpath $(hadoop classpath) WordCount.java
jar cf wc.jar WordCount*.class
hdfs dfs -mkdir -p /data/input/in1
hdfs dfs -put -f alice.txt holmes.txt frankenstein.txt /data/input/in1/
hdfs dfs -rm -r -f /data/output/out1
hadoop jar wc.jar WordCount /data/input/in1 /data/output/out1
hadoop fs -cat /data/output/out1/part-*

