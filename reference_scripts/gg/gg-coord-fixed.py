"""gg-coord-fixed.py — plotnine reference for examples/gg/gg-coord-fixed.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_point, geom_line, coord_fixed

df = pd.DataFrame({
    'x': [0.0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    'y': [0.0, 2, 1, 3, 2, 4, 3, 5, 4, 6, 5],
})
p = (ggplot(df, aes('x', 'y')) + geom_point() + geom_line()
     + coord_fixed(ratio=1))
p.save('reference_images/gg/gg-coord-fixed.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-coord-fixed.png')
