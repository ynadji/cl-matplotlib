;;;; polar-scatter.lisp — Discrete points on a polar curve
;;;; Run: sbcl --load examples/polar-scatter.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig ax)
    (subplots 1 1 :projection :polar)
  (declare (ignore fig))
  (let* ((theta (loop for i from 0 below 20
                      collect (* i (/ (* 2.0d0 pi) 20))))
         (r (mapcar (lambda (t_) (+ 0.5d0 (* 0.5d0 (sin t_)))) theta)))
    (plot theta r :marker :circle :linewidth 0 :color "C3"))
  (title "Polar Scatter")
  (savefig "examples/polar-scatter.png"))

(uiop:quit)
