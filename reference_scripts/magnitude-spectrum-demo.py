"""magnitude-spectrum-demo.py — reference for examples/magnitude-spectrum-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

n = 512
fs = 100.0
x = [math.sin(2*math.pi*15.0*i/fs) + 0.4*math.sin(2*math.pi*40.0*i/fs)
     for i in range(n)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.magnitude_spectrum(x, Fs=fs)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/magnitude-spectrum-demo.{ext}')
print('Saved reference_images/magnitude-spectrum-demo.png')
