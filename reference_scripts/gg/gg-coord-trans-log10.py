"""gg-coord-trans-log10.py — plotnine reference for
examples/gg/gg-coord-trans-log10.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_point, coord_trans

df = pd.DataFrame({
    'x': [1.0, 2, 5, 10, 20, 50, 100, 200, 500, 1000],
    'y': [1.0, 3, 2, 5, 4, 7, 6, 8, 7, 9],
})
p = (ggplot(df, aes('x', 'y')) + geom_point()
     + coord_trans(x='log10'))
p.save('reference_images/gg/gg-coord-trans-log10.png', width=6.4,
       height=4.8, dpi=100, verbose=False)
print('Saved reference_images/gg/gg-coord-trans-log10.png')
