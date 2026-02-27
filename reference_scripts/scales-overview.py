"""scales-overview.py — Reference for examples/scales-overview.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, axs = plt.subplots(2, 2, figsize=(10, 8))

xs = [i * 0.2 for i in range(50)]

axs[0, 0].plot(xs, [math.sin(x) for x in xs], color='steelblue', linewidth=1.5)
axs[0, 0].grid(visible=True)

axs[0, 1].plot(xs, [math.exp(x * 0.1) for x in xs], color='tomato', linewidth=1.5)
axs[0, 1].set_yscale('log')
axs[0, 1].grid(visible=True)

axs[1, 0].plot(xs, [math.cos(x) for x in xs], color='seagreen', linewidth=1.5)
axs[1, 0].grid(visible=True)

axs[1, 1].plot(xs, [x ** 2 for x in xs], color='darkorchid', linewidth=1.5)
axs[1, 1].grid(visible=True)

plt.savefig('reference_images/scales-overview.png', dpi=100)
plt.savefig('reference_images/scales-overview.svg')
print('Saved reference_images/scales-overview.svg')
plt.savefig('reference_images/scales-overview.pdf')
print('Saved reference_images/scales-overview.pdf')
print('Saved reference_images/scales-overview.png')
