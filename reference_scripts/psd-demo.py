"""psd-demo.py — reference for examples/psd-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

# two sinusoids + deterministic pseudo-noise (integer-mod, bit-exact)
n = 1024
fs = 100.0
x = [math.sin(2*math.pi*10.0*i/fs) + 0.5*math.sin(2*math.pi*25.0*i/fs)
     + 0.1*(((i*37) % 97)/97.0 - 0.5)
     for i in range(n)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.psd(x, NFFT=256, Fs=fs)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/psd-demo.{ext}')
print('Saved reference_images/psd-demo.png')
