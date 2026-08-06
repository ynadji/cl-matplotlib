"""tripcolor-demo.py — reference for examples/tripcolor-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

n = 120
xs = [((i*37) % 97)/97.0 * 10.0 for i in range(n)]
ys = [((i*53) % 89)/89.0 * 8.0 for i in range(n)]
cs = [math.sin(x*0.6) * math.cos(y*0.5) for x, y in zip(xs, ys)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.tripcolor(xs, ys, cs, shading='flat')
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/tripcolor-demo.{ext}')
print('Saved reference_images/tripcolor-demo.png')
