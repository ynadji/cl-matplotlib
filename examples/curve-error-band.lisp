;;;; curve-error-band.lisp — Line plot with shaded error band
;;;; Run: sbcl --load examples/curve-error-band.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((x (loop for i from 0 below 50
                collect (* 10.0d0 (/ (float i 1.0d0) 49.0d0))))
       (y (mapcar (lambda (xi) (+ (sin xi) (* 0.5d0 (sin (* 2.0d0 xi))))) x))
       (y-err (mapcar (lambda (xi) (+ 0.3d0 (* 0.1d0 (abs (cos xi))))) x))
       (y-minus (mapcar #'- y y-err))
       (y-plus  (mapcar #'+ y y-err)))
  (plot x y :color "blue" :linestyle "-" :linewidth 2 :label "Signal")
  (fill-between x y-minus y-plus :alpha 0.3 :color "blue" :label "Uncertainty"))

(xlabel "x")
(ylabel "y")
(title "Curve with Error Band")
(legend)
(grid :visible t)

(let ((out "examples/curve-error-band.png"))
  (savefig out)
  (savefig "examples/curve-error-band.svg")
  (savefig "examples/curve-error-band.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
