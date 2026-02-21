;;;; inverted-axes.lisp — Scatter plot with inverted y-axis
;;;; Run: sbcl --load examples/inverted-axes.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((depth '(0 10 20 30 40 50 60 70 80 90 100))
      (temp  '(25 23 20 17 15 14 13 12 11 10 9)))
  (figure :figsize '(6.0d0 7.0d0))
  (scatter temp depth :color "steelblue" :s 60.0)
  (plot temp depth :color "steelblue" :linewidth 1.5)
  (invert-yaxis)
  (title "Ocean Depth Profile")
  (xlabel "Temperature (C)")
  (ylabel "Depth (m)"))

(let ((out "examples/inverted-axes.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
