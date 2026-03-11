"""histogram-stacked.py — Reference for examples/histogram-stacked.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import math

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

n = 200
d1 = [math.sin(i * 0.05) * 20 + 50 for i in range(n)]
d2 = [math.cos(i * 0.07) * 15 + 45 for i in range(n)]
d3 = [math.sin(i * 0.03 + 1) * 25 + 55 for i in range(n)]

# Explicit bin edges so both Python and CL share identical bins
bin_edges = [25 + i * 4 for i in range(16)]  # 15 bins from 25 to 85
bin_centers = [(bin_edges[i] + bin_edges[i + 1]) / 2 for i in range(15)]
bin_width = 4


def count_bins(data, edges):
    counts = []
    for i in range(len(edges) - 1):
        lo, hi = edges[i], edges[i + 1]
        counts.append(sum(1 for x in data if lo <= x < hi))
    return counts


c1 = count_bins(d1, bin_edges)
c2 = count_bins(d2, bin_edges)
c3 = count_bins(d3, bin_edges)
bottom1 = c1
bottom2 = [a + b for a, b in zip(c1, c2)]

fig, ax = plt.subplots(figsize=(8, 5))
ax.bar(bin_centers, c1, width=bin_width, color='#4C72B0', label='Group A',
       edgecolor='white', linewidth=0.5)
ax.bar(bin_centers, c2, width=bin_width, bottom=bottom1, color='#DD8452',
       label='Group B', edgecolor='white', linewidth=0.5)
ax.bar(bin_centers, c3, width=bin_width, bottom=bottom2, color='#55A868',
       label='Group C', edgecolor='white', linewidth=0.5)
ax.set_xlabel('Value')
ax.set_ylabel('Count')
ax.set_title('Stacked Histogram')
ax.legend()

plt.savefig('reference_images/histogram-stacked.png', dpi=100)
plt.savefig('reference_images/histogram-stacked.svg')
print('Saved reference_images/histogram-stacked.svg')
plt.savefig('reference_images/histogram-stacked.pdf')
print('Saved reference_images/histogram-stacked.pdf')
print('Saved reference_images/histogram-stacked.png')
plt.close('all')
