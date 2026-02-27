"""annotated-heatmap.py — Reference for examples/annotated-heatmap.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

data = np.array([[0.1, 0.2, 0.5, 0.3],
                 [0.4, 0.8, 0.1, 0.6],
                 [0.7, 0.3, 0.9, 0.2],
                 [0.5, 0.6, 0.4, 0.7]])

fig, ax = plt.subplots(figsize=(6, 5))
ax.imshow(data, cmap='Blues')
for i in range(4):
    for j in range(4):
        ax.text(j, i, f'{data[i,j]:.1f}', ha='center', va='center',
                fontsize=12, color='black')
ax.set_title('Annotated Heatmap')

plt.savefig('reference_images/annotated-heatmap.png', dpi=100)
plt.savefig('reference_images/annotated-heatmap.svg')
print('Saved reference_images/annotated-heatmap.svg')
plt.savefig('reference_images/annotated-heatmap.pdf')
print('Saved reference_images/annotated-heatmap.pdf')
plt.close()
