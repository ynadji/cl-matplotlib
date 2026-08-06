"""axline-demo.py — reference for examples/axline-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.axline((0, 0), slope=1, color='C0', linewidth=2)
ax.axline((0, 2), (1, 3), color='C1', linestyle='--')
ax.axline((2, 0), slope=-0.5, color='C2')
ax.set_xlim(-1, 5)
ax.set_ylim(-1, 5)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/axline-demo.{ext}')
print('Saved reference_images/axline-demo.png')
