"""bar-colors.py — Reference for examples/bar-colors.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 5))

x = [1, 2, 3, 4, 5, 6]
heights = [45.0, 30.0, 55.0, 20.0, 40.0, 35.0]
colors = ['steelblue', 'tomato', 'seagreen', 'goldenrod', 'mediumpurple', 'coral']

plt.bar(x, heights, color=colors, edgecolor='black', linewidth=0.8, width=0.6)

plt.xlabel('Category')
plt.ylabel('Value')
plt.title('Bar Chart with Individual Colors')
plt.grid(visible=True, axis='y')

plt.savefig('reference_images/bar-colors.png', dpi=100)
plt.savefig('reference_images/bar-colors.svg')
print('Saved reference_images/bar-colors.svg')
plt.savefig('reference_images/bar-colors.pdf')
print('Saved reference_images/bar-colors.pdf')
print('Saved reference_images/bar-colors.png')
