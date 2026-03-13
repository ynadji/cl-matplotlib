;;;; polar-line.lisp — Polar line plot: cardioid r = 1 + cos(θ)
;;;; Run: sbcl --load examples/polar-line.lisp

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
         (r (mapcar (lambda (t_) (+ 1.0d0 (cos t_))) theta)))
    (plot theta r))
  (title "Cardioid: r = 1 + cos(θ)")
  (savefig "examples/polar-line.png")
  (savefig "examples/polar-line.svg")
  (savefig "examples/polar-line.pdf"))

(uiop:quit)
