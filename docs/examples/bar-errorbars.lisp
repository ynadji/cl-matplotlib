;;;; bar-errorbars.lisp — Bar chart with error bars
;;;; Run: sbcl --load examples/bar-errorbars.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((x '(0 1 2 3 4))
      (values '(3.5d0 5.2d0 4.1d0 6.8d0 2.9d0))
      (errors '(0.3d0 0.5d0 0.4d0 0.6d0 0.2d0))
      (labels '("A" "B" "C" "D" "E")))
  (figure :figsize '(8.0d0 5.0d0))
  (bar x values :yerr errors :capsize 5 :color "steelblue" :edgecolor "black" :linewidth 0.5)
  (set-xticks x :labels labels))

(xlabel "Category")
(ylabel "Value")
(title "Bar Chart with Error Bars")

(let ((out "examples/bar-errorbars.png"))
  (savefig out)
  (savefig "examples/bar-errorbars.svg")
  (savefig "examples/bar-errorbars.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
