"""legend-styles.py — Reference for examples/legend-styles.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(10, 6))

xs = np.arange(0.0, 51.0, 1.0)

# y = 2x (linear)
plt.plot(xs, 2.0 * xs,
         color='steelblue', linewidth=2.0,
         linestyle='-', label='Linear: y = 2x')
# y = 0.04x^2 (quadratic)
plt.plot(xs, 0.04 * xs**2,
         color='tomato', linewidth=2.0,
         linestyle='--', label='Quadratic: y = 0.04x^2')
# y = 10*sqrt(x) (square root)
plt.plot(xs, 10.0 * np.sqrt(xs),
         color='forestgreen', linewidth=2.0,
         linestyle=':', label='Root: y = 10*sqrt(x)')

plt.legend(loc='upper left', fontsize=11, frameon=True,
           title='Function Comparison',
           facecolor='#f0f0f0', edgecolor='gray')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Legend Styles — Multiple Functions')
plt.grid(visible=True)

plt.savefig('reference_images/legend-styles.png', dpi=100)
plt.savefig('reference_images/legend-styles.svg')
print('Saved reference_images/legend-styles.svg')
plt.savefig('reference_images/legend-styles.pdf')
print('Saved reference_images/legend-styles.pdf')
print('Saved reference_images/legend-styles.png')
