;;;; fill-between-alpha.lisp — Fill between curves with transparency
;;;; Run: sbcl --load examples/fill-between-alpha.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((x (loop for i from 0 below 100
                collect (* 4.0d0 pi (/ (float i 1.0d0) 99.0d0))))
       (y1 (mapcar #'sin x))
       (y2 (mapcar (lambda (v) (* v 0.5d0)) y1))
       (y3 (mapcar (lambda (v) (* v 1.5d0)) y1)))
  (plot x y1 :color "blue" :linestyle :solid :linewidth 1.5 :label "sin(x)")
  (plot x y3 :color "blue" :linestyle :solid :linewidth 0.8 :label "1.5 sin(x)")
  (plot x y2 :color "blue" :linestyle :solid :linewidth 0.8 :label "0.5 sin(x)")
  (fill-between x y2 y3 :alpha 0.3 :color "blue" :label "±50% band"))

(xlabel "x")
(ylabel "y")
(title "Fill Between with Transparency")
(legend)
(grid :visible t)

(let ((out "examples/fill-between-alpha.png"))
  (savefig out)
  (savefig "examples/fill-between-alpha.svg")
  (savefig "examples/fill-between-alpha.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
