"""stackplot.py — Reference for examples/stackplot.lisp"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

plt.rcParams['savefig.dpi'] = 100
plt.rcParams['text.hinting'] = 'none'

fig = plt.figure(figsize=(10, 6))

# Revenue from 3 product lines over 12 months
months = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0,
          7.0, 8.0, 9.0, 10.0, 11.0, 12.0]
product_a = [10.0, 12.0, 14.0, 15.0, 18.0, 20.0,
             22.0, 24.0, 23.0, 25.0, 27.0, 30.0]
product_b = [8.0, 9.0, 11.0, 12.0, 10.0, 13.0,
             15.0, 14.0, 16.0, 17.0, 19.0, 20.0]
product_c = [5.0, 6.0, 5.0, 7.0, 8.0, 9.0,
             8.0, 10.0, 11.0, 12.0, 11.0, 13.0]

plt.stackplot(months, product_a, product_b, product_c,
              labels=['Product A', 'Product B', 'Product C'],
              colors=['steelblue', 'tomato', 'seagreen'])

plt.xlabel('Month')
plt.ylabel('Revenue ($K)')
plt.title('Monthly Revenue by Product Line')
plt.legend()
plt.grid(visible=True)

plt.savefig('reference_images/stackplot.png', dpi=100)
print('Saved reference_images/stackplot.png')
