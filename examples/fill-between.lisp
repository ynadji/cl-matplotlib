;;;; fill-between.lisp — Fill between sin(x) and cos(x)
;;;; Run: sbcl --load examples/fill-between.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

;; Fill between sin(x) and cos(x) from 0 to 2*pi
(let* ((xs (loop for x from 0.0d0 to (* 2.0d0 pi) by 0.1d0
                 collect x))
       (y-sin (mapcar #'sin xs))
       (y-cos (mapcar #'cos xs)))
  ;; Plot the curves
  (plot xs y-sin :color "steelblue" :linewidth 2.0 :label "sin(x)")
  (plot xs y-cos :color "tomato" :linewidth 2.0 :label "cos(x)")
  ;; Fill between with alpha
  (fill-between xs y-sin y-cos :color "mediumpurple" :alpha 0.3
                :label "Fill region"))

(xlabel "x (radians)")
(ylabel "y")
(title "Fill Between sin(x) and cos(x)")
(legend)
(grid :visible t)

(let ((out "examples/fill-between.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
