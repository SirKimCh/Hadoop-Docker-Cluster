# Hadoop 3.1.2 Cluster on Docker — 4 Nodes

## 1. Tổng quan hệ thống

Hệ thống triển khai cụm Hadoop 3.1.2 gồm 4 nodes độc lập trên nền Docker:

| Node | Hostname | Vai trò |
|---|---|---|
| Master | `namenode` | NameNode + SecondaryNameNode + ResourceManager |
| Worker 1 | `datanode1` | DataNode + NodeManager |
| Worker 2 | `datanode2` | DataNode + NodeManager |
| Worker 3 | `datanode3` | DataNode + NodeManager |

Các container giao tiếp qua bridge network `hadoop_net`. Toàn bộ cấu hình Hadoop được chia sẻ qua volume mount từ thư mục `config/` trên máy host vào `/opt/hadoop/etc/hadoop` bên trong mỗi container — cho phép thay đổi cấu hình mà không cần rebuild image.

---

## 2. Cấu trúc thư mục dự án

```
Hadoop-Docker-Cluster/
├── Dockerfile                      # Image Ubuntu 20.04 + JDK 8 + Hadoop 3.1.2 + SSH
├── docker-compose.yml              # Định nghĩa 4 service, network, port mapping, volumes
├── config/                         # Các file cấu hình Hadoop (volume mount)
│   ├── core-site.xml               # fs.defaultFS = hdfs://namenode:9000
│   ├── hdfs-site.xml               # Replication = 3, đường dẫn data
│   ├── mapred-site.xml             # MapReduce on YARN, giới hạn bộ nhớ
│   ├── yarn-site.xml               # ResourceManager, NodeManager, vmem-check=false
│   ├── workers                     # Danh sách datanode1, datanode2, datanode3
│   ├── hadoop-env.sh               # JAVA_HOME, HADOOP_HOME, biến user daemon
│   ├── capacity-scheduler.xml      # YARN CapacityScheduler với queue default
│   ├── log4j.properties            # Cấu hình logging Hadoop daemon và YARN container
│   └── hadoop-metrics2.properties  # Cấu hình Hadoop metrics2
├── scripts/                        # Bash script khởi động và chạy ứng dụng
│   ├── init-ssh.sh                 # Kích hoạt SSH daemon trên container
│   ├── start-hadoop.sh             # Format HDFS, khởi động HDFS + YARN, kiểm tra jps
│   └── run-wordcount.sh            # Tải dữ liệu, biên dịch, đóng gói, chạy WordCount
├── data/                           # Dữ liệu đầu vào và mã nguồn Java
│   └── WordCount.java              # Chương trình MapReduce đếm từ
├── logs/                           # Log hệ thống Hadoop daemon (volume mount)
└── cmd_logs/                       # File ghi lại toàn bộ phiên thao tác dòng lệnh
```

---

## 3. Hướng dẫn triển khai từng bước

### Bước 1: Build image và khởi động các container

```bash
docker compose build
docker compose up -d
```

Kiểm tra 4 container đang chạy:

```bash
docker ps
```

> **Lưu ý:** Chỉ cần build lại khi thay đổi `Dockerfile`. Thay đổi trong `config/` và `scripts/` có hiệu lực ngay lập tức nhờ volume mount.

---

### Bước 2: Khởi động SSH trên cả 4 containers

```bash
docker exec namenode bash /opt/scripts/init-ssh.sh
docker exec datanode1 bash /opt/scripts/init-ssh.sh
docker exec datanode2 bash /opt/scripts/init-ssh.sh
docker exec datanode3 bash /opt/scripts/init-ssh.sh
```

Kết quả mong đợi mỗi node: `Starting OpenBSD Secure Shell server sshd ... done.`

---

### Bước 3: Khởi động Hadoop và ghi log phiên làm việc

**3.1. Truy cập vào container namenode:**

```bash
docker exec -it namenode bash
```

**3.2. Bắt đầu ghi vết toàn bộ phiên làm việc:**

```bash
script /cmd_logs/full_process_log.txt
```

**3.3. Khởi động Hadoop (format HDFS + bật HDFS + YARN):**

```bash
/opt/scripts/start-hadoop.sh
```

