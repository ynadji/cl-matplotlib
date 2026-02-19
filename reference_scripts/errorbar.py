"""errorbar.py — Reference for examples/errorbar.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 6))

# y = x^2 with y error bars of ±x and x error bars of ±0.2
xs = np.arange(0.5, 5.5, 0.5)
ys = xs ** 2
yerrs = xs.copy()  # ±x
xerrs = np.full_like(xs, 0.2)  # ±0.2

plt.errorbar(xs, ys, yerr=yerrs, xerr=xerrs,
             color='steelblue', ecolor='tomato',
             capsize=4.0, linewidth=1.5,
             marker='o', label='y = x² ± errors')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Error Bar Plot')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/errorbar.png', dpi=100)
print('Saved reference_images/errorbar.png')
