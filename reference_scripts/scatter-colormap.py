"""scatter-colormap.py — Reference for examples/scatter-colormap.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import math

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

# Deterministic data — identical math in both Python and CL
n = 150
x = [math.sin(i * 0.1) * 50 + 50 for i in range(n)]
y = [math.cos(i * 0.13) * 50 + 50 for i in range(n)]
colors_val = [math.sin(i * 0.05) * 0.5 + 0.5 for i in range(n)]
sizes = [(math.sin(i * 0.07) + 1) * 100 + 20 for i in range(n)]

# Compute explicit hex colors (viridis-like gradient: blue->green->yellow)
# Simple deterministic RGB formula identical in Python and CL
colors_hex = []
for c in colors_val:
    r = int(68 + c * 120)
    g = int(1 + c * 180)
    b = int(84 + (1 - c) * 160)
    colors_hex.append('#%02x%02x%02x' % (r, g, b))

# Debug: print first 5 values
print('x[:5]  =', x[:5])
print('y[:5]  =', y[:5])
print('c[:5]  =', colors_hex[:5])
print('s[:5]  =', sizes[:5])

fig, ax = plt.subplots(figsize=(8, 5))
sc = ax.scatter(x, y, c=colors_hex, s=sizes, alpha=0.8)
ax.set_xlabel('X')
ax.set_ylabel('Y')
ax.set_title('Scatter with Colormap')

plt.savefig('reference_images/scatter-colormap.png', dpi=100)
plt.savefig('reference_images/scatter-colormap.svg')
plt.savefig('reference_images/scatter-colormap.pdf')
print('Saved reference_images/scatter-colormap.{png,svg,pdf}')
plt.close('all')
