"""hexbin-basic.py — Reference for examples/hexbin-basic.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import math

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

n = 1000
x = [math.sin(i * 0.1) * 3 + math.cos(i * 0.037) * 2 for i in range(n)]
y = [math.cos(i * 0.1) * 3 + math.sin(i * 0.053) * 2 for i in range(n)]

fig, ax = plt.subplots(figsize=(8, 5))
hb = ax.hexbin(x, y, gridsize=20, cmap='inferno', mincnt=1)
plt.colorbar(hb, ax=ax, label='Count')
ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_title('Hexbin Plot')

plt.savefig('reference_images/hexbin-basic.png', dpi=100)
plt.savefig('reference_images/hexbin-basic.svg')
print('Saved reference_images/hexbin-basic.svg')
plt.savefig('reference_images/hexbin-basic.pdf')
print('Saved reference_images/hexbin-basic.pdf')
print('Saved reference_images/hexbin-basic.png')
plt.close('all')
