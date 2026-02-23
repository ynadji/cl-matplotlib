"""polar-line.py — Reference for examples/polar-line.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

# CL axes display bbox: position [0.125, 0.11, 0.775, 0.77] on 640x480
DW = 0.775 * 640   # 496.0 px
DH = 0.77 * 480    # 369.6 px
RADIUS_PX = 0.5 * min(DW, DH)  # 184.8 px — circle fills shorter dimension
RX = RADIUS_PX / DW  # 0.3726 — unit-space x-radius
RY = RADIUS_PX / DH  # 0.5    — unit-space y-radius
CX, CY = 0.5, 0.5


def draw_polar_background(ax, r_max):
    """Replicate CL polar-axes grid/labels in unit-space [0,1]x[0,1] coordinates."""
    bg = Ellipse((CX, CY), 2*RX, 2*RY, facecolor='white', edgecolor='none', zorder=0)
    ax.add_patch(bg)
    for frac in [0.25, 0.5, 0.75, 1.0]:
        g = Ellipse((CX, CY), 2*RX*frac, 2*RY*frac, fill=False,
                     edgecolor=(0.8, 0.8, 0.8), linewidth=0.5, zorder=1)
        ax.add_patch(g)
    for deg in range(0, 360, 45):
        rad = np.radians(deg)
        ax.plot([CX, CX + RX * np.cos(rad)], [CY, CY + RY * np.sin(rad)],
                color=(0.8, 0.8, 0.8), linewidth=0.5, zorder=1)
    boundary = Ellipse((CX, CY), 2*RX, 2*RY, fill=False,
                        edgecolor='black', linewidth=1.0, zorder=3)
    ax.add_patch(boundary)
    # Theta labels at 108% of display radius → convert to unit-space
    lrx = 1.08 * RADIUS_PX / DW
    lry = 1.08 * RADIUS_PX / DH
    for i, lbl in enumerate(['0°', '45°', '90°', '135°', '180°', '225°', '270°', '315°']):
        rad = np.radians(i * 45)
        ax.text(CX + lrx * np.cos(rad), CY + lry * np.sin(rad),
                lbl, ha='center', va='center', fontsize=8, zorder=4)
    # R labels along θ=0 ray, 5px above center in display → 5/DH in unit-space
    for frac in [0.25, 0.5, 0.75, 1.0]:
        r_tick = r_max * frac
        ax.text(CX + frac * RX, CY + 5.0 / DH,
                f'{r_tick:.2G}', ha='center', va='bottom', fontsize=7, zorder=4)


fig, ax = plt.subplots(figsize=(6.4, 4.8))
ax.set_position([0.125, 0.11, 0.775, 0.77])
ax.axis('off')
ax.set_xlim(0, 1)
ax.set_ylim(0, 1)

theta = np.linspace(0, 2 * np.pi, 201)
r = 1.0 + np.cos(theta)
r_max = float(np.max(np.abs(r))) * 1.05

draw_polar_background(ax, r_max)

# CL polar-affine: scale = 0.5/r_max, translate = (0.5, 0.5)
x_data = r * np.cos(theta) * 0.5 / r_max + 0.5
y_data = r * np.sin(theta) * 0.5 / r_max + 0.5
ax.plot(x_data, y_data, color='C0', linewidth=1.5, zorder=2)

# Title at CL position: y = 1.0 + pad/axes_h where pad = 6*dpi/72+1
title_pad_px = 6.0 * (100.0 / 72.0) + 1.0
y_title = 1.0 + title_pad_px / DH
ax.text(0.5, y_title, 'Cardioid: r = 1 + cos(\u03b8)',
        transform=ax.transAxes, ha='center', va='baseline', fontsize=12)

fig.savefig('reference_images/polar-line.png')
print('Saved reference_images/polar-line.png')
