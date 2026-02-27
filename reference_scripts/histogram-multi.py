"""histogram-multi.py — Reference for examples/histogram-multi.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

centers = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0]
width = 0.25
counts_a = [3.0, 5.0, 4.0, 6.0, 3.0, 2.0, 1.0]
counts_b = [1.0, 2.0, 4.0, 5.0, 6.0, 3.0, 2.0]
counts_c = [0.0, 1.0, 2.0, 3.0, 5.0, 5.0, 4.0]

x_a = [c - width for c in centers]
x_c = [c + width for c in centers]

fig = plt.figure(figsize=(10, 6))

plt.bar(x_a, counts_a, width=width, color='steelblue', label='Group A',
        edgecolor='black', linewidth=0.5)
plt.bar(centers, counts_b, width=width, color='tomato', label='Group B',
        edgecolor='black', linewidth=0.5)
plt.bar(x_c, counts_c, width=width, color='seagreen', label='Group C',
        edgecolor='black', linewidth=0.5)

plt.legend()
plt.xlabel('Bin')
plt.ylabel('Count')
plt.title('Multiple Histogram Groups')
plt.grid(visible=True, axis='y')

plt.savefig('reference_images/histogram-multi.png', dpi=100)
plt.savefig('reference_images/histogram-multi.svg')
print('Saved reference_images/histogram-multi.svg')
plt.savefig('reference_images/histogram-multi.pdf')
print('Saved reference_images/histogram-multi.pdf')
print('Saved reference_images/histogram-multi.png')
