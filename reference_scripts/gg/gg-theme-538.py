"""gg-theme-538.py — plotnine reference for examples/gg/gg-theme-538.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_point, geom_line, theme_538

df = pd.DataFrame({
    'x': [i * 0.5 for i in range(21)],
    'y': [((i * 37) % 97) / 97.0 * 8.0 for i in range(21)],
})
p = (ggplot(df, aes('x', 'y')) + geom_point() + geom_line()
     + theme_538())
p.save('reference_images/gg/gg-theme-538.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-theme-538.png')
