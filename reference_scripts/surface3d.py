"""surface3d.py — Reference for examples/surface3d.lisp"""
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

n = 40
v = np.array([10.0 * (k / (n - 1)) - 5.0 for k in range(n)])
X, Y = np.meshgrid(v, v)
R = np.sqrt(X ** 2 + Y ** 2)
Z = np.where(R == 0, 1.0, np.sin(R) / np.where(R == 0, 1.0, R))

fig = plt.figure(figsize=(6.4, 4.8))
ax = fig.add_subplot(projection='3d')
ax.plot_surface(X, Y, Z, cmap='viridis')
ax.set_xlabel('x')
ax.set_ylabel('y')
ax.set_zlabel('sinc')
ax.set_title('3D surface')

plt.savefig('reference_images/surface3d.png', dpi=100)
plt.savefig('reference_images/surface3d.svg')
plt.savefig('reference_images/surface3d.pdf')
print('Saved reference_images/surface3d.png')
