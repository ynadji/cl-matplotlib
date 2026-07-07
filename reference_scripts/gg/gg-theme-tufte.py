"""gg-theme-tufte.py — plotnine reference for examples/gg/gg-theme-tufte.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_point, geom_line, theme_tufte

df = pd.DataFrame({
    'x': [i * 0.5 for i in range(21)],
    'y': [((i * 37) % 97) / 97.0 * 8.0 for i in range(21)],
})
p = (ggplot(df, aes('x', 'y')) + geom_point() + geom_line()
     + theme_tufte())
p.save('reference_images/gg/gg-theme-tufte.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-theme-tufte.png')
