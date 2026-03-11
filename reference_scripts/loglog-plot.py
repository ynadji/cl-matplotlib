"""loglog-plot.py — Reference for examples/loglog-plot.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

x = np.logspace(0, 3, 50)
y1 = x**2
y2 = x**1.5
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 6))
ax1.loglog(x, y1, 'b-', label='x²', linewidth=1.5)
ax1.loglog(x, y2, 'r--', label='x^1.5', linewidth=1.5)
ax1.set_xlabel('x')
ax1.set_ylabel('y')
ax1.set_title('Log-Log Plot')
ax1.legend()
ax1.grid(True, which='both', alpha=0.3)
ax2.semilogx(x, np.log10(y1), 'b-', label='log₁₀(x²)', linewidth=1.5)
ax2.semilogx(x, np.log10(y2), 'r--', label='log₁₀(x^1.5)', linewidth=1.5)
ax2.set_xlabel('x')
ax2.set_ylabel('log₁₀(y)')
ax2.set_title('Semi-Log X Plot')
ax2.legend()
ax2.grid(True, which='both', alpha=0.3)

plt.savefig('reference_images/loglog-plot.png', dpi=100)
plt.savefig('reference_images/loglog-plot.svg')
print('Saved reference_images/loglog-plot.svg')
plt.savefig('reference_images/loglog-plot.pdf')
print('Saved reference_images/loglog-plot.pdf')
print('Saved reference_images/loglog-plot.png')
plt.close('all')
