"""subplots-shared.py — Reference for examples/subplots-shared.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig, axs = plt.subplots(2, 2, figsize=(10, 8), sharex=True, sharey=True)

x = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

axs[0, 0].plot(x, [0.0, 0.8, 0.9, 0.1, -0.8, -0.9, 0.0], color='blue', linewidth=1.5)

axs[0, 1].plot(x, [0.0, 0.6, 0.8, 0.2, -0.6, -0.8, 0.0], color='red', linewidth=1.5)

axs[1, 0].plot(x, [0.5, 0.9, 0.4, -0.4, -0.9, -0.4, 0.5], color='green', linewidth=1.5)

axs[1, 1].plot(x, [-0.5, 0.3, 0.9, 0.9, 0.3, -0.5, -0.9], color='purple', linewidth=1.5)

plt.savefig('reference_images/subplots-shared.png', dpi=100)
plt.savefig('reference_images/subplots-shared.svg')
print('Saved reference_images/subplots-shared.svg')
plt.savefig('reference_images/subplots-shared.pdf')
print('Saved reference_images/subplots-shared.pdf')
print('Saved reference_images/subplots-shared.png')
