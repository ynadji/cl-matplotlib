"""trisurf3d.py — Reference for examples/trisurf3d.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

xs, ys, zs = [], [], []
for ri in range(1, 9):
    r = ri / 8.0
    for ai in range(24):
        a = 2.0 * math.pi * (ai / 24.0)
        x, y = r * math.cos(a), r * math.sin(a)
        xs.append(x); ys.append(y); zs.append(math.sin(-x * y))

fig = plt.figure(figsize=(6.4, 4.8))
ax = fig.add_subplot(projection='3d')
ax.plot_trisurf(xs, ys, zs, cmap='viridis', linewidth=0.2, edgecolor='black')
ax.set_xlabel('x')
ax.set_ylabel('y')
ax.set_zlabel('z')
ax.set_title('triangulated surface')

plt.savefig('reference_images/trisurf3d.png', dpi=100)
plt.savefig('reference_images/trisurf3d.svg')
plt.savefig('reference_images/trisurf3d.pdf')
print('Saved reference_images/trisurf3d.png')
