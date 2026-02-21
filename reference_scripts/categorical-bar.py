"""categorical-bar.py — Reference for examples/categorical-bar.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

categories = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun']
values = [42, 35, 51, 48, 63, 55]
x = list(range(len(categories)))

fig, ax = plt.subplots(figsize=(8, 5))
ax.bar(x, values, color='steelblue', width=0.6)
ax.set_xticks(x, categories)
ax.set_title('Monthly Sales')
ax.set_ylabel('Sales (units)')
ax.set_ylim(0, 80)
plt.savefig('reference_images/categorical-bar.png')
plt.close()
