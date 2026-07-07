"""gg-reverse.py — plotnine reference for examples/gg/gg-reverse.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_line, scale_y_reverse

xs = [i*0.25 for i in range(41)]
ys = [5.0 + 3.0*math.sin(x) + 0.4*x for x in xs]
df = pd.DataFrame({'x': xs, 'depth': ys})

p = ggplot(df, aes('x', 'depth')) + geom_line() + scale_y_reverse()
p.save('reference_images/gg/gg-reverse.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-reverse.png')
