"""gg-rug-scatter.py — plotnine reference for examples/gg/gg-rug-scatter.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_point, geom_rug

xs = [i*0.25 + 0.5*math.sin(i) for i in range(40)]
ys = [2.0 + 0.8*x + 1.5*math.cos(x) for x in xs]
df = pd.DataFrame({'x': xs, 'y': ys})

p = ggplot(df, aes('x', 'y')) + geom_point() + geom_rug()
p.save('reference_images/gg/gg-rug-scatter.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-rug-scatter.png')
