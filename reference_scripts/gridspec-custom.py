"""gridspec-custom.py — Reference for examples/gridspec-custom.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig, axs = plt.subplots(2, 2, figsize=(10, 8))

xs = np.arange(0, 50) * 0.2

axs[0, 0].plot(xs, 0.1 * xs**2, color='steelblue', linewidth=2.0)
axs[0, 0].grid(visible=True)

axs[0, 1].plot(xs, np.exp(-0.3 * xs), color='tomato', linewidth=2.0)
axs[0, 1].grid(visible=True)

axs[1, 0].plot(xs, np.sin(xs), color='seagreen', linewidth=2.0)
axs[1, 0].grid(visible=True)

axs[1, 1].plot(xs, np.exp(-0.2 * xs) * np.sin(2.0 * xs),
               color='darkorchid', linewidth=2.0)
axs[1, 1].grid(visible=True)

plt.savefig('reference_images/gridspec-custom.png', dpi=100)
print('Saved reference_images/gridspec-custom.png')
