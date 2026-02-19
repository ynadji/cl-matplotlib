"""stem-plot.py — Reference for examples/stem-plot.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(10, 5))

# Stem plot of y = sin(x) for x = 0, 0.5, 1.0, ..., 4*pi
xs = np.arange(0.0, 4.0 * np.pi + 0.01, 0.5)
ys = np.sin(xs)

markers, stemlines, baseline = plt.stem(xs, ys, label='sin(x)')
plt.setp(stemlines, color='steelblue')
plt.setp(markers, color='steelblue')
plt.setp(baseline, color='gray')

plt.xlabel('x (radians)')
plt.ylabel('sin(x)')
plt.title('Stem Plot — sin(x)')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/stem-plot.png', dpi=100)
print('Saved reference_images/stem-plot.png')
