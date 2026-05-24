# Hadoop 3.1.2 Native Cluster — 3 VPS Ubuntu

## Tổng quan

Triển khai cụm Hadoop 3.1.2 native trên 3 VPS Ubuntu (không dùng Docker):

| Node | Hostname | IP | Vai trò |
|---|---|---|---|
| Master | nttrung-th6 | `10.32.2.236` | NameNode + SecondaryNameNode + ResourceManager |
| Worker 1 | — | `10.32.2.213` | DataNode + NodeManager |
| Worker 2 | — | `10.32.2.125` | DataNode + NodeManager |

---

## Bước 1: Yêu cầu chuẩn bị

Cài đặt **trên cả 3 VPS** (Master, Worker 1, Worker 2):

### 1.1. Java 8

```bash
sudo apt update
sudo apt install -y openjdk-8-jdk
java -version
```

### 1.2. Hadoop 3.1.2

```bash
cd /opt
sudo wget https://archive.apache.org/dist/hadoop/common/hadoop-3.1.2/hadoop-3.1.2.tar.gz
sudo tar -xzf hadoop-3.1.2.tar.gz
sudo mv hadoop-3.1.2 hadoop
sudo rm hadoop-3.1.2.tar.gz
```

### 1.3. Biến môi trường

Thêm vào cuối file `~/.bashrc`:

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/opt/hadoop
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
```

Áp dụng:

```bash
source ~/.bashrc
hadoop version
```

### 1.4. Python 3 và các thư viện

```bash
sudo apt install -y python3 python3-pip dos2unix
pip3 install pandas matplotlib openpyxl
```

---

## Bước 2: Cấu hình SSH không mật khẩu từ Master sang 2 Worker

### 2.1. Trên Master — Tạo cặp khóa SSH

```bash
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 2.2. Trên Master — Copy khóa sang 2 Worker

```bash
ssh-copy-id ubuntu@10.32.2.213
ssh-copy-id ubuntu@10.32.2.125
```

### 2.3. Kiểm tra kết nối

```bash
ssh ubuntu@10.32.2.213 hostname
ssh ubuntu@10.32.2.125 hostname
```

---

## Bước 3: Điền file `.env` và chạy script đồng bộ cụm

### 3.1. Clone dự án

```bash
cd /home/ubuntu
git clone https://github.com/SirKimCh/Hadoop-Docker-Cluster.git
cd Hadoop-Docker-Cluster
```

### 3.2. Cấu hình `.env`

```bash
cp .env.example .env
nano .env
```

Nội dung `.env`:

```
MASTER_IP=10.32.2.236
WORKER1_IP=10.32.2.213
WORKER2_IP=10.32.2.125
SSH_USER=ubuntu
HADOOP_HOME=/opt/hadoop
JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
```

### 3.3. Cấp quyền và đồng bộ cấu hình

```bash
chmod +x scripts/*.sh
./scripts/sync_cluster_config.sh
```

Script sẽ:
1. Đọc IP từ file `.env`
2. Sinh 5 file: `core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`, `mapred-site.xml`, `hadoop-env.sh`
3. Copy cấu hình vào `$HADOOP_HOME/etc/hadoop/` trên Master
4. Dùng `rsync` đẩy cấu hình sang 2 Worker (bao gồm `JAVA_HOME` trong `hadoop-env.sh`)

---

## Bước 4: Format NameNode và Start Cluster

```bash
./scripts/start-hadoop.sh
```

Script tự động thực hiện toàn bộ chu trình (không cần `sudo` — script tự xử lý):

```
[0] Kiểm tra SSH + Java tồn tại trên cả 2 Worker
[0] Dừng toàn bộ daemon cũ (nếu có)
[1] Format HDFS
[2] Start NameNode + SecondaryNameNode trên Master
[3] Start DataNode trên 2 Worker (qua SSH)
[4] Start ResourceManager trên Master
[5] Start NodeManager trên 2 Worker (qua SSH)
[6] Phân quyền HDFS: chown /data cho user ubuntu
[7] jps + hdfs dfsadmin -report
```

