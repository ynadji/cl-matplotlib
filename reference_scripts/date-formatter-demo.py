"""date-formatter-demo.py — reference for examples/date-formatter-demo.lisp

Explicit DateFormatter + MonthLocator over daily data.
"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

start = datetime(2024, 1, 1)
dates = [start + timedelta(days=3*i) for i in range(60)]
vals = [5 + 2*math.sin(i*0.3) + i*0.02 for i in range(60)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.plot(dates, vals)
ax.xaxis.set_major_locator(mdates.MonthLocator())
ax.xaxis.set_major_formatter(mdates.DateFormatter('%b %Y'))
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/date-formatter-demo.{ext}')
print('Saved reference_images/date-formatter-demo.png')
