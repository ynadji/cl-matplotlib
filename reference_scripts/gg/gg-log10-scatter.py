"""gg-log10-scatter.py — plotnine reference for examples/gg/gg-log10-scatter.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_point, scale_x_log10, scale_y_log10

xs = [10**(i/6.0) for i in range(19)]              # 1 .. 1000
ys = [x**1.7 * 3.0 for x in xs]
df = pd.DataFrame({'x': xs, 'y': ys})

p = (ggplot(df, aes('x', 'y')) + geom_point()
     + scale_x_log10() + scale_y_log10())
p.save('reference_images/gg/gg-log10-scatter.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-log10-scatter.png')
