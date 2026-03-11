"""legend-outside.py — Reference for examples/legend-outside.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

x = np.linspace(0, 2*np.pi, 100)
fig, ax = plt.subplots(figsize=(8, 5))
for i, (label, color) in enumerate(zip(['Alpha', 'Beta', 'Gamma', 'Delta'],
                                         ['#4C72B0', '#DD8452', '#55A868', '#C44E52'])):
    ax.plot(x, np.sin(x + i*np.pi/4), color=color, label=label, linewidth=1.5)
ax.set_xlabel('x')
ax.set_ylabel('y')
ax.set_title('Legend Outside Plot Area')
ax.legend(bbox_to_anchor=(1.05, 1), loc='upper left', borderaxespad=0.)

plt.savefig('reference_images/legend-outside.png', dpi=100)
plt.savefig('reference_images/legend-outside.svg')
print('Saved reference_images/legend-outside.svg')
plt.savefig('reference_images/legend-outside.pdf')
print('Saved reference_images/legend-outside.pdf')
print('Saved reference_images/legend-outside.png')
plt.close('all')
