"""gg-histogram.py — plotnine reference for examples/gg/gg-histogram.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_histogram

vals = [3*math.sin(i*0.7) + 2*math.cos(i*0.13) + i*0.01 for i in range(200)]
df = pd.DataFrame({'v': vals})

p = ggplot(df, aes('v')) + geom_histogram(bins=20)
p.save('reference_images/gg/gg-histogram.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-histogram.png')
