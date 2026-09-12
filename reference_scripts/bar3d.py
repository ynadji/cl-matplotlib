"""bar3d.py — Reference for examples/bar3d.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

xs, ys, dzs = [], [], []
for i in range(4):
    for j in range(4):
        xs.append(i); ys.append(j); dzs.append(1 + i + j + 0.5 * ((i * j) % 3))

fig = plt.figure(figsize=(6.4, 4.8))
ax = fig.add_subplot(projection='3d')
ax.bar3d(xs, ys, 0, 0.6, 0.6, dzs, color='tab:blue')
ax.set_xlabel('x')
ax.set_ylabel('y')
ax.set_zlabel('height')
ax.set_title('3D bars')

plt.savefig('reference_images/bar3d.png', dpi=100)
plt.savefig('reference_images/bar3d.svg')
plt.savefig('reference_images/bar3d.pdf')
print('Saved reference_images/bar3d.png')
