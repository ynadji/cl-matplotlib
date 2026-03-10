"""scatter-sizes.py — Reference for examples/scatter-sizes.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

xs = [1.0, 2.5, 3.7, 5.1, 6.4, 7.2, 8.9, 3.3, 4.8, 6.1,
      1.5, 2.0, 4.5, 5.8, 7.7, 8.3, 2.7, 6.8, 9.1, 0.8,
      3.1, 4.2, 5.5, 7.0, 8.6, 1.2, 2.9, 5.2, 6.7, 9.4]
ys = [2.1, 3.4, 1.8, 4.5, 2.9, 6.1, 3.8, 5.2, 1.5, 4.0,
      6.7, 2.3, 5.6, 3.1, 4.9, 7.3, 1.9, 5.8, 2.6, 7.8,
      3.7, 4.3, 6.4, 2.8, 5.1, 8.2, 3.5, 7.6, 1.4, 4.7]
sizes = [50, 100, 200, 80, 150, 30, 250, 120, 60, 180,
         90, 220, 45, 160, 75, 300, 110, 40, 190, 85,
         130, 70, 240, 55, 170, 95, 280, 65, 145, 210]
colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
          "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
          "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
          "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
          "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
          "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf"]

plt.scatter(xs, ys, s=sizes, c=colors, alpha=0.7)

plt.xlabel('X')
plt.ylabel('Y')
plt.title('Scatter with Varying Sizes')

plt.savefig('reference_images/scatter-sizes.png', dpi=100)
plt.savefig('reference_images/scatter-sizes.svg')
print('Saved reference_images/scatter-sizes.svg')
plt.savefig('reference_images/scatter-sizes.pdf')
print('Saved reference_images/scatter-sizes.pdf')
print('Saved reference_images/scatter-sizes.png')
