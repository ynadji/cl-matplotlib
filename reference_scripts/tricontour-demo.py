"""tricontour-demo.py — reference for examples/tricontour-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

n = 200
xs = [((i*37) % 97)/97.0 * 10.0 for i in range(n)]
ys = [((i*53) % 89)/89.0 * 8.0 for i in range(n)]
zs = [math.sin(x*0.6) * math.cos(y*0.5) for x, y in zip(xs, ys)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.tricontour(xs, ys, zs, levels=7)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/tricontour-demo.{ext}')
print('Saved reference_images/tricontour-demo.png')
