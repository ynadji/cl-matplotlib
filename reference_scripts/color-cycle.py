"""color-cycle.py — Reference for examples/color-cycle.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

# 0 to ~2*pi (100 points * 0.063)
xs = np.arange(100) * 0.063
colors = ['steelblue', 'tomato', 'seagreen', 'darkorchid',
          'goldenrod', 'deeppink', 'teal', 'coral']

for k in range(8):
    phi = k * 0.4
    ys = np.sin(xs + phi)
    plt.plot(xs, ys, color=colors[k], linewidth=1.5,
             label=f'phi = {phi:.1f}')

plt.xlabel('x')
plt.ylabel('sin(x + phi)')
plt.title('Color Cycle — Phase-Shifted Sine Waves')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/color-cycle.png', dpi=100)
plt.savefig('reference_images/color-cycle.svg')
print('Saved reference_images/color-cycle.svg')
plt.savefig('reference_images/color-cycle.pdf')
print('Saved reference_images/color-cycle.pdf')
print('Saved reference_images/color-cycle.png')
