"""spy-demo.py — reference for examples/spy-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import numpy as np
import matplotlib.pyplot as plt

z = np.zeros((20, 20))
for i in range(20):
    z[i, i] = 1.0
    z[i, (i*7) % 20] = 1.0
    if i > 2:
        z[i, i-3] = 1.0

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.spy(z)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/spy-demo.{ext}')
print('Saved reference_images/spy-demo.png')
