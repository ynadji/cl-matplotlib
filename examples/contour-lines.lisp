;;;; contour-lines.lisp — Contour lines (unfilled) of a Gaussian
;;;; Run: sbcl --load examples/contour-lines.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; Contour lines of z = exp(-(x^2 + y^2))
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
      (setf (aref z j i) (exp (- (+ (* xv xv) (* yv yv)))))))
  (contour xs ys z :levels 8 :cmap :viridis))

(xlabel "x")
(ylabel "y")
(title "Contour Lines — Gaussian")
(grid :visible t)

(let ((out "examples/contour-lines.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
