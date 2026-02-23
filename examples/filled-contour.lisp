;;;; filled-contour.lisp — Filled contour plot of a 2D Gaussian
;;;; Run: sbcl --load examples/filled-contour.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((n 50)
       (xs (loop for i below n collect (- (* 6.0d0 (/ (float i 1.0d0) (1- n))) 3.0d0)))
       (ys (loop for i below n collect (- (* 6.0d0 (/ (float i 1.0d0) (1- n))) 3.0d0)))
       (z  (make-array (list n n) :element-type 'double-float)))
  ;; z = exp(-(x^2 + y^2))
  (loop for j below n
        for yv in ys do
    (loop for i below n
          for xv in xs do
      (setf (aref z j i) (exp (- (+ (* xv xv) (* yv yv)))))))

  (contourf xs ys z :levels 12 :cmap :viridis))

(xlabel "x")
(ylabel "y")
(title "Gaussian: exp(-(x^2+y^2))")

(let ((out "examples/filled-contour.png"))
  (savefig out)
  (savefig "examples/filled-contour.svg")
  (savefig "examples/filled-contour.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
