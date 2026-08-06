"""gg-legend-left.py — plotnine reference for examples/gg/gg-legend-left.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_point, theme

df = pd.DataFrame({
    'x': [1.0, 2, 3, 4, 5, 6],
    'y': [2.0, 4, 3, 5, 4, 6],
    'grp': pd.Categorical(['a', 'b', 'c', 'a', 'b', 'c']),
})
p = (ggplot(df, aes('x', 'y', color='grp')) + geom_point(size=3)
     + theme(legend_position='left'))
p.save('reference_images/gg/gg-legend-left.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-legend-left.png')
