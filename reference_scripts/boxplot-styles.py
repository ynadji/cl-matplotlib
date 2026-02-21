"""boxplot-styles.py — Reference for examples/boxplot-styles.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 5))

data = [[2.1, 3.4, 1.8, 2.9, 3.2, 2.5, 1.6, 3.8, 2.7, 3.0],
        [4.2, 5.1, 3.8, 4.9, 5.3, 4.0, 3.5, 5.8, 4.6, 5.2],
        [1.1, 2.0, 1.5, 1.8, 2.3, 1.4, 0.9, 2.5, 1.7, 2.1]]

bp = plt.boxplot(data, widths=0.5)
for element in ['boxes', 'whiskers', 'caps', 'medians']:
    plt.setp(bp[element], color='steelblue', linewidth=1.5)

plt.ylabel('Value')
plt.title('Boxplot with Multiple Groups')
plt.grid(visible=True, axis='y')

plt.savefig('reference_images/boxplot-styles.png', dpi=100)
print('Saved reference_images/boxplot-styles.png')
