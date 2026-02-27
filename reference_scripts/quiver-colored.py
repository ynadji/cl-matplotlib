"""quiver-colored.py — Reference for examples/quiver-colored.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
from matplotlib.collections import PolyCollection

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42


def draw_cl_quiver(ax, X, Y, U, V, color='C0'):
    """Draw quiver arrows matching CL's rendering algorithm exactly."""
    x_flat = X.flatten()
    y_flat = Y.flatten()
    u_flat = U.flatten()
    v_flat = V.flatten()
    n = len(x_flat)

    x_range = max(1e-10, float(x_flat.max() - x_flat.min()))
    y_range = max(1e-10, float(y_flat.max() - y_flat.min()))
    span = max(x_range, y_range)
    shaft_width = 0.005 * span

    magnitudes = np.sqrt(u_flat**2 + v_flat**2)
    nonzero = magnitudes[magnitudes > 0]
    mean_mag = float(nonzero.mean()) if len(nonzero) > 0 else 1.0
    scale_factor = mean_mag / (0.1 * span)

    hw = 3.0 * shaft_width
    hl = 5.0 * shaft_width
    half_sw = shaft_width / 2.0

    polygons = []
    for i in range(n):
        x, y = float(x_flat[i]), float(y_flat[i])
        u, v = float(u_flat[i]), float(v_flat[i])
        mag = float(magnitudes[i])
        if mag == 0:
            continue

        theta = np.arctan2(v, u)
        arrow_len = mag / scale_factor
        shaft_len = max(0.0, arrow_len - hl)

        local = [
            (0, -half_sw),
            (shaft_len, -half_sw),
            (shaft_len, -hw),
            (arrow_len, 0),
            (shaft_len, hw),
            (shaft_len, half_sw),
            (0, half_sw),
        ]

        cos_t = np.cos(theta)
        sin_t = np.sin(theta)
        verts = [(x + lx*cos_t - ly*sin_t, y + lx*sin_t + ly*cos_t)
                 for lx, ly in local]
        polygons.append(verts)

    if polygons:
        pc = PolyCollection(polygons, facecolors=[color], edgecolors=[color],
                            linewidths=[0])
        pc.set_zorder(2)
        ax.add_collection(pc, autolim=False)

    x_margin = x_range * 0.05
    y_margin = y_range * 0.05
    ax.set_xlim(float(x_flat.min()) - x_margin, float(x_flat.max()) + x_margin)
    ax.set_ylim(float(y_flat.min()) - y_margin, float(y_flat.max()) + y_margin)


fig = plt.figure(figsize=(8, 6))
ax = plt.gca()

x = np.linspace(-3, 3, 6)
y = np.linspace(-3, 3, 6)
X, Y = np.meshgrid(x, y)
U = -Y
V = X

draw_cl_quiver(ax, X, Y, U, V)

ax.set_xticks([-3, -2, -1, 0, 1, 2, 3])
ax.set_yticks([-3, -2, -1, 0, 1, 2, 3])

ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_title('Quiver Plot \u2014 Rotational Field')
ax.grid(True)

fig.savefig('reference_images/quiver-colored.png', dpi=100)
fig.savefig('reference_images/quiver-colored.svg')
print('Saved reference_images/quiver-colored.svg')
fig.savefig('reference_images/quiver-colored.pdf')
print('Saved reference_images/quiver-colored.pdf')
print('Saved reference_images/quiver-colored.png')
