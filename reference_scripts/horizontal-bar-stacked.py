"""horizontal-bar-stacked.py — Reference for examples/horizontal-bar-stacked.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(10, 6))

y = [1.0, 2.0, 3.0, 4.0, 5.0]
values_a = [20.0, 35.0, 15.0, 30.0, 25.0]
values_b = [15.0, 20.0, 30.0, 10.0, 25.0]
values_c = [10.0, 15.0, 20.0, 25.0, 15.0]

plt.barh(y, values_a, height=0.6, label='Group A', color='steelblue',
         edgecolor='black', linewidth=0.5)
plt.barh(y, values_b, height=0.6, left=values_a, label='Group B', color='tomato',
         edgecolor='black', linewidth=0.5)
left_c = [a + b for a, b in zip(values_a, values_b)]
plt.barh(y, values_c, height=0.6, left=left_c, label='Group C', color='seagreen',
         edgecolor='black', linewidth=0.5)

plt.ylabel('Category')
plt.xlabel('Value')
plt.title('Stacked Horizontal Bar Chart')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/horizontal-bar-stacked.png', dpi=100)
plt.savefig('reference_images/horizontal-bar-stacked.svg')
print('Saved reference_images/horizontal-bar-stacked.svg')
plt.savefig('reference_images/horizontal-bar-stacked.pdf')
print('Saved reference_images/horizontal-bar-stacked.pdf')
print('Saved reference_images/horizontal-bar-stacked.png')
