"""gg-bin2d.py — plotnine reference for examples/gg/gg-bin2d.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_bin_2d

xs, ys = [], []
for i in range(500):
    xs.append(3.0*math.sin(i*12.9898) + 0.5*math.cos(i*3.7))
    ys.append(2.0*math.sin(i*78.233) + 0.5*math.sin(i*5.1))
df = pd.DataFrame({'x': xs, 'y': ys})

p = ggplot(df, aes('x', 'y')) + geom_bin_2d(bins=15)
p.save('reference_images/gg/gg-bin2d.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-bin2d.png')
