"""symlog-demo.py — Reference for examples/symlog-demo.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 5))

xs = [(-10.0 + i * 0.1) for i in range(200)]
ys = [math.sinh(x) for x in xs]

plt.plot(xs, ys, color='blue', linestyle='-', linewidth=1.5)
plt.grid(visible=True)
plt.xlabel('x')
plt.ylabel('sinh(x)')
plt.title('sinh(x) — Hyperbolic Sine')

plt.savefig('reference_images/symlog-demo.png', dpi=100)
print('Saved reference_images/symlog-demo.png')
