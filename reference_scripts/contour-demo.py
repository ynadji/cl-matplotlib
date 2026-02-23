"""contour-demo.py — Reference for examples/contour-demo.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 6))

n = 50
xs = [6.0 * i / (n - 1) - 3.0 for i in range(n)]
ys = [6.0 * i / (n - 1) - 3.0 for i in range(n)]

z = [[0.0] * n for _ in range(n)]
for j in range(n):
    for i in range(n):
        z[j][i] = math.sin(xs[i]) * math.cos(ys[j])

levels = [-1.0, -0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75, 1.0]
plt.contourf(xs, ys, z, levels=levels, cmap='plasma')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Contour Demo — sin(x)cos(y)')

plt.savefig('reference_images/contour-demo.png', dpi=100)
print('Saved reference_images/contour-demo.png')
