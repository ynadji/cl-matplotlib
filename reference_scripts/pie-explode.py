"""pie-explode.py — Reference for examples/pie-explode.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

sizes = [35, 25, 20, 20]
labels = ['Category A', 'Category B', 'Category C', 'Category D']
explode = (0, 0.1, 0, 0)
colors = ['#4C72B0', '#DD8452', '#55A868', '#C44E52']
fig, ax = plt.subplots(figsize=(8, 6))
ax.pie(sizes, explode=explode, labels=labels, colors=colors, autopct='%1.1f%%', startangle=90)
ax.set_title('Exploded Pie Chart')

plt.savefig('reference_images/pie-explode.png', dpi=100)
plt.savefig('reference_images/pie-explode.svg')
print('Saved reference_images/pie-explode.svg')
plt.savefig('reference_images/pie-explode.pdf')
print('Saved reference_images/pie-explode.pdf')
print('Saved reference_images/pie-explode.png')
plt.close('all')
