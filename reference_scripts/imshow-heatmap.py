"""imshow-heatmap.py — Reference for examples/imshow-heatmap.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 6))

n = 10
data = np.zeros((n, n))
for i in range(n):
    for j in range(n):
        data[i, j] = i * 0.1 + j * 0.1

plt.imshow(data, cmap='viridis', origin='lower')

plt.xlabel('Column')
plt.ylabel('Row')
plt.title('Heatmap — Gradient Pattern')

plt.savefig('reference_images/imshow-heatmap.png', dpi=100)
print('Saved reference_images/imshow-heatmap.png')
