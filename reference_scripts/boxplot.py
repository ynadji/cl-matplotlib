"""boxplot.py — Reference for examples/boxplot.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 6))

# 4 groups with different spreads (fixed data, no randomness)
group_a = [10.0, 12.0, 14.0, 15.0, 16.0, 18.0, 20.0,
           22.0, 24.0, 25.0, 26.0, 28.0, 30.0]
group_b = [5.0, 8.0, 10.0, 12.0, 14.0, 15.0, 15.0,
           16.0, 17.0, 18.0, 20.0, 25.0, 35.0]
group_c = [18.0, 19.0, 20.0, 20.0, 21.0, 21.0, 22.0,
           22.0, 23.0, 23.0, 24.0, 24.0, 25.0]
group_d = [2.0, 5.0, 8.0, 11.0, 15.0, 20.0, 25.0,
           30.0, 35.0, 38.0, 40.0, 42.0, 45.0]

bp = plt.boxplot([group_a, group_b, group_c, group_d],
                 widths=0.5)
# Style to match CL: color="steelblue", linewidth=1.5
for element in ['boxes', 'whiskers', 'caps', 'medians']:
    plt.setp(bp[element], color='steelblue', linewidth=1.5)

plt.xlabel('Group')
plt.ylabel('Value')
plt.title('Box and Whisker Plot — 4 Groups')
plt.grid(visible=True)

plt.savefig('reference_images/boxplot.png', dpi=100)
plt.savefig('reference_images/boxplot.svg')
print('Saved reference_images/boxplot.svg')
plt.savefig('reference_images/boxplot.pdf')
print('Saved reference_images/boxplot.pdf')
print('Saved reference_images/boxplot.png')
