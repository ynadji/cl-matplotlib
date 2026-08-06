"""gg-violin.py — plotnine reference for examples/gg/gg-violin.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_violin

rows = []
for gi, g in enumerate(['a', 'b', 'c']):
    for i in range(80):
        v = 3*math.sin(i*0.9 + gi) + math.cos(i*0.31) + gi*1.5
        rows.append({'grp': g, 'v': v})
df = pd.DataFrame(rows)

p = ggplot(df, aes('grp', 'v')) + geom_violin()
p.save('reference_images/gg/gg-violin.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-violin.png')
