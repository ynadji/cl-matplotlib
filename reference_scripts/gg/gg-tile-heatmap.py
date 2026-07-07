"""gg-tile-heatmap.py — plotnine reference for examples/gg/gg-tile-heatmap.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_tile

rows = []
for i in range(12):
    for j in range(10):
        rows.append({'x': float(i), 'y': float(j),
                     'v': math.sin(i*0.5) * math.cos(j*0.6)})
df = pd.DataFrame(rows)

p = ggplot(df, aes('x', 'y', fill='v')) + geom_tile()
p.save('reference_images/gg/gg-tile-heatmap.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-tile-heatmap.png')
