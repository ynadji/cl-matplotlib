"""gg-area-stacked.py — plotnine reference for examples/gg/gg-area-stacked.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_area

rows = []
for x in range(30):
    for si, s in enumerate(['u', 'v', 'w']):
        y = 2 + si + math.sin(x*0.4 + si*2.0) + 0.05*x
        rows.append({'x': float(x), 's': s, 'y': y})
df = pd.DataFrame(rows)

p = ggplot(df, aes('x', 'y', fill='s')) + geom_area()
p.save('reference_images/gg/gg-area-stacked.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-area-stacked.png')
