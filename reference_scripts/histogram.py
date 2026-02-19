"""histogram.py — Reference for examples/histogram.lisp"""
import math
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

# Replicate CL LCG exactly: seed=7, a=1103515245, c=12345, m=2^31
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

rng = LCG(7)

fig = plt.figure(figsize=(8, 5))

data = [5.0 + 2.0 * randn(rng) for _ in range(1000)]

plt.hist(data, bins=30, color='steelblue', edgecolor='white', alpha=0.85)

plt.xlabel('Value')
plt.ylabel('Count')
plt.title('Histogram (N=1000, mean=5, std=2)')
plt.grid(visible=True)

plt.savefig('reference_images/histogram.png', dpi=100)
print('Saved reference_images/histogram.png')
