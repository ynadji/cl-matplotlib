;;;; legend-outside.lisp — Legend positioned outside the plot area
;;;; Run: sbcl --load examples/legend-outside.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((n 100)
       (xs (loop for i from 0 below n
                 collect (* i (/ (* 2.0d0 pi) (1- n)))))
       (line-colors '("#4C72B0" "#DD8452" "#55A868" "#C44E52"))
       (line-labels '("Alpha" "Beta" "Gamma" "Delta")))
  (loop for i from 0 below 4
        for color in line-colors
        for label in line-labels
        do (plot xs
                 (mapcar (lambda (x) (sin (+ x (* i (/ pi 4.0d0))))) xs)
                 :color color :label label :linewidth 1.5)))

(xlabel "x")
(ylabel "y")
(title "Legend Outside Plot Area")
(legend :bbox-to-anchor '(1.05d0 1.0d0) :loc :upper-left)

(let ((out "examples/legend-outside.png"))
  (savefig out)
  (savefig "examples/legend-outside.svg")
  (savefig "examples/legend-outside.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
