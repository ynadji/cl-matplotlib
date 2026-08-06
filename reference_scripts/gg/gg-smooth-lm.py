"""gg-smooth-lm.py — plotnine reference for examples/gg/gg-smooth-lm.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_point, geom_smooth

xs = [i*0.25 for i in range(40)]
ys = [1.5*x + 2 + 2.5*math.sin(x*2.7) for x in xs]
df = pd.DataFrame({'x': xs, 'y': ys})

p = ggplot(df, aes('x', 'y')) + geom_point() + geom_smooth(method='lm')
p.save('reference_images/gg/gg-smooth-lm.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-smooth-lm.png')
