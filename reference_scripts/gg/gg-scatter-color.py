"""gg-scatter-color.py — plotnine reference for examples/gg/gg-scatter-color.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_point

xs = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0,
      1.2, 2.3, 3.1, 4.2, 1.8, 2.9, 3.7, 4.6, 0.8, 3.4]
ys = [1.1, 1.9, 3.2, 4.1, 5.4, 6.2, 7.7, 8.1, 9.6, 10.2,
      2.6, 4.9, 6.5, 8.8, 3.5, 5.8, 7.2, 9.3, 1.5, 6.9]
grp = (['a', 'b', 'c', 'a', 'b'] * 4)

df = pd.DataFrame({'wt': xs, 'mpg': ys, 'grp': grp})

p = ggplot(df, aes('wt', 'mpg', color='grp')) + geom_point()
p.save('reference_images/gg/gg-scatter-color.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-scatter-color.png')
