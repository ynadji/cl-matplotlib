"""log-scale.py — Reference for examples/log-scale.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

# y = exp(x) for x = 0 to 5
xs = np.arange(0.0, 5.1, 0.1)
ys = np.exp(xs)

plt.plot(xs, ys, color='steelblue', linewidth=2.0, label='y = exp(x)')
plt.yscale('log')

plt.xlabel('x')
plt.ylabel('exp(x)')
plt.title('Logarithmic Scale Demo')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/log-scale.png', dpi=100)
plt.savefig('reference_images/log-scale.svg')
print('Saved reference_images/log-scale.svg')
plt.savefig('reference_images/log-scale.pdf')
print('Saved reference_images/log-scale.pdf')
print('Saved reference_images/log-scale.png')
