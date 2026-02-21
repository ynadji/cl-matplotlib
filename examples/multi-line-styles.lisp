;;;; multi-line-styles.lisp — Multiple lines with different linestyles
;;;; Run: sbcl --load examples/multi-line-styles.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let ((xs (loop for i from 0 to 100
                collect (* i 0.1d0))))
  (plot xs (mapcar (lambda (x) (sin x)) xs)
        :linestyle :solid :color "blue" :linewidth 2 :label "solid")
  (plot xs (mapcar (lambda (x) (sin (+ x 0.5d0))) xs)
        :linestyle :dashed :color "red" :linewidth 2 :label "dashed")
  (plot xs (mapcar (lambda (x) (sin (+ x 1.0d0))) xs)
        :linestyle :dotted :color "green" :linewidth 2 :label "dotted")
  (plot xs (mapcar (lambda (x) (sin (+ x 1.5d0))) xs)
        :linestyle :dashdot :color "orange" :linewidth 2 :label "dash-dot"))

(legend)
(grid :visible t)
(xlabel "x")
(ylabel "y")
(title "Line Styles")

(let ((out "examples/multi-line-styles.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
