"""specgram-demo.py — reference for examples/specgram-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import matplotlib.pyplot as plt

# chirp: frequency sweeps 5 -> 45 Hz
n = 2048
fs = 100.0
x = [math.sin(2*math.pi*(5.0 + 20.0*i/n)*i/fs) for i in range(n)]

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.specgram(x, NFFT=128, Fs=fs, noverlap=64)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/specgram-demo.{ext}')
print('Saved reference_images/specgram-demo.png')
