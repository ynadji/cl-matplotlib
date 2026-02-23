"""logit-demo.py — Reference for examples/logit-demo.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(8, 5))

ps = [0.01 + i * (0.98 / 99) for i in range(100)]
ys = [p * (1 - p) for p in ps]

plt.plot(ps, ys, color='green', linestyle='-', linewidth=1.5)
plt.grid(visible=True)
plt.xlabel('Probability p')
plt.ylabel('p(1-p)')
plt.title('Probability Product p(1-p)')

plt.savefig('reference_images/logit-demo.png', dpi=100)
print('Saved reference_images/logit-demo.png')
