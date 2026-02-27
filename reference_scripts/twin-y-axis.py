"""twin-y-axis.py — Reference for examples/twin-y-axis.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, ax1 = plt.subplots(figsize=(8, 5))

months = [float(m) for m in range(1, 13)]
temps = [2.0, 4.0, 8.0, 13.0, 18.0, 22.0,
         25.0, 24.0, 20.0, 14.0, 8.0, 3.0]
precip = [50.0, 40.0, 45.0, 55.0, 65.0, 50.0,
          35.0, 40.0, 55.0, 70.0, 65.0, 55.0]

ax1.plot(months, temps, color='blue', linewidth=2.0)
ax1.set_xlabel('Month')
ax1.set_ylabel('Temperature (C)')

ax2 = ax1.twinx()
ax2.plot(months, precip, color='red', linewidth=2.0)
ax2.set_ylabel('Precipitation (mm)')

plt.title('Monthly Temperature and Precipitation')
plt.savefig('reference_images/twin-y-axis.png', dpi=100)
plt.savefig('reference_images/twin-y-axis.svg')
print('Saved reference_images/twin-y-axis.svg')
plt.savefig('reference_images/twin-y-axis.pdf')
print('Saved reference_images/twin-y-axis.pdf')
print('Saved reference_images/twin-y-axis.png')
