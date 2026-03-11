"""bar-hatch.py — Reference for examples/bar-hatch.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

categories = ['A', 'B', 'C', 'D']
values = [4.2, 6.1, 3.8, 5.5]
hatches = ['/', '\\', 'x', 'o']
colors = ['#4C72B0', '#DD8452', '#55A868', '#C44E52']
fig, ax = plt.subplots(figsize=(8, 5))
bars = ax.bar(categories, values, color=colors, edgecolor='black', linewidth=0.8)
for bar, hatch in zip(bars, hatches):
    bar.set_hatch(hatch)
ax.set_xlabel('Category')
ax.set_ylabel('Value')
ax.set_title('Bar Chart with Hatch Patterns')

plt.savefig('reference_images/bar-hatch.png', dpi=100)
plt.savefig('reference_images/bar-hatch.svg')
print('Saved reference_images/bar-hatch.svg')
plt.savefig('reference_images/bar-hatch.pdf')
print('Saved reference_images/bar-hatch.pdf')
print('Saved reference_images/bar-hatch.png')
plt.close('all')
