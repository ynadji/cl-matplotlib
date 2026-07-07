"""gg-bar-flip.py — plotnine reference for examples/gg/gg-bar-flip.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_bar, coord_flip

cuts = (['Fair'] * 3 + ['Good'] * 9 + ['Ideal'] * 14 +
        ['Premium'] * 7 + ['Very Good'] * 11)
df = pd.DataFrame({'cut': cuts})

p = ggplot(df, aes('cut')) + geom_bar() + coord_flip()
p.save('reference_images/gg/gg-bar-flip.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-bar-flip.png')
