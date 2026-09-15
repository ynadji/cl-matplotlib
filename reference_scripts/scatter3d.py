"""scatter3d.py — Reference for examples/scatter3d.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

xs, ys, zs, cs = [], [], [], []
for k in range(60):
    tt = 4.0 * math.pi * (k / 59.0)
    r = 1.0 + 0.02 * k
    xs.append(r * math.cos(tt))
    ys.append(r * math.sin(tt))
    zs.append(k / 10.0)
    cs.append(k / 59.0)

fig = plt.figure(figsize=(6.4, 4.8))
ax = fig.add_subplot(projection='3d')
ax.scatter(xs, ys, zs, c=cs, cmap='plasma', s=30)
ax.set_xlabel('x')
ax.set_ylabel('y')
ax.set_zlabel('z')
ax.set_title('3D scatter')

plt.savefig('reference_images/scatter3d.png', dpi=100)
plt.savefig('reference_images/scatter3d.svg')
plt.savefig('reference_images/scatter3d.pdf')
print('Saved reference_images/scatter3d.png')
