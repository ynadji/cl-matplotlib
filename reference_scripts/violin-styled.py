"""violin-styled.py — Reference for examples/violin-styled.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import math
import numpy as np
from matplotlib.lines import Line2D

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'


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


scores_a = [60.0, 65.0, 70.0, 72.0, 74.0, 75.0, 76.0,
            78.0, 80.0, 82.0, 85.0, 88.0, 90.0]
scores_b = [55.0, 60.0, 63.0, 65.0, 68.0, 70.0, 72.0,
            73.0, 75.0, 78.0, 80.0, 85.0, 92.0]
scores_c = [70.0, 72.0, 74.0, 75.0, 76.0, 77.0, 78.0,
            79.0, 80.0, 81.0, 82.0, 83.0, 85.0]

datasets = [scores_a, scores_b, scores_c]
positions = [1, 2, 3]
width = 0.7
half_w = width / 2.0

vpstats, medians, mins_maxs = build_vpstats(datasets)

fig = plt.figure(figsize=(8, 6))
ax = plt.gca()

# Grid below violin bodies (CL draws grid before zorder>=1.5 artists)
ax.grid(visible=True, zorder=0)
for line in ax.get_xgridlines() + ax.get_ygridlines():
    line.set_zorder(0)

# Draw violin bodies using ax.violin — horizontal (vert=False)
parts = ax.violin(vpstats, positions=positions, widths=width,
                  vert=False,
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
    ax.add_line(Line2D([med, med], [pos - half_w, pos + half_w],
                       color='white', linewidth=2.0, zorder=3))
    ax.add_line(Line2D([dmin, dmin], [pos - ext_hw, pos + ext_hw],
                       color='black', linewidth=1.0, zorder=3))
    ax.add_line(Line2D([dmax, dmax], [pos - ext_hw, pos + ext_hw],
                       color='black', linewidth=1.0, zorder=3))

# Match CL axis limits: ylim fixed, xlim = data +/- 5% margin
ax.set_ylim(0.5, 3.5)
all_data = [float(x) for ds in datasets for x in ds]
data_min, data_max = min(all_data), max(all_data)
data_range = data_max - data_min
ax.set_xlim(data_min - data_range * 0.05, data_max + data_range * 0.05)
ax.set_yticks(positions)

plt.xlabel('Score')
plt.ylabel('Group')
plt.title('Violin Plot \u2014 Horizontal Orientation')

plt.savefig('reference_images/violin-styled.png', dpi=100)
print('Saved reference_images/violin-styled.png')
