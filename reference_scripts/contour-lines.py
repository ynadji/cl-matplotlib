"""contour-lines.py — Reference for examples/contour-lines.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

# z = exp(-(x^2 + y^2)) — Gaussian surface
n = 50
xs = np.linspace(-3.0, 3.0, n)
ys = np.linspace(-3.0, 3.0, n)
X, Y = np.meshgrid(xs, ys)
Z = np.exp(-(X**2 + Y**2))

plt.contour(X, Y, Z, levels=8, cmap='viridis')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Contour Lines — Gaussian')
plt.grid(visible=True)

plt.savefig('reference_images/contour-lines.png', dpi=100)
plt.savefig('reference_images/contour-lines.svg')
print('Saved reference_images/contour-lines.svg')
plt.savefig('reference_images/contour-lines.pdf')
print('Saved reference_images/contour-lines.pdf')
print('Saved reference_images/contour-lines.png')
