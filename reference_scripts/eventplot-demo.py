"""eventplot-demo.py — reference for examples/eventplot-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
matplotlib.rcParams['text.hinting'] = 'none'
import matplotlib.pyplot as plt

positions = [
    [1.0, 2.5, 3.0, 4.2, 6.0, 7.5, 9.0],
    [0.5, 2.0, 3.5, 5.0, 5.5, 8.0],
    [1.5, 4.0, 4.5, 6.5, 8.5],
]
colors = ['C0', 'C1', 'C2']

fig, ax = plt.subplots(figsize=(6.4, 4.8), dpi=100)
ax.eventplot(positions, lineoffsets=[1, 2, 3], linelengths=0.8,
             colors=colors)
for ext in ('png', 'svg', 'pdf'):
    fig.savefig(f'reference_images/eventplot-demo.{ext}')
print('Saved reference_images/eventplot-demo.png')
