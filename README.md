# Hadoop 3.1.2 Native Cluster — 3 VPS Ubuntu

## Tổng quan

Triển khai cụm Hadoop 3.1.2 native trên 3 VPS Ubuntu (không dùng Docker):

| Node | Vai trò | Dịch vụ |
|---|---|---|
| Master | NameNode | NameNode + SecondaryNameNode + ResourceManager |
| Worker 1 | DataNode | DataNode + NodeManager |
| Worker 2 | DataNode | DataNode + NodeManager |

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

### 1.4. JAVA_HOME cho Hadoop

Sửa file `$HADOOP_HOME/etc/hadoop/hadoop-env.sh`:

```bash
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
```

### 1.5. Python 3 và các thư viện

```bash
sudo apt install -y python3 python3-pip
pip3 install pandas matplotlib openpyxl
```

### 1.6. rsync

```bash
sudo apt install -y rsync
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
ssh-copy-id ubuntu@<WORKER1_IP>
ssh-copy-id ubuntu@<WORKER2_IP>
```

### 2.3. Kiểm tra kết nối

```bash
ssh ubuntu@<WORKER1_IP> hostname
ssh ubuntu@<WORKER2_IP> hostname
```

---

## Bước 3: Điền file `.env` và chạy script đồng bộ cụm

### 3.1. Cấu hình `.env`

Trên **Master**, copy file mẫu và điền IP thực tế:

```bash
cd /path/to/Hadoop-Docker-Cluster
cp .env.example .env
nano .env
```

Nội dung `.env`:

```
MASTER_IP=<IP_Master>
WORKER1_IP=<IP_Worker1>
WORKER2_IP=<IP_Worker2>
SSH_USER=ubuntu
HADOOP_HOME=/opt/hadoop
```

### 3.2. Chạy script đồng bộ cấu hình

```bash
chmod +x scripts/sync_cluster_config.sh
./scripts/sync_cluster_config.sh
```

Script sẽ:
1. Đọc IP từ file `.env`
2. Sinh 4 file XML (`core-site.xml`, `hdfs-site.xml`, `yarn-site.xml`, `mapred-site.xml`) và file `workers`
3. Copy cấu hình vào `$HADOOP_HOME/etc/hadoop/` trên Master
4. Dùng `rsync` đẩy cấu hình sang 2 Worker

---

## Bước 4: Format NameNode và Start Cluster

### 4.1. Khởi động cụm Hadoop

Trên **Master**:

```bash
chmod +x scripts/start-hadoop.sh
./scripts/start-hadoop.sh
```

Script sẽ:
1. Format HDFS (lần đầu tiên)
2. Khởi động NameNode và SecondaryNameNode trên Master
3. SSH sang 2 Worker, khởi động DataNode và NodeManager
4. Khởi động ResourceManager trên Master
5. Chạy `jps` để xác nhận

### 4.2. Xác nhận cluster hoạt động

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
chmod +x scripts/run-retail-q1.sh
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
chmod +x scripts/run-retail-q2.sh
./scripts/run-retail-q2.sh
```

---

## Bước 6: Triển khai nhanh qua GitHub (CI/CD)

Toàn bộ mã nguồn dự án được quản lý trên GitHub. Đồng đội trên VPS chỉ cần clone repo và chạy script tự động.

### 6.1. Clone dự án từ GitHub

Trên **Master VPS** (`10.32.2.236`):

```bash
cd /home/ubuntu
git clone https://github.com/SirKimCh/Hadoop-Docker-Cluster.git
cd Hadoop-Docker-Cluster
```

### 6.2. Cấu hình `.env`

```bash
cp .env.example .env
nano .env
```

Điền IP thực tế:

```
MASTER_IP=10.32.2.236
WORKER1_IP=10.32.2.213
WORKER2_IP=10.32.2.125
SSH_USER=ubuntu
HADOOP_HOME=/opt/hadoop
```

### 6.3. Cấp quyền thực thi cho tất cả script

```bash
chmod +x scripts/*.sh
```

### 6.4. Triển khai tự động toàn cụm

Chạy tuần tự trên **Master**:

```bash
# Bước A: Đồng bộ cấu hình Hadoop sang 2 Worker
./scripts/sync_cluster_config.sh

# Bước B: Khởi động cụm Hadoop
./scripts/start-hadoop.sh

# Bước C: Chạy benchmark Câu 1 (tự động compile, chạy 6 Mapper x 3 lần, xuất Excel + Chart)
./scripts/run-retail-q1.sh

# Bước D: Chạy benchmark Câu 2
./scripts/run-retail-q2.sh
```

### 6.5. Pull cập nhật mới nhất

Khi đồng đội push code mới lên GitHub, trên Master chỉ cần:

```bash
cd /home/ubuntu/Hadoop-Docker-Cluster
git pull origin main
```

Sau đó chạy lại script cần thiết. File `.env` đã nằm trong `.gitignore` nên không bị ghi đè khi pull.

### 6.6. Luồng triển khai tổng thể

```
Developer (local)
    │
    │  git push origin main
    ▼
GitHub: SirKimCh/Hadoop-Docker-Cluster
    │
    │  git pull origin main
    ▼
Master VPS (10.32.2.236)
    │
    │  ./scripts/sync_cluster_config.sh  (rsync XML + workers)
    ├──► Worker 1 (10.32.2.213)
    └──► Worker 2 (10.32.2.125)
    │
    │  ./scripts/run-retail-q1.sh  (compile → HDFS → MapReduce → Python)
    ▼
result/<timestamp>_Q1/
    ├── part-r-00000          (kết quả MapReduce)
    ├── q1_raw_times.csv      (thời gian thô)
    ├── q1_benchmark_*.xlsx   (Excel)
    └── q1_speedup_chart_*.png (biểu đồ)
```

---

## Kết quả đầu ra

Mỗi lần chạy benchmark tạo thư mục `result/<ngày-giờ>_Q1/` (hoặc `_Q2/`) chứa:

| File | Mô tả |
|---|---|
| `part-r-00000` | Kết quả MapReduce (Country, Count) |
| `q1_raw_times.csv` | Thời gian thô: Mapper, Run, Time |
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
│  4. Emit key=Country, value=Invoice                         │
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
│  5. Emit key=Country, value=CustomerID                      │
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
| HDFS NameNode UI | `http://<MASTER_IP>:9870` | Trạng thái NameNode, DataNode, duyệt file HDFS |
| YARN ResourceManager UI | `http://<MASTER_IP>:8088` | Jobs, trạng thái cluster, NodeManagers |

---

## Cấu trúc thư mục dự án

```
Hadoop-Docker-Cluster/
├── .env.example                    # Template biến môi trường
├── scripts/
│   ├── sync_cluster_config.sh      # Sinh & đồng bộ cấu hình từ .env
│   ├── start-hadoop.sh             # Format HDFS, khởi động HDFS + YARN
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
