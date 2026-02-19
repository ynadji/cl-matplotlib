"""colorbar-custom.py — Reference for examples/colorbar-custom.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 6))

# z = sin(x) * cos(y) on [-3, 3]
n = 50
xs = np.linspace(-3.0, 3.0, n)
ys = np.linspace(-3.0, 3.0, n)
X, Y = np.meshgrid(xs, ys)
Z = np.sin(X) * np.cos(Y)

plt.contourf(X, Y, Z, levels=16, cmap='plasma')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Custom Colormap — Plasma')

plt.savefig('reference_images/colorbar-custom.png', dpi=100)
print('Saved reference_images/colorbar-custom.png')
