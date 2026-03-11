"""categorical-scatter.py — Reference for examples/categorical-scatter.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

np.random.seed(42)
categories = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon']
fig, ax = plt.subplots(figsize=(8, 5))
for i, cat in enumerate(categories):
    y = np.random.normal(i, 0.3, 20)
    x = [cat] * 20
    ax.scatter(x, y, alpha=0.6, s=30)
ax.set_xlabel('Category')
ax.set_ylabel('Value')
ax.set_title('Categorical Scatter Plot')

plt.savefig('reference_images/categorical-scatter.png', dpi=100)
plt.savefig('reference_images/categorical-scatter.svg')
print('Saved reference_images/categorical-scatter.svg')
plt.savefig('reference_images/categorical-scatter.pdf')
print('Saved reference_images/categorical-scatter.pdf')
print('Saved reference_images/categorical-scatter.png')
plt.close('all')
