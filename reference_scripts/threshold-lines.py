"""threshold-lines.py — Reference for examples/threshold-lines.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import math

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

x = list(range(50))
y = [math.sin(i * 0.3) * 2 for i in x]
mean_val = sum(y) / len(y)
std_val = math.sqrt(sum((v - mean_val)**2 for v in y) / len(y))

fig = plt.figure(figsize=(8, 5))
plt.plot(x, y, color='steelblue', linewidth=1.5, label='Data')
plt.axhline(mean_val, color='red', linestyle='--', linewidth=1.5, label='Mean')
plt.axhline(mean_val + std_val, color='orange', linestyle=':', linewidth=1.5, label='Mean+Std')
plt.axhline(mean_val - std_val, color='orange', linestyle=':', linewidth=1.5, label='Mean-Std')
plt.title('Data with Threshold Lines')
plt.xlabel('Index')
plt.ylabel('Value')
plt.legend()
plt.savefig('reference_images/threshold-lines.png')
plt.close()
