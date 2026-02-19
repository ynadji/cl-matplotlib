"""filled-contour.py — Reference for examples/filled-contour.lisp"""
import math
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 6))

n = 50
# xs[i] = 6.0 * i/(n-1) - 3.0  →  range [-3, 3]
xs = [6.0 * i / (n - 1) - 3.0 for i in range(n)]
ys = [6.0 * i / (n - 1) - 3.0 for i in range(n)]

# z[j][i] = exp(-(xs[i]^2 + ys[j]^2))
z = np.zeros((n, n))
for j in range(n):
    for i in range(n):
        z[j, i] = math.exp(-(xs[i] ** 2 + ys[j] ** 2))

plt.contourf(xs, ys, z, levels=12, cmap='viridis')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Gaussian: exp(-(x^2+y^2))')

plt.savefig('reference_images/filled-contour.png', dpi=100)
print('Saved reference_images/filled-contour.png')
