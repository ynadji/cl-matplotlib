"""text-watermark.py — Reference for examples/text-watermark.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig, ax = plt.subplots(figsize=(7, 5))
x = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
y = [i**2 for i in x]
ax.plot(x, y, color='steelblue', linewidth=2)
ax.set_title('Plot with Watermark')
ax.text(5, 50, 'DRAFT', fontsize=36, color='gray', alpha=0.4,
        ha='center', va='center', rotation=30.0)

plt.savefig('reference_images/text-watermark.png', dpi=100)
plt.close()
