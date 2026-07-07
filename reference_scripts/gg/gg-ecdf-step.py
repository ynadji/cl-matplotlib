"""gg-ecdf-step.py — plotnine reference for examples/gg/gg-ecdf-step.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, stat_ecdf

vals = [5.0 + 2.0*math.sin(i*0.7) + i*0.05 for i in range(60)]
df = pd.DataFrame({'v': vals})

p = ggplot(df, aes('v')) + stat_ecdf()
p.save('reference_images/gg/gg-ecdf-step.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-ecdf-step.png')
