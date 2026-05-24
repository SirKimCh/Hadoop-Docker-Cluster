import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from datetime import datetime

CSV_FILE = '/result/q2_execution_times.csv'
TIMESTAMP = datetime.now().strftime('%d-%m-%Y_%H-%M')
EXCEL_FILE = f'/result/q2_results_{TIMESTAMP}.xlsx'
CHART_FILE = f'/result/q2_speedup_{TIMESTAMP}.png'

df = pd.read_csv(CSV_FILE)

stats = df.groupby('Mapper')['Time'].agg(['mean', 'std', 'min', 'max']).reset_index()
stats.columns = ['Mapper', 'Mean Time', 'Std Dev', 'Min Time', 'Max Time']

t1_mean = stats.loc[stats['Mapper'] == 1, 'Mean Time'].values[0]
stats['Speedup'] = t1_mean / stats['Mean Time']

overall_mean = df['Time'].mean()
stats['Overall Mean'] = overall_mean

with pd.ExcelWriter(EXCEL_FILE, engine='openpyxl') as writer:
    df.to_excel(writer, sheet_name='Raw Data', index=False)
    stats.to_excel(writer, sheet_name='Statistics', index=False)
    summary = pd.DataFrame({
        'Metric': ['Overall Mean Time (s)', 'Best Speedup', 'Best Mapper Count'],
        'Value': [round(overall_mean, 2), round(stats['Speedup'].max(), 2), int(stats.loc[stats['Speedup'].idxmax(), 'Mapper'])]
    })
    summary.to_excel(writer, sheet_name='Summary', index=False)

fig, ax1 = plt.subplots(figsize=(10, 6))

color1 = '#2196F3'
ax1.set_xlabel('Number of Mappers')
ax1.set_ylabel('Average Execution Time (seconds)', color=color1)
ax1.plot(stats['Mapper'], stats['Mean Time'], 'o-', color=color1, linewidth=2, markersize=8)
ax1.tick_params(axis='y', labelcolor=color1)

ax2 = ax1.twinx()
color2 = '#FF5722'
ax2.set_ylabel('Speedup (T1/Tn)', color=color2)
ax2.plot(stats['Mapper'], stats['Speedup'], 's--', color=color2, linewidth=2, markersize=8)
ax2.tick_params(axis='y', labelcolor=color2)

plt.title('MapReduce Q2: Execution Time & Speedup')
fig.tight_layout()
plt.savefig(CHART_FILE, dpi=150)

print(f"Excel: {EXCEL_FILE}")
print(f"Chart: {CHART_FILE}")
print()
print(stats.to_string(index=False))
