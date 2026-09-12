"""lines3d.py — Reference for examples/lines3d.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

n = 200
ts = [8.0 * math.pi * (k / (n - 1)) for k in range(n)]
zs = [t / (8.0 * math.pi) for t in ts]
rs = [0.5 + z for z in zs]
xs = [r * math.cos(t) for r, t in zip(rs, ts)]
ys = [r * math.sin(t) for r, t in zip(rs, ts)]

fig = plt.figure(figsize=(6.4, 4.8))
ax = fig.add_subplot(projection='3d')
ax.plot(xs, ys, zs, color='tab:blue', linewidth=2, label='helix')
ax.plot([-x for x in xs], ys, zs, color='tab:orange', linewidth=1, linestyle='--', label='mirror')
ax.set_xlabel('x')
ax.set_ylabel('y')
ax.set_zlabel('z')
ax.set_title('3D lines')
ax.legend()

plt.savefig('reference_images/lines3d.png', dpi=100)
plt.savefig('reference_images/lines3d.svg')
plt.savefig('reference_images/lines3d.pdf')
print('Saved reference_images/lines3d.png')
