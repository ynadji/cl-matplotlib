"""gg-bar-basic.py — plotnine reference for examples/gg/gg-bar-basic.lisp

Default geom_bar (stat_count) over a discrete variable.
"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'

import pandas as pd
from plotnine import ggplot, aes, geom_bar

cuts = (['Fair'] * 3 + ['Good'] * 9 + ['Ideal'] * 14 +
        ['Premium'] * 7 + ['Very Good'] * 11)
df = pd.DataFrame({'cut': cuts})

p = ggplot(df, aes('cut')) + geom_bar()
p.save('reference_images/gg/gg-bar-basic.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-bar-basic.png')
