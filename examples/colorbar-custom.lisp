;;;; colorbar-custom.lisp — Custom colormap demonstration
;;;; Run: sbcl --load examples/colorbar-custom.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; Filled contour of z = sin(x)*cos(y) with plasma colormap
(let* ((n 50)
       (xs (loop for i below n
                 collect (- (* 6.0d0 (/ (float i 1.0d0) (1- n))) 3.0d0)))
       (ys (loop for i below n
                 collect (- (* 6.0d0 (/ (float i 1.0d0) (1- n))) 3.0d0)))
       (z  (make-array (list n n) :element-type 'double-float)))
  ;; z = sin(x) * cos(y)
  (loop for j below n
        for yv in ys do
    (loop for i below n
          for xv in xs do
      (setf (aref z j i) (* (sin xv) (cos yv)))))
  (contourf xs ys z :levels 16 :cmap :plasma))

(xlabel "x")
(ylabel "y")
(title "Custom Colormap — Plasma")

(let ((out "examples/colorbar-custom.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