### Xác nhận cluster hoạt động

Kết quả `jps` trên Master:

```
NameNode
SecondaryNameNode
ResourceManager
```

Kết quả `jps` trên mỗi Worker:

```
DataNode
NodeManager
```

```bash
hdfs dfsadmin -report | grep "Live datanodes"
```

Kết quả mong đợi: `Live datanodes (2):`

---

## Bước 5: Kích hoạt script Benchmark chạy tự động

### Câu 1 — Đếm hóa đơn duy nhất theo quốc gia

```bash
./scripts/run-retail-q1.sh
```

Script tự động thực hiện toàn bộ chu trình:
1. Upload dữ liệu lên HDFS
2. Biên dịch Java, đóng gói JAR
3. Chạy 6 cấu hình Mapper (1, 2, 5, 10, 20, 30), mỗi cấu hình 3 lần
4. Đo thời gian từng lần chạy, ghi vào CSV
5. Lấy kết quả MapReduce về local
6. Gọi Python xuất Excel `.xlsx` và vẽ biểu đồ `.png`

### Câu 2 — Đếm khách hàng duy nhất theo quốc gia

```bash
./scripts/run-retail-q2.sh
```

---

## Kết quả đầu ra

Mỗi lần chạy benchmark tạo thư mục `result/<ngày-giờ>_Q1/` (hoặc `_Q2/`) chứa:

| File | Mô tả |
|---|---|
| `part-r-00000` | Kết quả MapReduce (Country, Count) |
| `q1_raw_times.csv` | Thời gian thô: `So Mapper,Lan chay,Thoi gian` |
| `q1_benchmark_<timestamp>.xlsx` | Bảng số liệu Excel (Run 1/2/3, Avg Time, Speedup) |
| `q1_speedup_chart_<timestamp>.png` | Biểu đồ Bar (Time) + Line (Speedup) |

---

## Cấu trúc logic MapReduce — Câu 1

Đếm số lượng hóa đơn (Invoice) duy nhất theo quốc gia. **Không lọc hóa đơn hủy.**

```
online_retail_II.csv
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  MAPPER (RetailMapper)                                      │
│  1. Bỏ qua dòng header                                      │
│  2. Tách CSV bằng regex: ,(?=(?:[^"]*"[^"]*")*[^"]*$)      │
│  3. Clean ngoặc kép: replaceAll("^\"|\"$", "").trim()       │
│  4. Ép số Mapper: split.maxsize = fileSize / numMappers     │
│  5. Emit key=Country, value=Invoice                         │
└─────────────────────────────────────────────────────────────┘
        │
        ▼  Shuffle & Sort
┌─────────────────────────────────────────────────────────────┐
│  REDUCER (RetailReducer)                                    │
│  1. HashSet<String> loại bỏ Invoice trùng lặp              │
│  2. Emit key=Country, value=count                           │
└─────────────────────────────────────────────────────────────┘
```

Kết quả ví dụ (Australia = 117):

```
Australia       117
Austria         41
Belgium         158
France          680
Germany         964
United Kingdom  20675
```

---

## Cấu trúc logic MapReduce — Câu 2

Đếm số lượng khách hàng (Customer ID) duy nhất theo quốc gia. Bỏ qua dòng có Customer ID rỗng.

```
online_retail_II.csv
        │
        ▼
┌─────────────────────────────────────────────────────────────┐
│  MAPPER (RetailMapper)                                      │
│  1. Bỏ qua dòng header                                      │
│  2. Tách CSV bằng regex                                     │
│  3. Clean ngoặc kép cho tất cả trường                       │
│  4. Lọc: bỏ Invoice bắt đầu bằng "C", bỏ Customer ID rỗng  │
│  5. Ép số Mapper: split.maxsize = fileSize / numMappers     │
│  6. Emit key=Country, value=CustomerID                      │
└─────────────────────────────────────────────────────────────┘
        │
        ▼  Shuffle & Sort
┌─────────────────────────────────────────────────────────────┐
│  REDUCER (RetailReducer)                                    │
│  1. HashSet<String> loại bỏ CustomerID trùng lặp           │
│  2. Emit key=Country, value=count                           │
└─────────────────────────────────────────────────────────────┘
```

