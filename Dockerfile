FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openjdk-8-jdk \
    openssh-server \
    openssh-client \
    wget \
    python3 \
    python3-pip \
    && pip3 install matplotlib \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV HADOOP_HOME=/opt/hadoop
ENV PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$JAVA_HOME/bin

RUN useradd -m -s /bin/bash hadoop

RUN mkdir -p /var/run/sshd

RUN su - hadoop -c "ssh-keygen -t rsa -P '' -f /home/hadoop/.ssh/id_rsa" \
    && su - hadoop -c "cat /home/hadoop/.ssh/id_rsa.pub >> /home/hadoop/.ssh/authorized_keys" \
    && su - hadoop -c "chmod 600 /home/hadoop/.ssh/authorized_keys" \
    && su - hadoop -c "chmod 700 /home/hadoop/.ssh"

RUN mkdir -p /root/.ssh \
    && ssh-keygen -t rsa -P '' -f /root/.ssh/id_rsa \
    && cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys \
    && chmod 600 /root/.ssh/authorized_keys \
    && chmod 700 /root/.ssh

RUN echo "StrictHostKeyChecking no" >> /etc/ssh/ssh_config

RUN (wget --no-check-certificate --tries=3 --timeout=180 \
    https://mirrors.huaweicloud.com/apache/hadoop/common/hadoop-3.1.2/hadoop-3.1.2.tar.gz \
    -O /tmp/hadoop-3.1.2.tar.gz \
    || wget --no-check-certificate --tries=3 --timeout=180 \
    https://archive.apache.org/dist/hadoop/common/hadoop-3.1.2/hadoop-3.1.2.tar.gz \
    -O /tmp/hadoop-3.1.2.tar.gz) \
    && tar -xzf /tmp/hadoop-3.1.2.tar.gz -C /opt/ \
    && mv /opt/hadoop-3.1.2 /opt/hadoop \
    && rm /tmp/hadoop-3.1.2.tar.gz

RUN chown -R hadoop:hadoop /opt/hadoop

RUN echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" >> /home/hadoop/.bashrc \
    && echo "export HADOOP_HOME=/opt/hadoop" >> /home/hadoop/.bashrc \
    && echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$JAVA_HOME/bin" >> /home/hadoop/.bashrc

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

