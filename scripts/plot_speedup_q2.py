import sys
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from datetime import datetime

RAW_CSV = '/result/q2_raw_times.csv'
RES_DIR = sys.argv[1] if len(sys.argv) > 1 else '/result'
TIMESTAMP = datetime.now().strftime('%d-%m-%Y_%H-%M')

df = pd.read_csv(RAW_CSV)

pivot = df.pivot_table(index='Mapper', columns='Run', values='Time', aggfunc='first').reset_index()
pivot.columns = ['Mapper'] + [f'Run {int(c)}' for c in pivot.columns[1:]]

pivot['Avg Time'] = df.groupby('Mapper')['Time'].mean().values

t1_avg = pivot.loc[pivot['Mapper'] == 1, 'Avg Time'].values[0]
pivot['Speedup'] = t1_avg / pivot['Avg Time']

EXCEL_FILE = f'{RES_DIR}/q2_benchmark_{TIMESTAMP}.xlsx'
with pd.ExcelWriter(EXCEL_FILE, engine='openpyxl') as writer:
    df.to_excel(writer, sheet_name='Raw Data', index=False)
    pivot.to_excel(writer, sheet_name='Statistics', index=False)
    summary = pd.DataFrame({
        'Metric': ['Best Speedup', 'Best Mapper Count', 'Baseline Time (1 Mapper)'],
        'Value': [
            round(pivot['Speedup'].max(), 2),
            int(pivot.loc[pivot['Speedup'].idxmax(), 'Mapper']),
            round(t1_avg, 2)
        ]
    })
    summary.to_excel(writer, sheet_name='Summary', index=False)

CHART_FILE = f'{RES_DIR}/q2_speedup_chart_{TIMESTAMP}.png'
fig, ax1 = plt.subplots(figsize=(10, 6))

ax1.set_xlabel('Number of Mappers')
ax1.set_ylabel('Average Execution Time (seconds)', color='#2196F3')
ax1.bar(pivot['Mapper'], pivot['Avg Time'], color='#2196F3', alpha=0.7, label='Avg Time')
ax1.tick_params(axis='y', labelcolor='#2196F3')

ax2 = ax1.twinx()
ax2.set_ylabel('Speedup (T1/Tn)', color='#FF5722')
ax2.plot(pivot['Mapper'], pivot['Speedup'], 's-', color='#FF5722', linewidth=2, markersize=8, label='Speedup')
ax2.tick_params(axis='y', labelcolor='#FF5722')

plt.title('MapReduce Q2: Execution Time & Speedup')
fig.tight_layout()
plt.savefig(CHART_FILE, dpi=150)

print(f"Excel : {EXCEL_FILE}")
print(f"Chart : {CHART_FILE}")
print()
print(pivot.to_string(index=False))
