"""simple-line.py — Reference for examples/simple-line.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 6))

# x from -10 to 10 inclusive (integers coerced to float)
xs = [float(x) for x in range(-10, 11)]

# y = x^2
ys1 = [x * x for x in xs]
plt.plot(xs, ys1, color='steelblue', linewidth=2.0, label='y = x^2')

# y = 2x + 10
ys2 = [2.0 * x + 10.0 for x in xs]
plt.plot(xs, ys2, color='tomato', linewidth=2.0, linestyle='--', label='y = 2x + 10')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Simple Line Plot')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/simple-line.png', dpi=100)
print('Saved reference_images/simple-line.png')
