"""pcolormesh-basic.py — Reference for examples/pcolormesh-basic.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

rows, cols = 20, 30
data = np.zeros((rows, cols))
for i in range(rows):
    for j in range(cols):
        x = (j - 15.0) / 5.0
        y = (i - 10.0) / 5.0
        data[i, j] = np.cos(np.sqrt(x * x + y * y + 0.01)) * np.exp(-0.1 * (x * x + y * y))

plt.pcolormesh(data, cmap='plasma')
plt.colorbar()
plt.title('Radial Wave: cos(r)*exp(-r^2/10)')

plt.savefig('reference_images/pcolormesh-basic.png', dpi=100)
plt.savefig('reference_images/pcolormesh-basic.svg')
print('Saved reference_images/pcolormesh-basic.svg')
plt.savefig('reference_images/pcolormesh-basic.pdf')
print('Saved reference_images/pcolormesh-basic.pdf')
print('Saved reference_images/pcolormesh-basic.png')
