"""shared-axes.py — Reference for examples/shared-axes.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig, axs = plt.subplots(2, 1, sharex=True, figsize=(8, 6))

# x from 0 to ~4*pi (100 points * 0.126)
xs = np.arange(0, 100) * 0.126

axs[0].plot(xs, np.sin(xs), color='steelblue', linewidth=1.5)
axs[0].set_ylabel('sin(x)')
axs[0].grid(visible=True)

axs[1].plot(xs, np.cos(xs), color='tomato', linewidth=1.5)
axs[1].set_xlabel('x (radians)')
axs[1].set_ylabel('cos(x)')
axs[1].grid(visible=True)

plt.savefig('reference_images/shared-axes.png', dpi=100)
print('Saved reference_images/shared-axes.png')
