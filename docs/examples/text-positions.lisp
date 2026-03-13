;;;; text-positions.lisp — Line plot with data point labels
;;;; Run: sbcl --load examples/text-positions.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((x '(1 2 3 4 5))
      (y '(2 4 3 5 1)))
  (figure :figsize '(7 5))
  (plot x y :color "steelblue" :linewidth 2.0 :marker :circle)
  (loop for xi in x for yi in y do
    (text xi (+ yi 0.15d0) (format nil "(~D,~D)" xi yi)
          :ha :center :va :bottom :fontsize 9))
  (title "Data Point Labels")
  (xlim 0.5d0 5.5d0)
  (ylim 0 6))

(let ((out "examples/text-positions.png"))
  (savefig out)
  (savefig "examples/text-positions.svg")
  (savefig "examples/text-positions.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
