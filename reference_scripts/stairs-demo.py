"""stairs-demo.py — reference for examples/stairs-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

values = [math.sin(i*0.5) + 2 for i in range(14)]
edges = [i * 0.5 for i in range(15)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.stairs(values, edges, fill=True, alpha=0.4, color='C0')
ax.stairs([v + 1 for v in values], edges, color='C1', linewidth=2)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/stairs-demo.{ext}')
print('Saved reference_images/stairs-demo.png')
