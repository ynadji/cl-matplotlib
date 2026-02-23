;;;; polar-multi.lisp — Multiple polar curves: cardioid + circle + limaçon
;;;; Run: sbcl --load examples/polar-multi.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig ax)
    (subplots 1 1 :projection :polar)
  (declare (ignore fig))
  (let* ((n 200)
         (theta (loop for i from 0 to n
                      collect (* i (/ (* 2.0d0 pi) n))))
         (r1 (mapcar (lambda (t_) (+ 1.0d0 (cos t_))) theta))
         (r2 (mapcar (lambda (t_) (declare (ignore t_)) 1.0d0) theta))
         (r3 (mapcar (lambda (t_) (+ 0.5d0 (cos t_))) theta)))
    (plot theta r1 :color "C0")
    (plot theta r2 :color "C1")
    (plot theta r3 :color "C2"))
  (title "Multiple Polar Curves")
  (savefig "examples/polar-multi.png"))

(uiop:quit)
