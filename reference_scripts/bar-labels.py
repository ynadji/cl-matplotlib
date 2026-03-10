"""bar-labels.py — Reference for examples/bar-labels.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, ax = plt.subplots(figsize=(7, 5))
values = [23, 45, 12, 67, 34]
x = list(range(5))
categories = ['A', 'B', 'C', 'D', 'E']
ax.bar(x, values, color='steelblue')
for xi, val in zip(x, values):
    ax.text(xi, val + 1, str(val), ha='center', va='bottom', fontsize=11)
ax.set_xticks(x, categories)
ax.set_ylim(0, 80)
ax.set_title('Bar Chart with Labels')

plt.savefig('reference_images/bar-labels.png', dpi=100)
plt.savefig('reference_images/bar-labels.svg')
print('Saved reference_images/bar-labels.svg')
plt.savefig('reference_images/bar-labels.pdf')
print('Saved reference_images/bar-labels.pdf')
plt.close()
