import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, ax = plt.subplots(figsize=(8, 6))

rows, cols = 20, 30
data = np.array([[np.sin(j / 5.0) * np.cos(i / 5.0)
                  for j in range(cols)]
                 for i in range(rows)])

mesh = ax.pcolormesh(data, cmap='viridis', shading='flat')
fig.colorbar(mesh, ax=ax)
ax.set_title('Pseudocolor Mesh: sin(x/5)*cos(y/5)')

plt.savefig('reference_images/pcolormesh.png')
plt.savefig('reference_images/pcolormesh.svg')
print('Saved reference_images/pcolormesh.svg')
plt.savefig('reference_images/pcolormesh.pdf')
print('Saved reference_images/pcolormesh.pdf')
