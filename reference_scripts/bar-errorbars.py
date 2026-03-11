"""bar-errorbars.py — Reference for examples/bar-errorbars.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

categories = ['A', 'B', 'C', 'D', 'E']
values = [3.5, 5.2, 4.1, 6.8, 2.9]
errors = [0.3, 0.5, 0.4, 0.6, 0.2]
fig, ax = plt.subplots(figsize=(8, 5))
ax.bar(categories, values, yerr=errors, capsize=5, color='steelblue', edgecolor='black', linewidth=0.5)
ax.set_xlabel('Category')
ax.set_ylabel('Value')
ax.set_title('Bar Chart with Error Bars')

plt.savefig('reference_images/bar-errorbars.png', dpi=100)
plt.savefig('reference_images/bar-errorbars.svg')
print('Saved reference_images/bar-errorbars.svg')
plt.savefig('reference_images/bar-errorbars.pdf')
print('Saved reference_images/bar-errorbars.pdf')
print('Saved reference_images/bar-errorbars.png')
plt.close('all')
