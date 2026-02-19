"""annotations.py — Reference for examples/annotations.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(10, 6))

xs = np.linspace(0, 2 * np.pi, 101)
ys = np.sin(xs)

peak_x = np.pi / 2.0
peak_y = 1.0

plt.plot(xs, ys, color='steelblue', linewidth=2.0, label='sin(x)')
plt.annotate('Maximum',
             xy=(peak_x, peak_y),
             xytext=(peak_x + 1.0, peak_y - 0.3),
             fontsize=12,
             arrowprops=dict(arrowstyle='->', color='red'),
             color='red')

plt.xlabel('x (radians)')
plt.ylabel('sin(x)')
plt.title('Annotated Plot — sin(x) with Peak')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/annotations.png', dpi=100)
print('Saved reference_images/annotations.png')
