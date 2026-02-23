"""two-scales.py — Reference for examples/two-scales.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig, ax1 = plt.subplots(figsize=(8, 5))

t = np.linspace(0.0, 10.0, 100)
s1 = np.sin(t)
s2 = np.exp(t / 3.0)

ax1.plot(t, s1, color='blue', linewidth=2.0)
ax1.set_xlabel('Time (s)')
ax1.set_ylabel('sin(t)')

ax2 = ax1.twinx()
ax2.plot(t, s2, color='red', linewidth=2.0)
ax2.set_ylabel('exp(t/3)')

plt.title('Two Scales: sin(t) and exp(t/3)')
plt.savefig('reference_images/two-scales.png', dpi=100)
print('Saved reference_images/two-scales.png')
