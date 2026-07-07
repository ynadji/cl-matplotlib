"""matshow-demo.py — reference for examples/matshow-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import math
import numpy as np
import matplotlib.pyplot as plt

z = np.array([[math.sin(i*0.7) * math.cos(j*0.5) for j in range(12)]
              for i in range(10)])

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.matshow(z)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/matshow-demo.{ext}')
print('Saved reference_images/matshow-demo.png')
