"""gg-count.py — plotnine reference for examples/gg/gg-count.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_count

rows = []
for i in range(120):
    rows.append({'x': float((i * i) % 5), 'y': float((i * 7) % 4)})
df = pd.DataFrame(rows)

p = ggplot(df, aes('x', 'y')) + geom_count()
p.save('reference_images/gg/gg-count.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-count.png')
