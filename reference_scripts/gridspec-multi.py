"""gridspec-multi.py — Reference for examples/gridspec-multi.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, axs = plt.subplots(1, 3, figsize=(12, 4))

x = [i * 1.0 for i in range(11)]

# Left panel: quadratic
axs[0].plot(x, [v**2 for v in x], color='steelblue', linewidth=2.0)
axs[0].grid(visible=True)

# Middle panel: square root
axs[1].plot(x, [v**0.5 for v in x], color='tomato', linewidth=2.0)
axs[1].grid(visible=True)

# Right panel: bar chart
axs[2].bar([1, 2, 3, 4, 5], [10, 20, 15, 25, 18], color='seagreen', width=0.6)
axs[2].grid(visible=True)

plt.savefig('reference_images/gridspec-multi.png', dpi=100)
plt.savefig('reference_images/gridspec-multi.svg')
print('Saved reference_images/gridspec-multi.svg')
plt.savefig('reference_images/gridspec-multi.pdf')
print('Saved reference_images/gridspec-multi.pdf')
print('Saved reference_images/gridspec-multi.png')
