"""colormaps-extended.py — reference for examples/colormaps-extended.lisp

Gradient strips through a sample of the extended colormap registry
(matplotlib-parity tables + _r variants).
"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import numpy as np
import matplotlib.pyplot as plt

CMAPS = ['turbo', 'tab10', 'PuOr', 'YlGnBu', 'twilight', 'seismic',
         'Oranges', 'cubehelix', 'viridis_r']

gradient = np.linspace(0, 1, 256).reshape(1, -1)

fig, axes = plt.subplots(len(CMAPS), 1, figsize=(6.4, 4.8), dpi=100)
for ax, name in zip(axes, CMAPS):
    ax.imshow(gradient, aspect='auto', cmap=name)
    ax.set_xticks([])
    ax.set_yticks([])
    ax.set_ylabel(name, rotation=0, ha='right', va='center', fontsize=9)

for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/colormaps-extended.{ext}')
print('Saved reference_images/colormaps-extended.png')
