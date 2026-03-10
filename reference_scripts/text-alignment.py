"""text-alignment.py — Reference for examples/text-alignment.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, ax = plt.subplots(figsize=(7, 5))

x = [1, 2, 3, 4, 5, 6]
y = [3, 5, 2, 6, 4, 7]
ax.plot(x, y, 'o-', color='steelblue', linewidth=2)

ax.text(1, 3, 'left', ha='left', va='bottom', fontsize=12, color='tomato')
ax.text(3, 2, 'center', ha='center', va='top', fontsize=12, color='tomato')
ax.text(6, 7, 'right', ha='right', va='bottom', fontsize=12, color='tomato')

ax.set_title('Text Alignment Demo')
ax.set_xlim(0.5, 6.5)
ax.set_ylim(0, 8)

plt.savefig('reference_images/text-alignment.png', dpi=100)
plt.savefig('reference_images/text-alignment.svg')
print('Saved reference_images/text-alignment.svg')
plt.savefig('reference_images/text-alignment.pdf')
print('Saved reference_images/text-alignment.pdf')
plt.close()
