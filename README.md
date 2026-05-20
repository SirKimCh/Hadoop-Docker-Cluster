# Hadoop 3.1.2 Cluster on Docker — 4 Nodes

## 1. Tổng quan hệ thống

Hệ thống triển khai cụm Hadoop 3.1.2 gồm 4 nodes độc lập trên nền Docker:

| Node | Hostname | Vai trò |
|---|---|---|
| Master | `namenode` | NameNode + ResourceManager |
| Worker 1 | `datanode1` | DataNode + NodeManager |
| Worker 2 | `datanode2` | DataNode + NodeManager |
| Worker 3 | `datanode3` | DataNode + NodeManager |

Các container giao tiếp qua bridge network `hadoop_net`. Cấu hình Hadoop được chia sẻ qua volume mount từ thư mục `config/` trên máy host vào `/opt/hadoop/etc/hadoop` bên trong mỗi container.

---

## 2. Cấu trúc thư mục dự án

```
Hadoop-Docker-Cluster/
├── Dockerfile                  # Image Ubuntu 20.04 + JDK 8 + Hadoop 3.1.2
├── docker-compose.yml          # Định nghĩa 4 service và network
├── config/                     # Các file cấu hình Hadoop (XML + workers)
│   ├── core-site.xml
│   ├── hdfs-site.xml
│   ├── mapred-site.xml
│   ├── yarn-site.xml
│   └── workers
├── scripts/                    # Các bash script khởi động và chạy ứng dụng
│   ├── init-ssh.sh             # Kích hoạt SSH daemon trên container
│   ├── start-hadoop.sh         # Format HDFS, khởi động HDFS + YARN, kiểm tra jps
│   └── run-wordcount.sh        # Biên dịch, đóng gói và chạy MapReduce WordCount
├── data/                       # Dữ liệu đầu vào và mã nguồn Java
│   └── WordCount.java
├── logs/                       # Log hệ thống của các Hadoop daemon (volume mount)
└── cmd_logs/                   # File text ghi lại toàn bộ phiên thao tác dòng lệnh
```

---

## 3. Hướng dẫn triển khai từng bước

### Bước 1: Khởi động các container

Chạy lệnh sau tại thư mục gốc của dự án trên máy host:

```bash
docker-compose up -d
```

Kiểm tra trạng thái 4 container sau khi khởi động:

```bash
docker ps
```

---

### Bước 2: Khởi tạo dịch vụ SSH trên cả 4 containers

```bash
docker exec namenode bash /opt/scripts/init-ssh.sh
docker exec datanode1 bash /opt/scripts/init-ssh.sh
docker exec datanode2 bash /opt/scripts/init-ssh.sh
docker exec datanode3 bash /opt/scripts/init-ssh.sh
```

---

### Bước 3: Ghi log phiên làm việc và khởi động Hadoop

**3.1. Truy cập vào container namenode:**

```bash
docker exec -it namenode bash
```

**3.2. Bắt đầu ghi vết toàn bộ phiên làm việc vào file log:**

```bash
script /cmd_logs/full_process_log.txt
```

**3.3. Chạy script khởi động Hadoop (format HDFS + bật HDFS + YARN + kiểm tra jps):**

```bash
/opt/scripts/start-hadoop.sh
```

Sau khi chạy xong, lệnh `jps` sẽ hiển thị các tiến trình Java đang hoạt động trên namenode, bao gồm: `NameNode`, `SecondaryNameNode`, `ResourceManager`.

---

### Bước 4: Thực thi ứng dụng MapReduce WordCount

Trong cùng phiên terminal đã mở ở Bước 3, chạy:

```bash
/opt/scripts/run-wordcount.sh
```

Script sẽ tự động thực hiện tuần tự:
1. Biên dịch `WordCount.java` bằng `hadoop com.sun.tools.javac.Main`
2. Đóng gói thành `wc.jar`
3. Tạo thư mục đầu vào `/data/input/in1` trên HDFS
4. Đẩy file `.txt` từ `/data` lên HDFS
5. Xóa thư mục đầu ra cũ nếu tồn tại
6. Thực thi tác vụ MapReduce
7. In kết quả đếm từ ra màn hình terminal

---

### Bước 5: Kết thúc và lưu log phiên làm việc

```bash
exit
```

Lệnh `exit` đóng phiên `script` và lưu toàn bộ nội dung thao tác dòng lệnh vào file `/cmd_logs/full_process_log.txt` (tương ứng với thư mục `cmd_logs/` trên máy host).

---

## 4. Giám sát hệ thống qua Web UI

Truy cập từ trình duyệt trên máy host Windows:

| Giao diện | Địa chỉ |
|---|---|
| HDFS Web UI — Trạng thái NameNode & các DataNode | [http://localhost:9870](http://localhost:9870) |
| YARN Web UI — Ứng dụng & Lập lịch tài nguyên | [http://localhost:8088](http://localhost:8088) |

---

## 5. Kiểm tra thành phần minh chứng nghiệm thu

### Thư mục `logs/` — Log hệ thống Hadoop daemon

Sau khi khởi động cụm, thư mục `logs/` trên máy host sẽ chứa các file log của các daemon:

```
logs/
├── hadoop-hadoop-namenode-namenode.log
├── hadoop-hadoop-secondarynamenode-namenode.log
├── hadoop-hadoop-datanode-datanode1.log
├── hadoop-hadoop-datanode-datanode2.log
├── hadoop-hadoop-datanode-datanode3.log
├── yarn-hadoop-resourcemanager-namenode.log
├── yarn-hadoop-nodemanager-datanode1.log
├── yarn-hadoop-nodemanager-datanode2.log
└── yarn-hadoop-nodemanager-datanode3.log
```

### Thư mục `cmd_logs/` — Log phiên tương tác dòng lệnh

```
cmd_logs/
└── full_process_log.txt        # Toàn bộ lịch sử lệnh và kết quả của phiên làm việc
```

