"""figure-labels.py — Reference for examples/figure-labels.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig, axs = plt.subplots(2, 2, figsize=(10, 8))
x = np.linspace(0, 2*np.pi, 50)
axs[0,0].plot(x, np.sin(x), color='steelblue')
axs[0,1].plot(x, np.cos(x), color='orange')
axs[1,0].plot(x, np.sin(2*x), color='green')
axs[1,1].plot(x, np.cos(2*x), color='red')
fig.subplots_adjust(left=0.125, right=0.9, bottom=0.11, top=0.88, wspace=0.2, hspace=0.2)
fig.suptitle('Trigonometric Functions', fontsize=14)
fig.supxlabel('Angle (radians)', fontsize=12)
fig.supylabel('Amplitude', fontsize=12)
plt.savefig('reference_images/figure-labels.png')
plt.close()
