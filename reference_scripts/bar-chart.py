"""bar-chart.py — Reference for examples/bar-chart.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 5))

langs = [1, 2, 3, 4, 5, 6]
scores = [45.0, 38.0, 30.0, 25.0, 18.0, 12.0]
colors = ['steelblue', 'tomato', 'seagreen', 'goldenrod', 'mediumpurple', 'coral']

plt.bar(langs, scores, width=0.6, color=colors, edgecolor='black', linewidth=0.8)

plt.xlabel('Language')
plt.ylabel('Popularity')
plt.title('Programming Language Popularity')
plt.grid(visible=True)

plt.savefig('reference_images/bar-chart.png', dpi=100)
plt.savefig('reference_images/bar-chart.svg')
print('Saved reference_images/bar-chart.svg')
plt.savefig('reference_images/bar-chart.pdf')
print('Saved reference_images/bar-chart.pdf')
print('Saved reference_images/bar-chart.png')
