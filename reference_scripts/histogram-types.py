"""histogram-types.py — Reference for examples/histogram-types.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

data = [-2.5, -2.1, -1.8, -1.6, -1.4, -1.3, -1.2, -1.0, -0.9, -0.8,
        -0.7, -0.6, -0.5, -0.5, -0.4, -0.3, -0.3, -0.2, -0.2, -0.1,
         0.0,  0.0,  0.1,  0.1,  0.2,  0.3,  0.3,  0.4,  0.5,  0.5,
         0.6,  0.7,  0.8,  0.9,  1.0,  1.2,  1.3,  1.4,  1.6,  1.8,
         2.1,  2.5]

fig, axs = plt.subplots(2, 2, figsize=(10, 8))

axs[0, 0].hist(data, bins=10, histtype='bar', color='steelblue', edgecolor='black')
axs[0, 0].grid(visible=True)

axs[0, 1].hist(data, bins=10, histtype='step', color='tomato')
axs[0, 1].grid(visible=True)

axs[1, 0].hist(data, bins=10, histtype='stepfilled', color='seagreen', alpha=0.7)
axs[1, 0].grid(visible=True)

axs[1, 1].hist(data, bins=10, histtype='bar', color='goldenrod', edgecolor='black', alpha=0.8)
axs[1, 1].grid(visible=True)

plt.savefig('reference_images/histogram-types.png', dpi=100)
print('Saved reference_images/histogram-types.png')
