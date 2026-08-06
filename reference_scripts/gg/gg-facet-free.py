"""gg-facet-free.py — plotnine reference for examples/gg/gg-facet-free.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_point, facet_wrap

rows = []
for gi, g in enumerate(['a', 'b', 'c', 'd']):
    scale = 10 ** gi
    for i in range(12):
        rows.append({'g': g,
                     'x': i * 0.5,
                     'y': scale * (1.0 + 0.4*math.sin(i + gi))})
df = pd.DataFrame(rows)

p = (ggplot(df, aes('x', 'y')) + geom_point()
     + facet_wrap('g', scales='free_y'))
p.save('reference_images/gg/gg-facet-free.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-facet-free.png')
