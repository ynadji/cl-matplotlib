"""gg-qq-basic.py — plotnine reference for examples/gg/gg-qq-basic.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_qq

# integer-mod quasi-random sample: bit-exact across languages
vals = [3.0 + 3.0 * (((i*37) % 97) / 97.0 - 0.5) * (((i*53) % 89) / 89.0 + 0.5)
        for i in range(80)]
df = pd.DataFrame({'v': vals})

p = ggplot(df, aes(sample='v')) + geom_qq()
p.save('reference_images/gg/gg-qq-basic.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-qq-basic.png')
