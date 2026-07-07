"""gg-bar-dodge.py — plotnine reference for examples/gg/gg-bar-dodge.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import pandas as pd
from plotnine import ggplot, aes, geom_bar, position_dodge

rows = []
for cut, counts in [('Fair', {'D': 2, 'E': 3, 'F': 1}),
                    ('Good', {'D': 5, 'E': 4, 'F': 6}),
                    ('Ideal', {'D': 8, 'E': 10, 'F': 7})]:
    for clarity, n in counts.items():
        rows.extend([{'cut': cut, 'clarity': clarity}] * n)
df = pd.DataFrame(rows)

p = ggplot(df, aes('cut', fill='clarity')) + geom_bar(position='dodge')
p.save('reference_images/gg/gg-bar-dodge.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-bar-dodge.png')
