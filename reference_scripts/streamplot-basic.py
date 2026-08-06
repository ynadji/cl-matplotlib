"""streamplot-basic.py — Reference for examples/streamplot-basic.lisp

Uses matplotlib's real plt.streamplot. (An earlier version of this script
re-implemented the CL port's then-buggy algorithm so the comparison would
pass; the CL implementation is now a faithful port of matplotlib's, so the
genuine article is the correct reference.)
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

n = 20
x = np.linspace(-3, 3, n)
y = np.linspace(-3, 3, n)
X, Y = np.meshgrid(x, y)
U = -Y
V = X

fig, ax = plt.subplots(figsize=(8, 6))
ax.streamplot(X, Y, U, V, color='C0', linewidth=1.0, density=1.0)
ax.set_title('Streamplot — Rotational Flow')
ax.set_xlabel('X')
ax.set_ylabel('Y')
fig.savefig('reference_images/streamplot-basic.png')
fig.savefig('reference_images/streamplot-basic.svg')
print('Saved reference_images/streamplot-basic.svg')
fig.savefig('reference_images/streamplot-basic.pdf')
print('Saved reference_images/streamplot-basic.pdf')
print('Saved reference_images/streamplot-basic.png')
