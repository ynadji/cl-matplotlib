"""fill-between-where.py — Reference for examples/fill-between-where.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

x = np.linspace(0, 4*np.pi, 200)
y1 = np.sin(x)
y2 = 0.5 * np.sin(2*x)
fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(x, y1, 'b-', label='sin(x)', linewidth=1.5)
ax.plot(x, y2, 'r-', label='0.5·sin(2x)', linewidth=1.5)
ax.fill_between(x, y1, y2, where=(y1 > y2), alpha=0.4, color='green', label='y1 > y2')
ax.fill_between(x, y1, y2, where=(y1 <= y2), alpha=0.4, color='red', label='y1 ≤ y2')
ax.set_xlabel('x')
ax.set_ylabel('y')
ax.set_title('fill_between with where condition')
ax.legend()

plt.savefig('reference_images/fill-between-where.png', dpi=100)
plt.savefig('reference_images/fill-between-where.svg')
print('Saved reference_images/fill-between-where.svg')
plt.savefig('reference_images/fill-between-where.pdf')
print('Saved reference_images/fill-between-where.pdf')
print('Saved reference_images/fill-between-where.png')
plt.close('all')
