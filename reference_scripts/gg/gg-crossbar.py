"""gg-crossbar.py — plotnine reference for examples/gg/gg-crossbar.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_crossbar

df = pd.DataFrame({
    'trt': ['a', 'b', 'c', 'd'],
    'mid': [3.2, 5.1, 4.4, 6.0],
    'lo':  [2.4, 4.4, 3.6, 5.1],
    'hi':  [4.0, 5.8, 5.2, 6.9],
})
p = (ggplot(df, aes('trt', 'mid', ymin='lo', ymax='hi'))
     + geom_crossbar(width=0.5))
p.save('reference_images/gg/gg-crossbar.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-crossbar.png')
