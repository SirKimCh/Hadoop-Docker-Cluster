#!/bin/bash
export HDFS_NAMENODE_USER=root
export HDFS_DATANODE_USER=root
export HDFS_SECONDARYNAMENODE_USER=root
export YARN_RESOURCEMANAGER_USER=root
export YARN_NODEMANAGER_USER=root
sed -i 's/\r//' /opt/hadoop/etc/hadoop/workers
sed -i 's/\r//' /opt/hadoop/etc/hadoop/hadoop-env.sh

/opt/hadoop/bin/hdfs namenode -format -force

/opt/hadoop/bin/hdfs --daemon start namenode
/opt/hadoop/bin/hdfs --daemon start secondarynamenode

ssh datanode1 "/opt/hadoop/bin/hdfs --daemon start datanode"
ssh datanode2 "/opt/hadoop/bin/hdfs --daemon start datanode"
ssh datanode3 "/opt/hadoop/bin/hdfs --daemon start datanode"

/opt/hadoop/bin/yarn --daemon start resourcemanager

ssh datanode1 "/opt/hadoop/bin/yarn --daemon start nodemanager"
ssh datanode2 "/opt/hadoop/bin/yarn --daemon start nodemanager"
ssh datanode3 "/opt/hadoop/bin/yarn --daemon start nodemanager"

sleep 5
jps

