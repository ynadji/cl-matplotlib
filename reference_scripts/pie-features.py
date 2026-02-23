"""pie-features.py — Reference for examples/pie-features.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 6))

sizes = [35.0, 25.0, 20.0, 15.0, 5.0]
labels = ['Python', 'Java', 'C++', 'JavaScript', 'Others']
colors = ['steelblue', 'tomato', 'seagreen', 'goldenrod', 'mediumpurple']

plt.pie(sizes, labels=labels, autopct='%1.1f%%',
        colors=colors, startangle=90)

plt.title('Programming Languages')

plt.savefig('reference_images/pie-features.png', dpi=100)
print('Saved reference_images/pie-features.png')
