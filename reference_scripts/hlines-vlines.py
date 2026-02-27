"""hlines-vlines.py — Reference for examples/hlines-vlines.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 5))
x = list(range(11))
y = [0.5, 1.8, 2.5, 1.2, 3.0, 2.2, 3.5, 1.5, 2.8, 3.8, 2.0]
plt.plot(x, y, color='steelblue', linewidth=1.5, label='Data')
plt.hlines([1, 2, 3], 0, 10, colors=['red', 'green', 'blue'],
           linewidth=1.5, linestyles='solid')
plt.vlines([3, 6, 9], 0, 4, colors=['orange', 'purple', 'brown'],
           linewidth=1.5, linestyles='solid')
plt.xlim(0, 10)
plt.ylim(0, 4)
plt.title('Horizontal and Vertical Lines')
plt.xlabel('X')
plt.ylabel('Y')
plt.savefig('reference_images/hlines-vlines.png')
plt.savefig('reference_images/hlines-vlines.svg')
print('Saved reference_images/hlines-vlines.svg')
plt.savefig('reference_images/hlines-vlines.pdf')
print('Saved reference_images/hlines-vlines.pdf')
plt.close()
