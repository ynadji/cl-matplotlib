"""pie-chart.py — Reference for examples/pie-chart.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(7, 7))

sizes = [35, 25, 20, 15, 5]
labels = ['Python', 'JavaScript', 'Java', 'C++', 'Other']
colors = ['steelblue', 'tomato', 'seagreen', 'goldenrod', 'mediumpurple']

plt.pie(sizes, labels=labels, colors=colors, startangle=90)

plt.title('Market Share')

plt.savefig('reference_images/pie-chart.png', dpi=100)
plt.savefig('reference_images/pie-chart.svg')
print('Saved reference_images/pie-chart.svg')
plt.savefig('reference_images/pie-chart.pdf')
print('Saved reference_images/pie-chart.pdf')
print('Saved reference_images/pie-chart.png')
