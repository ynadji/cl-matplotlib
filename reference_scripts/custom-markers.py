"""custom-markers.py — Reference for examples/custom-markers.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

xs = np.arange(0.0, 8.0, 1.0)

plt.plot(xs, 1.0 * xs,
         color='steelblue', linewidth=1.5,
         marker='o', label='circle (o)')
plt.plot(xs, 1.0 * xs + 2.0,
         color='tomato', linewidth=1.5,
         linestyle='--', marker='s', label='square (s)')
plt.plot(xs, 1.0 * xs + 4.0,
         color='seagreen', linewidth=1.5,
         linestyle='-.', marker='^', label='triangle-up (^)')
plt.plot(xs, 1.0 * xs + 6.0,
         color='darkorchid', linewidth=1.5,
         linestyle=':', marker='v', label='triangle-down (v)')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Custom Markers and Line Styles')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/custom-markers.png', dpi=100)
plt.savefig('reference_images/custom-markers.svg')
print('Saved reference_images/custom-markers.svg')
plt.savefig('reference_images/custom-markers.pdf')
print('Saved reference_images/custom-markers.pdf')
print('Saved reference_images/custom-markers.png')
