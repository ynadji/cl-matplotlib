"""violin-basic.py — Reference for examples/violin-basic.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import math
import numpy as np
from matplotlib.lines import Line2D

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42


def cl_gaussian_kde(dataset, eval_points):
    """Match CL's GaussianKDE: Scott's rule h = n^(-1/5) * sigma_pop."""
    n = len(dataset)
    if n == 0:
        return [0.0] * len(eval_points)
    mean = sum(dataset) / n
    variance = sum((x - mean) ** 2 for x in dataset) / n
    sigma = math.sqrt(variance)
    h = max(1e-3, n ** (-0.2) * sigma)
    inv_n_h = 1.0 / (n * h)
    inv_sqrt_2pi = 1.0 / math.sqrt(2.0 * math.pi)
    result = []
    for x in eval_points:
        total = sum(inv_sqrt_2pi * math.exp(-0.5 * ((x - xi) / h) ** 2)
                    for xi in dataset)
        result.append(inv_n_h * total)
    return result


def build_vpstats(datasets):
    """Build violin stats matching CL's KDE algorithm."""
    vpstats = []
    medians = []
    mins_maxs = []
    for data_raw in datasets:
        data = sorted([float(x) for x in data_raw])
        n = len(data)
        dmin, dmax = data[0], data[-1]
        drange = dmax - dmin
        pad = 0.05 * max(drange, 1e-6)
        n_eval = 100
        step = (dmax + pad - (dmin - pad)) / (n_eval - 1)
        coords = [dmin - pad + i * step for i in range(n_eval)]
        vals = cl_gaussian_kde(data, coords)
        kde_max = max(vals)
        if kde_max > 0:
            vals = [v / kde_max for v in vals]
        if n % 2 == 1:
            median = data[n // 2]
        else:
            median = (data[n // 2 - 1] + data[n // 2]) / 2.0
        vpstats.append({
            'coords': np.array(coords),
            'vals': np.array(vals),
            'mean': sum(data) / n,
            'median': median,
            'min': dmin,
            'max': dmax,
        })
        medians.append(median)
        mins_maxs.append((dmin, dmax))
    return vpstats, medians, mins_maxs


group_a = [3.0, 5.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0,
           13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 20.0]
group_b = [1.0, 2.0, 2.0, 3.0, 3.0, 4.0, 4.0, 5.0,
           6.0, 15.0, 16.0, 17.0, 17.0, 18.0, 19.0]
group_c = [8.0, 9.0, 10.0, 10.0, 11.0, 11.0, 12.0, 12.0,
           12.0, 13.0, 13.0, 14.0, 14.0, 15.0, 16.0]

datasets = [group_a, group_b, group_c]
positions = [1, 2, 3]
width = 0.5
half_w = width / 2.0

vpstats, medians, mins_maxs = build_vpstats(datasets)

fig = plt.figure(figsize=(8, 6))
ax = plt.gca()

# Grid below violin bodies (CL draws grid before zorder>=1.5 artists)
ax.grid(visible=True, zorder=0)
for line in ax.get_xgridlines() + ax.get_ygridlines():
    line.set_zorder(0)

# Draw violin bodies using ax.violin (no median/extrema — we draw those manually)
parts = ax.violin(vpstats, positions=positions, widths=width,
                  showmeans=False, showmedians=False, showextrema=False)

for body in parts['bodies']:
    body.set_facecolor('C0')
    body.set_edgecolor('black')
    body.set_linewidth(1.0)
    body.set_alpha(0.7)
    body.set_zorder(2)

# Median lines: full violin width (CL uses pos +/- half_w)
# Extrema lines: half violin width (CL uses pos +/- half_w*0.5)
ext_hw = half_w * 0.5
for pos, med, (dmin, dmax) in zip(positions, medians, mins_maxs):
    ax.add_line(Line2D([pos - half_w, pos + half_w], [med, med],
                       color='white', linewidth=2.0, zorder=3))
    ax.add_line(Line2D([pos - ext_hw, pos + ext_hw], [dmin, dmin],
                       color='black', linewidth=1.0, zorder=3))
    ax.add_line(Line2D([pos - ext_hw, pos + ext_hw], [dmax, dmax],
                       color='black', linewidth=1.0, zorder=3))

# Match CL axis limits: xlim fixed, ylim = data +/- 5% margin
ax.set_xlim(0.5, 3.5)
all_data = [float(x) for ds in datasets for x in ds]
data_min, data_max = min(all_data), max(all_data)
data_range = data_max - data_min
ax.set_ylim(data_min - data_range * 0.05, data_max + data_range * 0.05)
ax.set_xticks(positions)

plt.xlabel('Group')
plt.ylabel('Value')
plt.title('Violin Plot \u2014 Distribution Comparison')

plt.savefig('reference_images/violin-basic.png', dpi=100)
plt.savefig('reference_images/violin-basic.svg')
print('Saved reference_images/violin-basic.svg')
plt.savefig('reference_images/violin-basic.pdf')
print('Saved reference_images/violin-basic.pdf')
print('Saved reference_images/violin-basic.png')
