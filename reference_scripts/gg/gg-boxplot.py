"""gg-boxplot.py — plotnine reference for examples/gg/gg-boxplot.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_boxplot

rows = []
for gi, g in enumerate(['a', 'b', 'c']):
    for i in range(60):
        v = 3*math.sin(i*0.9 + gi) + gi*1.5 + (2.5 if i == 7 else 0) * (gi + 1)
        rows.append({'grp': g, 'v': v})
df = pd.DataFrame(rows)

p = ggplot(df, aes('grp', 'v')) + geom_boxplot()
p.save('reference_images/gg/gg-boxplot.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-boxplot.png')
