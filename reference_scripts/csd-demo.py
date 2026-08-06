"""csd-demo.py — reference for examples/csd-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

n = 1024
fs = 100.0
x = [math.sin(2*math.pi*10.0*i/fs) + 0.2*(((i*37) % 97)/97.0 - 0.5)
     for i in range(n)]
y = [math.sin(2*math.pi*10.0*i/fs + 0.7) + 0.2*(((i*53) % 89)/89.0 - 0.5)
     for i in range(n)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.csd(x, y, NFFT=256, Fs=fs)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/csd-demo.{ext}')
print('Saved reference_images/csd-demo.png')
