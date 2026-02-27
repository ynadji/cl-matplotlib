"""barh.py — Reference for examples/barh.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(8, 5))

# Programming language popularity scores
positions = [1.0, 2.0, 3.0, 4.0, 5.0]
scores = [45.0, 38.0, 30.0, 25.0, 18.0]

plt.barh(positions, scores, height=0.6, color='steelblue',
         edgecolor='black', linewidth=0.8)

plt.xlabel('Popularity Score')
plt.ylabel('Language')
plt.title('Programming Language Popularity (Horizontal)')
plt.grid(visible=True)

plt.savefig('reference_images/barh.png', dpi=100)
plt.savefig('reference_images/barh.svg')
print('Saved reference_images/barh.svg')
plt.savefig('reference_images/barh.pdf')
print('Saved reference_images/barh.pdf')
print('Saved reference_images/barh.png')
