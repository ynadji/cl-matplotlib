"""triplot-demo.py — reference for examples/triplot-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

# deterministic scattered points (integer-mod, bit-exact across languages)
n = 40
xs = [((i*37) % 97)/97.0 * 10.0 for i in range(n)]
ys = [((i*53) % 89)/89.0 * 8.0 for i in range(n)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.triplot(xs, ys, color='C0', linewidth=1.0)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/triplot-demo.{ext}')
print('Saved reference_images/triplot-demo.png')
