"""gg-bin2d.py — plotnine reference for examples/gg/gg-bin2d.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_bin_2d

# integer-mod quasi-random data: bit-exact across languages
xs, ys = [], []
for i in range(500):
    xs.append(((i*37) % 97) / 97.0 * 7.0 - 3.5)
    ys.append(((i*53) % 89) / 89.0 * 5.0 - 2.5)
df = pd.DataFrame({'x': xs, 'y': ys})

p = ggplot(df, aes('x', 'y')) + geom_bin_2d(bins=15)
p.save('reference_images/gg/gg-bin2d.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-bin2d.png')
