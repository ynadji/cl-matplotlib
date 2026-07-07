"""gg-dates.py — plotnine reference for examples/gg/gg-dates.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import pandas as pd
from plotnine import ggplot, aes, geom_line, scale_x_date

dates = pd.date_range('2023-01-01', periods=24, freq='MS')
vals = [10 + 3*math.sin(i*0.6) + i*0.2 for i in range(24)]
df = pd.DataFrame({'d': dates, 'v': vals})

p = (ggplot(df, aes('d', 'v')) + geom_line()
     + scale_x_date(date_breaks='6 months', date_labels='%Y-%m'))
p.save('reference_images/gg/gg-dates.png', width=6.4, height=4.8,
       dpi=100, verbose=False)
print('Saved reference_images/gg/gg-dates.png')
