"""ggblank.py — plotnine reference for examples/gg/ggblank.lisp

An empty (layer-less) plot: trains x/y scales on the data and renders the
default theme_gray panel. This is the calibration target for gg's
theme-gray, tick placement, and expansion constants.
"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'

import pandas as pd
from plotnine import ggplot, aes

df = pd.DataFrame({'x': [1.0, 2.0, 3.0, 4.0, 5.0],
                   'y': [10.0, 12.0, 16.0, 13.0, 20.0]})

p = ggplot(df, aes('x', 'y'))
p.save('reference_images/gg/ggblank.png', width=6.4, height=4.8, dpi=100,
       verbose=False)
print('Saved reference_images/gg/ggblank.png')