---

## Giám sát hệ thống

| Giao diện | Địa chỉ | Chức năng |
|---|---|---|
| HDFS NameNode UI | `http://10.32.2.236:9870` | Trạng thái NameNode, DataNode, duyệt file HDFS |
| YARN ResourceManager UI | `http://10.32.2.236:8088` | Jobs, trạng thái cluster, NodeManagers |

---

## Khắc phục lỗi thường gặp

**Lỗi `namenode can only be executed by root`:**
Script `start-hadoop.sh` tự xử lý — tự động chạy lại với sudo.

**Lỗi `JAVA_HOME is not set`:**
Script hardcode `JAVA_HOME` và truyền qua sudo + SSH. Đảm bảo Java 8 đã cài trên cả 3 VPS.

**Lỗi `secondarynamenode is running as process XXXX`:**
Script tự dừng daemon cũ trước khi khởi động. Nếu vẫn lỗi, dừng thủ công:
```bash
sudo -E /opt/hadoop/bin/hdfs --daemon stop secondarynamenode
sudo -E /opt/hadoop/bin/hdfs --daemon stop namenode
sudo -E /opt/hadoop/bin/yarn --daemon stop resourcemanager
```

**Lỗi `Permission denied` khi SSH sang Worker:**
SSH passwordless phải thiết lập cho user `ubuntu` (không phải root):
```bash
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
ssh-copy-id ubuntu@10.32.2.213
ssh-copy-id ubuntu@10.32.2.125
```

**Lỗi HDFS permission denied khi chạy benchmark:**
Script `start-hadoop.sh` đã tự `chown /data` cho user `ubuntu`. Nếu vẫn lỗi:
```bash
sudo -E hdfs dfs -chmod -R 777 /data
sudo -E hdfs dfs -chown -R ubuntu /data
```

**Lỗi `bad interpreter: /bin/bash^M`:**
Do Windows line endings:
```bash
dos2unix scripts/*.sh scripts/*.py
```

**Kiểm tra trạng thái cluster:**
```bash
jps                           # Các daemon đang chạy
hdfs dfsadmin -report         # Số DataNode sống
yarn node -list               # Các NodeManager
```

---

## Pull cập nhật mới nhất

Khi đồng đội push code mới lên GitHub, trên Master chỉ cần:

```bash
cd ~/Hadoop-Docker-Cluster
git pull origin main
```

File `.env` nằm trong `.gitignore` nên không bị ghi đè khi pull.

---

## Cấu trúc thư mục dự án

```
Hadoop-Docker-Cluster/
├── .env.example                    # Template biến môi trường
├── .env                            # Biến môi trường thật (gitignored)
├── scripts/
│   ├── sync_cluster_config.sh      # Sinh & đồng bộ cấu hình từ .env
│   ├── start-hadoop.sh             # Stop old daemons, format, start cluster, set HDFS permissions
│   ├── run-retail-q1.sh            # Benchmark Câu 1 (6 Mapper x 3 lần)
│   ├── run-retail-q2.sh            # Benchmark Câu 2 (6 Mapper x 3 lần)
│   ├── plot_speedup_q1.py          # Phân tích & xuất Excel/Chart Câu 1
│   └── plot_speedup_q2.py          # Phân tích & xuất Excel/Chart Câu 2
├── data/
│   ├── OnlineRetailQ1.java
│   ├── OnlineRetailQ2.java
│   └── online_retail_II.csv
└── result/                         # Kết quả benchmark (tạo tự động)
```
