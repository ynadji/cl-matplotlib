;;;; pie-chart.lisp — Pie chart
;;;; Run: sbcl --load examples/pie-chart.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(7.0d0 7.0d0))

(pie '(35 25 20 15 5)
     :labels '("Python" "JavaScript" "Java" "C++" "Other")
     :colors '("steelblue" "tomato" "seagreen" "goldenrod" "mediumpurple")
     :startangle 90)

(title "Market Share")

(let ((out "examples/pie-chart.png"))
  (savefig out)
  (savefig "examples/pie-chart.svg")
  (savefig "examples/pie-chart.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
