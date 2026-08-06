"""broken-barh-demo.py — reference for examples/broken-barh-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.broken_barh([(110, 30), (150, 10)], (10, 9), facecolors='tab:blue')
ax.broken_barh([(10, 50), (100, 20), (130, 10)], (20, 9),
               facecolors=('tab:orange', 'tab:green', 'tab:red'))
ax.set_ylim(5, 35)
ax.set_xlim(0, 200)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/broken-barh-demo.{ext}')
print('Saved reference_images/broken-barh-demo.png')
