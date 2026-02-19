"""twin-axes.py — Reference for examples/twin-axes.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig, axs = plt.subplots(1, 2, figsize=(12, 5))

months = list(range(1, 13))
months_f = [float(m) for m in months]
temps = [2.0, 4.0, 8.0, 13.0, 18.0, 22.0,
         25.0, 24.0, 20.0, 14.0, 8.0, 3.0]
precip = [50.0, 40.0, 45.0, 55.0, 65.0, 50.0,
          35.0, 40.0, 55.0, 70.0, 65.0, 55.0]

axs[0].plot(months_f, temps, color='tomato', linewidth=2.0)
axs[0].set_xlabel('Month')
axs[0].set_ylabel('Temperature (C)')
axs[0].grid(visible=True)

axs[1].bar(months_f, precip, color='steelblue', width=0.6)
axs[1].set_xlabel('Month')
axs[1].set_ylabel('Precipitation (mm)')
axs[1].grid(visible=True)

plt.savefig('reference_images/twin-axes.png', dpi=100)
print('Saved reference_images/twin-axes.png')
