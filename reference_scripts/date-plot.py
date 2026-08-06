"""date-plot.py — reference for examples/date-plot.lisp

datetime x-axis with the AutoDateLocator + ConciseDateFormatter defaults.
"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
from datetime import datetime
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

dates = [datetime(2024, m, 1) for m in range(1, 13)]
vals = [10 + 3*math.sin(i*0.9) for i in range(12)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.plot(dates, vals)
ax.xaxis.set_major_locator(mdates.AutoDateLocator())
ax.xaxis.set_major_formatter(mdates.ConciseDateFormatter(ax.xaxis.get_major_locator()))
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/date-plot.{ext}')
print('Saved reference_images/date-plot.png')
