"""gg-freqpoly.py — plotnine reference for examples/gg/gg-freqpoly.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_freqpoly

vals = [10.0 + 4.0*math.sin(i*1.7) + 2.5*math.cos(i*0.3) for i in range(120)]
df = pd.DataFrame({'v': vals})

p = ggplot(df, aes('v')) + geom_freqpoly(bins=15)
p.save('reference_images/gg/gg-freqpoly.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-freqpoly.png')
