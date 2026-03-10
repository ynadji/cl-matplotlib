"""multi-line-styles.py — Reference for examples/multi-line-styles.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 5))

xs = [i * 0.1 for i in range(101)]

plt.plot(xs, [math.sin(x) for x in xs],
         '-', color='blue', linewidth=2, label='solid')
plt.plot(xs, [math.sin(x + 0.5) for x in xs],
         '--', color='red', linewidth=2, label='dashed')
plt.plot(xs, [math.sin(x + 1.0) for x in xs],
         ':', color='green', linewidth=2, label='dotted')
plt.plot(xs, [math.sin(x + 1.5) for x in xs],
         '-.', color='orange', linewidth=2, label='dash-dot')

plt.legend()
plt.grid(visible=True)
plt.xlabel('x')
plt.ylabel('y')
plt.title('Line Styles')

plt.savefig('reference_images/multi-line-styles.png', dpi=100)
plt.savefig('reference_images/multi-line-styles.svg')
print('Saved reference_images/multi-line-styles.svg')
plt.savefig('reference_images/multi-line-styles.pdf')
print('Saved reference_images/multi-line-styles.pdf')
print('Saved reference_images/multi-line-styles.png')
