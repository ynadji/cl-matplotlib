"""gg-facet-grid.py — plotnine reference for examples/gg/gg-facet-grid.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_point, facet_grid

rows = []
for gi, g in enumerate(['u', 'v']):
    for hi, h in enumerate(['p', 'q', 'r']):
        for i in range(8):
            rows.append({'g': g, 'h': h,
                         'x': i * 0.6 + 0.3*gi,
                         'y': math.sin(i + gi + 2*hi) + 2*hi + gi})
df = pd.DataFrame(rows)

p = ggplot(df, aes('x', 'y')) + geom_point() + facet_grid('g ~ h')
p.save('reference_images/gg/gg-facet-grid.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-facet-grid.png')
