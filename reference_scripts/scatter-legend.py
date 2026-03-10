"""scatter-legend.py — Reference for examples/scatter-legend.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

group1_x = [1.0, 1.5, 2.0, 2.5, 3.0]
group1_y = [2.0, 2.5, 1.8, 2.8, 2.2]
group2_x = [4.0, 4.5, 5.0, 5.5, 6.0]
group2_y = [4.0, 3.5, 4.5, 3.8, 4.2]
group3_x = [7.0, 7.5, 8.0, 8.5, 9.0]
group3_y = [6.0, 6.5, 5.8, 6.8, 6.2]

plt.scatter(group1_x, group1_y, s=80, color='blue', label='Group A', alpha=0.7)
plt.scatter(group2_x, group2_y, s=80, color='red', label='Group B', alpha=0.7)
plt.scatter(group3_x, group3_y, s=80, color='green', label='Group C', alpha=0.7)

plt.legend(loc='upper left')
plt.xlabel('X')
plt.ylabel('Y')
plt.title('Scatter Plot with Legend')
plt.grid(visible=True)

plt.savefig('reference_images/scatter-legend.png', dpi=100)
plt.savefig('reference_images/scatter-legend.svg')
print('Saved reference_images/scatter-legend.svg')
plt.savefig('reference_images/scatter-legend.pdf')
print('Saved reference_images/scatter-legend.pdf')
print('Saved reference_images/scatter-legend.png')
