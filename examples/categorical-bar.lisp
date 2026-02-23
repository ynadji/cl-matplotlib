;;;; categorical-bar.lisp — Bar chart with categorical x-axis via set-xticks
;;;; Run: sbcl --load examples/categorical-bar.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((x '(0 1 2 3 4 5))
      (values '(42 35 51 48 63 55))
      (cats '("Jan" "Feb" "Mar" "Apr" "May" "Jun")))
  (figure :figsize '(8.0d0 5.0d0))
  (bar x values :color "steelblue" :width 0.6)
  (set-xticks x :labels cats)
  (title "Monthly Sales")
  (ylabel "Sales (units)")
  (ylim 0 80))

(let ((out "examples/categorical-bar.png"))
  (savefig out)
  (savefig "examples/categorical-bar.svg")
  (savefig "examples/categorical-bar.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
