"""gg-annotate.py — plotnine reference for examples/gg/gg-annotate.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import (ggplot, aes, geom_line, geom_hline, geom_vline,
                      annotate)

xs = [i*0.2 for i in range(50)]
ys = [math.sin(x)*math.exp(-x/8.0) for x in xs]
df = pd.DataFrame({'x': xs, 'y': ys})

p = (ggplot(df, aes('x', 'y')) + geom_line()
     + geom_hline(yintercept=0, linetype='dashed', color='#999999')
     + geom_vline(xintercept=math.pi, linetype='dashed', color='#999999')
     + annotate('text', x=math.pi + 2.2, y=0.8, label='first zero crossing')
     + annotate('rect', xmin=6, xmax=8, ymin=-0.3, ymax=0.3,
                alpha=0.2, fill='#3366FF'))
p.save('reference_images/gg/gg-annotate.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-annotate.png')
