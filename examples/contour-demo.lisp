;;;; contour-demo.lisp — Contour lines of sin(x)*cos(y)
;;;; Run: sbcl --load examples/contour-demo.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; Contour lines of z = sin(x) * cos(y)
(let* ((n 50)
       (xs (loop for i below n
                 collect (- (* 6.0d0 (/ (float i 1.0d0) (1- n))) 3.0d0)))
       (ys (loop for i below n
                 collect (- (* 6.0d0 (/ (float i 1.0d0) (1- n))) 3.0d0)))
       (z  (make-array (list n n) :element-type 'double-float)))
  (loop for j below n
        for yv in ys do
    (loop for i below n
          for xv in xs do
      (setf (aref z j i) (* (sin xv) (cos yv)))))
  (contourf xs ys z
           :levels '(-1.0d0 -0.75d0 -0.5d0 -0.25d0 0.0d0 0.25d0 0.5d0 0.75d0 1.0d0)
           :cmap :plasma))

(xlabel "x")
(ylabel "y")
(title "Contour Demo — sin(x)cos(y)")

(let ((out "examples/contour-demo.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
