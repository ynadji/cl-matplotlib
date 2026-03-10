"""fill-between-alpha.py — Reference for examples/fill-between-alpha.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 5))

x = np.linspace(0, 4 * np.pi, 100)
y1 = np.sin(x)
y2 = np.sin(x) * 0.5
y3 = np.sin(x) * 1.5

plt.plot(x, y1, 'b-', linewidth=1.5, label='sin(x)')
plt.plot(x, y3, 'b-', linewidth=0.8, label='1.5 sin(x)')
plt.plot(x, y2, 'b-', linewidth=0.8, label='0.5 sin(x)')
plt.fill_between(x, y2, y3, alpha=0.3, color='blue', label='±50% band')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Fill Between with Transparency')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/fill-between-alpha.png', dpi=100)
plt.savefig('reference_images/fill-between-alpha.svg')
print('Saved reference_images/fill-between-alpha.svg')
plt.savefig('reference_images/fill-between-alpha.pdf')
print('Saved reference_images/fill-between-alpha.pdf')
print('Saved reference_images/fill-between-alpha.png')
