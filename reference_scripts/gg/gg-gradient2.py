"""gg-gradient2.py — plotnine reference for examples/gg/gg-gradient2.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_tile, scale_fill_gradient2

rows = []
for i in range(12):
    for j in range(10):
        rows.append({'x': float(i), 'y': float(j),
                     'v': math.sin(i*0.5) * math.cos(j*0.6)})
df = pd.DataFrame(rows)

p = (ggplot(df, aes('x', 'y', fill='v')) + geom_tile()
     + scale_fill_gradient2(low='#832424', mid='#FFFFFF', high='#3A3A98',
                            midpoint=0))
p.save('reference_images/gg/gg-gradient2.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-gradient2.png')
