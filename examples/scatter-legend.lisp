;;;; scatter-legend.lisp — Scatter plot with categorical legend
;;;; Run: sbcl --load examples/scatter-legend.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(scatter '(1.0d0 1.5d0 2.0d0 2.5d0 3.0d0)
         '(2.0d0 2.5d0 1.8d0 2.8d0 2.2d0)
         :s 80 :color "blue" :label "Group A" :alpha 0.7)
(scatter '(4.0d0 4.5d0 5.0d0 5.5d0 6.0d0)
         '(4.0d0 3.5d0 4.5d0 3.8d0 4.2d0)
         :s 80 :color "red" :label "Group B" :alpha 0.7)
(scatter '(7.0d0 7.5d0 8.0d0 8.5d0 9.0d0)
         '(6.0d0 6.5d0 5.8d0 6.8d0 6.2d0)
         :s 80 :color "green" :label "Group C" :alpha 0.7)

(legend :loc "upper left")
(xlabel "X")
(ylabel "Y")
(title "Scatter Plot with Legend")
(grid :visible t)

(let ((out "examples/scatter-legend.png"))
  (savefig out)
  (savefig "examples/scatter-legend.svg")
  (savefig "examples/scatter-legend.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
