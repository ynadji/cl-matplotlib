"""text-positions.py — Reference for examples/text-positions.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig, ax = plt.subplots(figsize=(7, 5))
x = [1, 2, 3, 4, 5]
y = [2, 4, 3, 5, 1]
ax.plot(x, y, 'o-', color='steelblue', linewidth=2)
for xi, yi in zip(x, y):
    ax.text(xi, yi + 0.15, f'({xi},{yi})', ha='center', va='bottom', fontsize=9)
ax.set_title('Data Point Labels')
ax.set_xlim(0.5, 5.5)
ax.set_ylim(0, 6)

plt.savefig('reference_images/text-positions.png', dpi=100)
plt.close()
