"""minor-ticks-demo.py — Reference for examples/minor-ticks-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

x = np.linspace(0, 10, 100)
y = np.sin(x)
fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(x, y, 'b-', linewidth=1.5)
ax.minorticks_on()
ax.grid(True, which='major', alpha=0.5)
ax.grid(True, which='minor', alpha=0.2, linestyle=':')
ax.set_xlabel('x')
ax.set_ylabel('sin(x)')
ax.set_title('Minor Ticks Demo')

plt.savefig('reference_images/minor-ticks-demo.png', dpi=100)
plt.savefig('reference_images/minor-ticks-demo.svg')
print('Saved reference_images/minor-ticks-demo.svg')
plt.savefig('reference_images/minor-ticks-demo.pdf')
print('Saved reference_images/minor-ticks-demo.pdf')
print('Saved reference_images/minor-ticks-demo.png')
plt.close('all')
