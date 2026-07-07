"""gg-errorbar.py — plotnine reference for examples/gg/gg-errorbar.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_errorbar, geom_point

df = pd.DataFrame({
    'trt':  ['a', 'b', 'c', 'd'],
    'mean': [3.2, 5.1, 4.4, 6.0],
    'lo':   [2.4, 4.4, 3.6, 5.1],
    'hi':   [4.0, 5.8, 5.2, 6.9],
})
p = (ggplot(df, aes('trt', 'mean'))
     + geom_errorbar(aes(ymin='lo', ymax='hi'), width=0.2)
     + geom_point(size=2))
p.save('reference_images/gg/gg-errorbar.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-errorbar.png')
