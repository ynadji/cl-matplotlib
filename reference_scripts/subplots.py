"""subplots.py — Reference for examples/subplots.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, axs = plt.subplots(2, 2, figsize=(10, 8))

# xs = 0, 0.2, 0.4, ..., 9.8  (50 points: i from 0 to 49)
xs = [i * 0.2 for i in range(50)]

# Top-left: sin
ys_sin = [math.sin(x) for x in xs]
axs[0, 0].plot(xs, ys_sin, color='steelblue', linewidth=1.5)
axs[0, 0].grid(visible=True)

# Top-right: cos
ys_cos = [math.cos(x) for x in xs]
axs[0, 1].plot(xs, ys_cos, color='tomato', linewidth=1.5)
axs[0, 1].grid(visible=True)

# Bottom-left: sin * cos
ys_sincos = [math.sin(x) * math.cos(x) for x in xs]
axs[1, 0].plot(xs, ys_sincos, color='seagreen', linewidth=1.5)
axs[1, 0].grid(visible=True)

# Bottom-right: sin^2
ys_sin2 = [math.sin(x) ** 2 for x in xs]
axs[1, 1].plot(xs, ys_sin2, color='darkorchid', linewidth=1.5)
axs[1, 1].grid(visible=True)

plt.savefig('reference_images/subplots.png', dpi=100)
plt.savefig('reference_images/subplots.svg')
print('Saved reference_images/subplots.svg')
plt.savefig('reference_images/subplots.pdf')
print('Saved reference_images/subplots.pdf')
print('Saved reference_images/subplots.png')
