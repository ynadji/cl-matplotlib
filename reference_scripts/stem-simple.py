"""stem-simple.py — Reference for examples/stem-simple.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 5))

x = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0]
y = [1.5, -0.5, 2.3, -1.2, 3.0, -2.1, 1.8, -0.8, 2.5, -1.5]

plt.stem(x, y)

plt.xlabel('x')
plt.ylabel('y')
plt.title('Stem Plot')
plt.grid(visible=True)

plt.savefig('reference_images/stem-simple.png', dpi=100)
print('Saved reference_images/stem-simple.png')
