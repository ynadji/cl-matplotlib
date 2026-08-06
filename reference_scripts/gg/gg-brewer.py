"""gg-brewer.py — plotnine reference for examples/gg/gg-brewer.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_col, scale_fill_brewer

df = pd.DataFrame({
    'grp': pd.Categorical(['a', 'b', 'c', 'd', 'e']),
    'v':   [4.0, 7.0, 3.0, 5.5, 6.2],
})
p = (ggplot(df, aes('grp', 'v', fill='grp')) + geom_col()
     + scale_fill_brewer(type='qual', palette='Set2'))
p.save('reference_images/gg/gg-brewer.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-brewer.png')
