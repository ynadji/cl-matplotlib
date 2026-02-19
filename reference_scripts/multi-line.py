"""multi-line.py — Reference for examples/multi-line.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(10, 6))

xs = np.arange(0.0, 101.0) * 0.1

plt.plot(xs, np.sin(xs),
         color='steelblue', linewidth=2.0,
         linestyle='-', label='sin(x)')
plt.plot(xs, np.cos(xs),
         color='tomato', linewidth=2.0,
         linestyle='--', label='cos(x)')
plt.plot(xs, 0.5 * np.sin(2.0 * xs),
         color='forestgreen', linewidth=2.5,
         linestyle=':', label='0.5*sin(2x)')
plt.plot(xs, 0.5 * np.cos(2.0 * xs),
         color='darkorange', linewidth=2.0,
         linestyle='-.', label='0.5*cos(2x)')

plt.legend(loc='upper right', fontsize=10)

plt.xlabel('x')
plt.ylabel('y')
plt.title('Multiple Lines — Different Styles')
plt.grid(visible=True)

plt.savefig('reference_images/multi-line.png', dpi=100)
print('Saved reference_images/multi-line.png')
