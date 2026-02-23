"""stacked-bar.py — Reference for examples/stacked-bar.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(10, 6))

categories = [1.0, 2.0, 3.0, 4.0, 5.0]
values_a = [20.0, 35.0, 30.0, 25.0, 15.0]
values_b = [15.0, 20.0, 25.0, 30.0, 35.0]
values_c = [10.0, 15.0, 20.0, 25.0, 30.0]

plt.bar(categories, values_a, width=0.6, label='Group A', color='steelblue',
        edgecolor='black', linewidth=0.5)
plt.bar(categories, values_b, width=0.6, bottom=values_a, label='Group B',
        color='tomato', edgecolor='black', linewidth=0.5)
bottom_c = [a + b for a, b in zip(values_a, values_b)]
plt.bar(categories, values_c, width=0.6, bottom=bottom_c, label='Group C',
        color='seagreen', edgecolor='black', linewidth=0.5)

plt.xlabel('Category')
plt.ylabel('Value')
plt.title('Stacked Bar Chart')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/stacked-bar.png', dpi=100)
print('Saved reference_images/stacked-bar.png')
