"""donut-chart.py — Reference for examples/donut-chart.lisp"""
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
colors = ['#4C72B0', '#DD8452', '#55A868', '#C44E52']
fig, ax = plt.subplots(figsize=(8, 6))
ax.pie(sizes, labels=labels, colors=colors, autopct='%1.1f%%',
       wedgeprops=dict(width=0.5), startangle=90)
ax.set_title('Donut Chart')

plt.savefig('reference_images/donut-chart.png', dpi=100)
plt.savefig('reference_images/donut-chart.svg')
print('Saved reference_images/donut-chart.svg')
plt.savefig('reference_images/donut-chart.pdf')
print('Saved reference_images/donut-chart.pdf')
print('Saved reference_images/donut-chart.png')
plt.close('all')
