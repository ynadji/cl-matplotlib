"""reference-grid.py — Reference for examples/reference-grid.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(7, 5))

x = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
y = [3.2, 5.1, 2.8, 6.4, 4.9, 7.2, 3.5, 5.8, 4.1, 6.7]
plt.scatter(x, y, color='steelblue', s=60, zorder=3)

for yval, col in [(2.5, 'green'), (5.0, 'orange'), (7.5, 'red')]:
    plt.axhline(yval, color=col, linewidth=1.0, linestyle='--', alpha=0.7)

plt.xlim(0.5, 10.5)
plt.ylim(1.5, 8.5)
plt.title('Scatter with Reference Lines')
plt.xlabel('X')
plt.ylabel('Y')
plt.savefig('reference_images/reference-grid.png')
plt.close()
