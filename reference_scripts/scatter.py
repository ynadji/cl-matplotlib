"""scatter.py — Reference for examples/scatter.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

# Replicate CL LCG exactly: seed=42, a=1103515245, c=12345, m=2^31
class LCG:
    def __init__(self, seed):
        self.seed = seed
        self.m = 2 ** 31

    def random(self):
        self.seed = (self.seed * 1103515245 + 12345) % self.m
        return self.seed / self.m

def randn(rng):
    """Box-Muller transform matching CL implementation."""
    u1 = max(1e-10, rng.random())
    u2 = rng.random()
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)

rng = LCG(42)

fig = plt.figure(figsize=(8, 6))

n = 200
xs = [randn(rng) for _ in range(n)]
ys = [0.7 * x + 0.5 * randn(rng) for x in xs]

plt.scatter(xs, ys, s=25.0, color='darkorchid', alpha=0.6, label='data')

plt.xlabel('x')
plt.ylabel('y')
plt.title('Scatter Plot')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/scatter.png', dpi=100)
plt.savefig('reference_images/scatter.svg')
print('Saved reference_images/scatter.svg')
plt.savefig('reference_images/scatter.pdf')
print('Saved reference_images/scatter.pdf')
print('Saved reference_images/scatter.png')
