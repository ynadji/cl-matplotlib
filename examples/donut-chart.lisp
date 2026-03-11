;;;; donut-chart.lisp — Donut chart (pie with hole)
;;;; Run: sbcl --load examples/donut-chart.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(pie '(35 25 20 20)
     :labels '("Category A" "Category B" "Category C" "Category D")
     :colors '("#4C72B0" "#DD8452" "#55A868" "#C44E52")
     :autopct "~,1F%"
     :wedgeprops '(:width 0.5d0)
     :startangle 90)

(title "Donut Chart")

(let ((out "examples/donut-chart.png"))
  (savefig out)
  (savefig "examples/donut-chart.svg")
  (savefig "examples/donut-chart.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