Kết quả `jps` sau khi khởi động thành công trên namenode:

```
NameNode
SecondaryNameNode
ResourceManager
```

---

### Bước 4: Thực thi ứng dụng MapReduce WordCount

Trong cùng phiên terminal, chạy:

```bash
/opt/scripts/run-wordcount.sh
```

Script thực hiện tuần tự:

1. Tải 3 cuốn sách từ Project Gutenberg (`alice.txt`, `holmes.txt`, `frankenstein.txt`)
2. Biên dịch `WordCount.java` bằng `javac -classpath $(hadoop classpath)`
3. Đóng gói thành `wc.jar`
4. Tạo thư mục đầu vào `/data/input/in1` trên HDFS
5. Upload 3 file `.txt` lên HDFS (overwrite nếu đã tồn tại)
6. Xóa thư mục đầu ra cũ nếu tồn tại
7. Thực thi MapReduce job trên cụm 3 DataNode
8. In kết quả word count ra màn hình terminal

---

### Bước 5: Kết thúc và lưu log

```bash
exit
exit
```

Lệnh `exit` đầu tiên đóng phiên `script`, lưu toàn bộ nội dung vào `cmd_logs/full_process_log.txt`. Lệnh `exit` thứ hai thoát khỏi container.

---

## 4. Giám sát hệ thống qua Web UI

Truy cập từ trình duyệt trên máy host:

| Giao diện | Địa chỉ | Chức năng |
|---|---|---|
| **HDFS NameNode UI** | [http://localhost:9870](http://localhost:9870) | Trạng thái NameNode, DataNode, duyệt file HDFS |
| **YARN ResourceManager UI** | [http://localhost:8088](http://localhost:8088) | Jobs đã chạy, trạng thái cluster, NodeManagers |

---

## 5. Cấu trúc log hệ thống

### Thư mục `logs/` — Daemon logs (tự động tạo khi daemon khởi động)

```
logs/
├── hadoop-root-namenode-namenode.out
├── hadoop-root-secondarynamenode-namenode.out
├── hadoop-root-datanode-datanode1.out
├── hadoop-root-datanode-datanode2.out
├── hadoop-root-datanode-datanode3.out
├── hadoop-root-resourcemanager-namenode.out
├── hadoop-root-nodemanager-datanode1.out
├── hadoop-root-nodemanager-datanode2.out
├── hadoop-root-nodemanager-datanode3.out
└── userlogs/
    └── application_<id>/           # Log từng YARN container theo job
        └── container_<id>/
            ├── syslog              # Log chi tiết quá trình chạy MapReduce
            ├── stderr              # Lỗi tiêu chuẩn của container
            └── stdout              # Output tiêu chuẩn của container
```

### Thư mục `cmd_logs/` — Phiên tương tác dòng lệnh

```
cmd_logs/
└── full_process_log.txt            # Toàn bộ lịch sử lệnh và kết quả phiên làm việc
```

---

## 6. Xác nhận job WordCount thành công

```bash
# Kiểm tra output trên HDFS
docker exec namenode hdfs dfs -ls /data/output/out1/
```

Kết quả mong đợi:
```
Found 2 items
-rw-r--r--   3 root supergroup          0  .../out1/_SUCCESS
-rw-r--r--   3 root supergroup     271347  .../out1/part-r-00000
```

```bash
# Kiểm tra 3 DataNode hoạt động
docker exec namenode hdfs dfsadmin -report | grep "Live datanodes"
```

Kết quả mong đợi: `Live datanodes (3):`

---

## 7. Các WARN trong log — Giải thích và mức độ ảnh hưởng

| WARN | Nguồn | Ảnh hưởng |
|---|---|---|
| `Only one image storage directory configured` | NameNode | Không ảnh hưởng — bình thường cho dev cluster |
| `Log Aggregation is disabled` | NodeManager | Không ảnh hưởng — tính năng tùy chọn |
| `Exit code 143 from container` | NodeManager | Không ảnh hưởng — SIGTERM khi YARN container kết thúc bình thường |
| `SSH: Warning: Permanently added ...` | SSH client | Không ảnh hưởng — lần đầu kết nối SSH |
