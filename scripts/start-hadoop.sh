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

for worker in $(cat /opt/hadoop/etc/hadoop/workers); do
  ssh "${worker}" "/opt/hadoop/bin/hdfs --daemon start datanode"
done

/opt/hadoop/bin/yarn --daemon start resourcemanager

for worker in $(cat /opt/hadoop/etc/hadoop/workers); do
  ssh "${worker}" "/opt/hadoop/bin/yarn --daemon start nodemanager"
done

sleep 5
jps
