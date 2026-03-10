"""step-plot.py — Reference for examples/step-plot.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'
plt.rcParams['svg.fonttype'] = 'path'
plt.rcParams['pdf.fonttype'] = 42

fig = plt.figure(figsize=(10, 5))

# Digital signal: alternating 0/1 with varying durations
xs = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0,
      8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0]
ys = [0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0,
      1.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0]

plt.step(xs, ys, where='post', color='steelblue', linewidth=2.0,
         label='Digital Signal (post)')

plt.xlabel('Time (μs)')
plt.ylabel('Amplitude')
plt.title('Step Plot — Digital Signal')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/step-plot.png', dpi=100)
plt.savefig('reference_images/step-plot.svg')
print('Saved reference_images/step-plot.svg')
plt.savefig('reference_images/step-plot.pdf')
print('Saved reference_images/step-plot.pdf')
print('Saved reference_images/step-plot.png')
