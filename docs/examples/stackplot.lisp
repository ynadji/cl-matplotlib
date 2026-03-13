;;;; stackplot.lisp — Stacked area chart
;;;; Run: sbcl --load examples/stackplot.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

;; Revenue from 3 product lines over 12 months
(let* ((months '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0
                 7.0d0 8.0d0 9.0d0 10.0d0 11.0d0 12.0d0))
       (product-a '(10.0d0 12.0d0 14.0d0 15.0d0 18.0d0 20.0d0
                    22.0d0 24.0d0 23.0d0 25.0d0 27.0d0 30.0d0))
       (product-b '(8.0d0  9.0d0  11.0d0 12.0d0 10.0d0 13.0d0
                    15.0d0 14.0d0 16.0d0 17.0d0 19.0d0 20.0d0))
       (product-c '(5.0d0  6.0d0  5.0d0  7.0d0  8.0d0  9.0d0
                    8.0d0  10.0d0 11.0d0 12.0d0 11.0d0 13.0d0)))
  (stackplot months (list product-a product-b product-c)
             :labels '("Product A" "Product B" "Product C")
             :colors '("steelblue" "tomato" "seagreen")))

(xlabel "Month")
(ylabel "Revenue ($K)")
(title "Monthly Revenue by Product Line")
(legend)
(grid :visible t)

(let ((out "examples/stackplot.png"))
  (savefig out)
  (savefig "examples/stackplot.svg")
  (savefig "examples/stackplot.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
