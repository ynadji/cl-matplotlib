"""gg-line-basic.py — plotnine reference for examples/gg/gg-line-basic.lisp

Default geom_line: calibrates line width and color through the pipeline.
"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'

import math
import pandas as pd
from plotnine import ggplot, aes, geom_line, labs

xs = [i * 0.25 for i in range(41)]           # 0 .. 10
ys = [math.sin(x) * math.exp(-x / 5.0) for x in xs]

df = pd.DataFrame({'t': xs, 'signal': ys})

p = (ggplot(df, aes('t', 'signal'))
     + geom_line()
     + labs(x='time', y='damped sine'))
p.save('reference_images/gg/gg-line-basic.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-line-basic.png')
