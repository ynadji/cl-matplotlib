"""gg-qq-basic.py — plotnine reference for examples/gg/gg-qq-basic.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_qq

# deterministic "random" sample: inverse-normal of a low-discrepancy sequence
vals = [3.0 + 1.5 * math.sin(i * 12.9898) * math.cos(i * 78.233) * 2.0
        for i in range(80)]
df = pd.DataFrame({'v': vals})

p = ggplot(df, aes(sample='v')) + geom_qq()
p.save('reference_images/gg/gg-qq-basic.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-qq-basic.png')
