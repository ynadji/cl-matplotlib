"""inverted-axes.py — Reference for examples/inverted-axes.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

depth = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
temperature = [25, 23, 20, 17, 15, 14, 13, 12, 11, 10, 9]

fig, ax = plt.subplots(figsize=(6, 7))
ax.scatter(temperature, depth, color='steelblue', s=60)
ax.plot(temperature, depth, color='steelblue', linewidth=1.5)
ax.invert_yaxis()
ax.set_title('Ocean Depth Profile')
ax.set_xlabel('Temperature (C)')
ax.set_ylabel('Depth (m)')
plt.savefig('reference_images/inverted-axes.png')
plt.close()
