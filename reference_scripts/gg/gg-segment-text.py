"""gg-segment-text.py — plotnine reference for examples/gg/gg-segment-text.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_segment, geom_point, geom_text

df = pd.DataFrame({
    'name': ['alpha', 'beta', 'gamma', 'delta', 'epsilon'],
    'v':    [4.2, 7.8, 2.9, 6.1, 5.0],
})
p = (ggplot(df, aes('name', 'v'))
     + geom_segment(aes(xend='name', y=0, yend='v'), color='#666666')
     + geom_point(size=3, color='#DB5F57')
     + geom_text(aes(label='v'), nudge_y=0.45, size=9))
p.save('reference_images/gg/gg-segment-text.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-segment-text.png')
