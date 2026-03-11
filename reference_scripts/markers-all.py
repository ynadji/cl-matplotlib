"""markers-all.py — Reference for examples/markers-all.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

markers = ['o', 's', '^', 'v', '<', '>', 'D', 'p', 'h', 'd', 'P', 'X', '+', 'x', '*', '|', '_', '.']
names = ['circle', 'square', 'triangle_up', 'triangle_down', 'triangle_left', 'triangle_right',
         'diamond', 'pentagon', 'hexagon', 'thin_diamond', 'plus_filled', 'x_filled',
         'plus', 'x', 'star', 'vline', 'hline', 'point']
fig, ax = plt.subplots(figsize=(8, 6))
n = len(markers)
cols = 6
rows = (n + cols - 1) // cols
for i, (m, name) in enumerate(zip(markers, names)):
    row, col = divmod(i, cols)
    ax.plot(col, rows - row - 1, marker=m, markersize=12, linestyle='none',
            color='steelblue', markeredgecolor='black', markeredgewidth=0.5)
    ax.text(col + 0.15, rows - row - 1, name, va='center', fontsize=7)
ax.set_xlim(-0.5, cols + 2)
ax.set_ylim(-0.5, rows + 0.5)
ax.axis('off')
ax.set_title('Marker Types')

plt.savefig('reference_images/markers-all.png', dpi=100)
plt.savefig('reference_images/markers-all.svg')
print('Saved reference_images/markers-all.svg')
plt.savefig('reference_images/markers-all.pdf')
print('Saved reference_images/markers-all.pdf')
print('Saved reference_images/markers-all.png')
plt.close('all')
