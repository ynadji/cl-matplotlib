;;;; pie-explode.lisp — Exploded pie chart (one wedge offset)
;;;; Run: sbcl --load examples/pie-explode.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(pie '(35 25 20 20)
     :explode '(0.0d0 0.1d0 0.0d0 0.0d0)
     :labels '("Category A" "Category B" "Category C" "Category D")
     :colors '("#4C72B0" "#DD8452" "#55A868" "#C44E52")
     :autopct "~,1F%"
     :startangle 90)

(title "Exploded Pie Chart")

(let ((out "examples/pie-explode.png"))
  (savefig out)
  (savefig "examples/pie-explode.svg")
  (savefig "examples/pie-explode.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
