"""gg-density.py — plotnine reference for examples/gg/gg-density.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_density

vals = [3*math.sin(i*0.7) + 2*math.cos(i*0.13) + i*0.01 for i in range(200)]
df = pd.DataFrame({'v': vals})

p = ggplot(df, aes('v')) + geom_density(fill='#4477AA', alpha=0.4)
p.save('reference_images/gg/gg-density.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-density.png')
