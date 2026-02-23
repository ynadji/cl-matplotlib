"""errorbar-features.py — Reference for examples/errorbar-features.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 5))

x = [1, 2, 3, 4, 5]
y1 = [2.0, 3.5, 2.8, 4.2, 3.9]
y2 = [v + 2.5 for v in y1]

plt.errorbar(x, y1, yerr=0.4, color='blue', capsize=5, linewidth=1.5)

plt.errorbar(x, y2, yerr=0.5, xerr=0.2, color='red', capsize=5, linewidth=1.5)

plt.grid(visible=True)
plt.xlabel('x')
plt.ylabel('y')
plt.title('Error Bar Types')

plt.savefig('reference_images/errorbar-features.png', dpi=100)
print('Saved reference_images/errorbar-features.png')
