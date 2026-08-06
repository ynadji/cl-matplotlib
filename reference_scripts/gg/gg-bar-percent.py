"""gg-bar-percent.py — plotnine reference for examples/gg/gg-bar-percent.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_bar, after_stat

cuts = (['Fair'] * 3 + ['Good'] * 9 + ['Ideal'] * 14 +
        ['Premium'] * 7 + ['Very Good'] * 11)
df = pd.DataFrame({'cut': cuts})

p = ggplot(df, aes('cut', y=after_stat('count / count.sum()'))) + geom_bar()
p.save('reference_images/gg/gg-bar-percent.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-bar-percent.png')
