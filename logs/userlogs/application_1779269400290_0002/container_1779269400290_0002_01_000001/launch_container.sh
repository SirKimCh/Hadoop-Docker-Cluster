#!/bin/bash

set -o pipefail -e
export PRELAUNCH_OUT="/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/prelaunch.out"
exec >"${PRELAUNCH_OUT}"
export PRELAUNCH_ERR="/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/prelaunch.err"
exec 2>"${PRELAUNCH_ERR}"
echo "Setting up env variables"
export JAVA_HOME=${JAVA_HOME:-"/usr/lib/jvm/java-8-openjdk-amd64"}
export HADOOP_COMMON_HOME=${HADOOP_COMMON_HOME:-"/opt/hadoop"}
export HADOOP_HDFS_HOME=${HADOOP_HDFS_HOME:-"/opt/hadoop"}
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-"/opt/hadoop/etc/hadoop"}
export HADOOP_YARN_HOME=${HADOOP_YARN_HOME:-"/opt/hadoop"}
export HADOOP_HOME=${HADOOP_HOME:-"/opt/hadoop"}
export PATH=${PATH:-"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin"}
export HADOOP_TOKEN_FILE_LOCATION="/opt/hadoop/tmp/nm-local-dir/usercache/root/appcache/application_1779269400290_0002/container_1779269400290_0002_01_000001/container_tokens"
export CONTAINER_ID="container_1779269400290_0002_01_000001"
export NM_PORT="44829"
export NM_HOST="datanode3"
export NM_HTTP_PORT="8042"
export LOCAL_DIRS="/opt/hadoop/tmp/nm-local-dir/usercache/root/appcache/application_1779269400290_0002"
export LOCAL_USER_DIRS="/opt/hadoop/tmp/nm-local-dir/usercache/root/"
export LOG_DIRS="/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001"
export USER="root"
export LOGNAME="root"
export HOME="/home/"
export PWD="/opt/hadoop/tmp/nm-local-dir/usercache/root/appcache/application_1779269400290_0002/container_1779269400290_0002_01_000001"
export JVM_PID="$$"
export MALLOC_ARENA_MAX="4"
export NM_AUX_SERVICE_mapreduce_shuffle="AAA0+gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
export APPLICATION_WEB_PROXY_BASE="/proxy/application_1779269400290_0002"
export SHELL="/bin/bash"
export HADOOP_MAPRED_HOME="/opt/hadoop"
export CLASSPATH="$PWD:$HADOOP_CONF_DIR:$HADOOP_COMMON_HOME/share/hadoop/common/*:$HADOOP_COMMON_HOME/share/hadoop/common/lib/*:$HADOOP_HDFS_HOME/share/hadoop/hdfs/*:$HADOOP_HDFS_HOME/share/hadoop/hdfs/lib/*:$HADOOP_YARN_HOME/share/hadoop/yarn/*:$HADOOP_YARN_HOME/share/hadoop/yarn/lib/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*:job.jar/*:job.jar/classes/:job.jar/lib/*:$PWD/*"
export APP_SUBMIT_TIME_ENV="1779269767122"
export LD_LIBRARY_PATH="$PWD:$HADOOP_COMMON_HOME/lib/native"
echo "Setting up job resources"
mkdir -p jobSubmitDir
ln -sf -- "/opt/hadoop/tmp/nm-local-dir/usercache/root/appcache/application_1779269400290_0002/filecache/12/job.split" "jobSubmitDir/job.split"
ln -sf -- "/opt/hadoop/tmp/nm-local-dir/usercache/root/appcache/application_1779269400290_0002/filecache/13/job.xml" "job.xml"
ln -sf -- "/opt/hadoop/tmp/nm-local-dir/usercache/root/appcache/application_1779269400290_0002/filecache/11/job.jar" "job.jar"
mkdir -p jobSubmitDir
ln -sf -- "/opt/hadoop/tmp/nm-local-dir/usercache/root/appcache/application_1779269400290_0002/filecache/10/job.splitmetainfo" "jobSubmitDir/job.splitmetainfo"
echo "Copying debugging information"
# Creating copy of launch script
cp "launch_container.sh" "/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/launch_container.sh"
chmod 640 "/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/launch_container.sh"
# Determining directory contents
echo "ls -l:" 1>"/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/directory.info"
ls -l 1>>"/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/directory.info"
echo "find -L . -maxdepth 5 -ls:" 1>>"/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/directory.info"
find -L . -maxdepth 5 -ls 1>>"/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/directory.info"
echo "broken symlinks(find -L . -maxdepth 5 -type l -ls):" 1>>"/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/directory.info"
find -L . -maxdepth 5 -type l -ls 1>>"/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/directory.info"
echo "Launching container"
exec /bin/bash -c "$JAVA_HOME/bin/java -Djava.io.tmpdir=$PWD/tmp -Dlog4j.configuration=container-log4j.properties -Dyarn.app.container.log.dir=/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001 -Dyarn.app.container.log.filesize=0 -Dhadoop.root.logger=INFO,CLA -Dhadoop.root.logfile=syslog  -Xmx1024m org.apache.hadoop.mapreduce.v2.app.MRAppMaster 1>/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/stdout 2>/opt/hadoop/logs/userlogs/application_1779269400290_0002/container_1779269400290_0002_01_000001/stderr "
