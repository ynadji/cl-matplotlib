"""fill-between.py — Reference for examples/fill-between.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(10, 6))

# Fill between sin(x) and cos(x) from 0 to 2*pi
xs = np.arange(0.0, 2.0 * np.pi + 0.01, 0.1)
y_sin = np.sin(xs)
y_cos = np.cos(xs)

# Plot the curves
plt.plot(xs, y_sin, color='steelblue', linewidth=2.0, label='sin(x)')
plt.plot(xs, y_cos, color='tomato', linewidth=2.0, label='cos(x)')
# Fill between with alpha
plt.fill_between(xs, y_sin, y_cos, color='mediumpurple', alpha=0.3,
                 label='Fill region')

plt.xlabel('x (radians)')
plt.ylabel('y')
plt.title('Fill Between sin(x) and cos(x)')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/fill-between.png', dpi=100)
plt.savefig('reference_images/fill-between.svg')
print('Saved reference_images/fill-between.svg')
plt.savefig('reference_images/fill-between.pdf')
print('Saved reference_images/fill-between.pdf')
print('Saved reference_images/fill-between.png')
