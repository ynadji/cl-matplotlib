"""custom-ticks.py — Reference for examples/custom-ticks.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

x = np.linspace(0, 2*np.pi, 200)
y = np.sin(x)

fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(x, y, color='steelblue', linewidth=2)
pi = np.pi
tick_pos = [0, pi/2, pi, 3*pi/2, 2*pi]
tick_labels = ['0', 'pi/2', 'pi', '3pi/2', '2pi']
ax.set_xticks(tick_pos, tick_labels)
ax.set_title('Sine Wave with Custom Tick Labels')
ax.set_xlabel('Angle')
ax.set_ylabel('sin(x)')
plt.savefig('reference_images/custom-ticks.png')
plt.close()
