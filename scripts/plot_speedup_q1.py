import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

CSV_FILE = '/result/q1_execution_times.csv'
OUTPUT_FILE = '/result/q1_speedup_chart.png'

nodes = []
times = []

with open(CSV_FILE, 'r') as f:
    reader = csv.reader(f)
    for row in reader:
        nodes.append(int(row[0]))
        times.append(int(row[1]))

t1 = times[0]
speedup = [t1 / t for t in times]

fig, ax1 = plt.subplots(figsize=(10, 6))

color1 = '#2196F3'
ax1.set_xlabel('Number of Nodes')
ax1.set_ylabel('Execution Time (seconds)', color=color1)
ax1.plot(nodes, times, 'o-', color=color1, linewidth=2, markersize=8, label='Execution Time')
ax1.tick_params(axis='y', labelcolor=color1)

ax2 = ax1.twinx()
color2 = '#FF5722'
ax2.set_ylabel('Speedup (T1/Tn)', color=color2)
ax2.plot(nodes, speedup, 's--', color=color2, linewidth=2, markersize=8, label='Speedup')
ax2.tick_params(axis='y', labelcolor=color2)

plt.title('MapReduce Q1: Execution Time & Speedup')
fig.tight_layout()
plt.savefig(OUTPUT_FILE, dpi=150)
print(f"Chart saved to {OUTPUT_FILE}")
