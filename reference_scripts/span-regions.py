"""span-regions.py — Reference for examples/span-regions.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(10, 6))

x = np.linspace(0.0, 20.0, 200)
y = np.sin(x)

plt.plot(x, y, color='steelblue', linewidth=2.0)

plt.axhspan(-0.5, 0.5, alpha=0.3, color='yellow')
plt.axvspan(5.0, 10.0, alpha=0.2, color='blue')

plt.xlabel('Time')
plt.ylabel('Amplitude')
plt.title('Sine Wave with Highlighted Regions')

plt.savefig('reference_images/span-regions.png', dpi=100)
print('Saved reference_images/span-regions.png')
