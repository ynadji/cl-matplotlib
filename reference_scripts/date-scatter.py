"""date-scatter.py — reference for examples/date-scatter.lisp

Scatter with datetimes on x (converter registry path).
"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

start = datetime(2024, 6, 1)
dates = [start + timedelta(days=i) for i in range(0, 10)]
vals = [3 + math.cos(i*0.8) for i in range(10)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.scatter(dates, vals)
ax.xaxis.set_major_locator(mdates.AutoDateLocator())
ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(ax.xaxis.get_major_locator()))
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/date-scatter.{ext}')
print('Saved reference_images/date-scatter.png')
