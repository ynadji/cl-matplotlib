"""gg-abline.py — plotnine reference for examples/gg/gg-abline.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_point, geom_abline

xs = [i*0.5 for i in range(21)]
ys = [1.2*x + 0.8 + 1.5*math.sin(x*1.9) for x in xs]
df = pd.DataFrame({'x': xs, 'y': ys})

p = (ggplot(df, aes('x', 'y')) + geom_point()
     + geom_abline(slope=1.2, intercept=0.8, color='#DB5F57',
                   linetype='dashed', size=1))
p.save('reference_images/gg/gg-abline.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-abline.png')
