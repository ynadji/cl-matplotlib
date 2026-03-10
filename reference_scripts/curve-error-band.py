"""curve-error-band.py — Reference for examples/curve-error-band.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 5))

x = np.linspace(0, 10, 50)
y = np.sin(x) + 0.5 * np.sin(2 * x)
y_err = 0.3 + 0.1 * np.abs(np.cos(x))

plt.plot(x, y, 'b-', linewidth=2, label='Signal')
plt.fill_between(x, y - y_err, y + y_err, alpha=0.3, color='blue',
                 label='Uncertainty')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Curve with Error Band')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/curve-error-band.png', dpi=100)
plt.savefig('reference_images/curve-error-band.svg')
print('Saved reference_images/curve-error-band.svg')
plt.savefig('reference_images/curve-error-band.pdf')
print('Saved reference_images/curve-error-band.pdf')
print('Saved reference_images/curve-error-band.png')
