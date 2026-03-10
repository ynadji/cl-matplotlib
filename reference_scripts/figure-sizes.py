"""figure-sizes.py — Reference for examples/figure-sizes.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(16, 4))

n = 200
xs = np.arange(n) * 0.05
# composite signal: sin(2x) + 0.5*sin(5x) + 0.3*sin(13x)
ys = np.sin(2.0 * xs) + 0.5 * np.sin(5.0 * xs) + 0.3 * np.sin(13.0 * xs)

plt.plot(xs, ys, color='steelblue', linewidth=1.0, label='composite signal')

plt.xlabel('Time (s)')
plt.ylabel('Amplitude')
plt.title('Wide Aspect Ratio — Panoramic Time Series')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/figure-sizes.png', dpi=100)
plt.savefig('reference_images/figure-sizes.svg')
print('Saved reference_images/figure-sizes.svg')
plt.savefig('reference_images/figure-sizes.pdf')
print('Saved reference_images/figure-sizes.pdf')
print('Saved reference_images/figure-sizes.png')
