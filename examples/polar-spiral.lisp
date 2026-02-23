;;;; polar-spiral.lisp — Archimedean spiral: r = θ/(2π)
;;;; Run: sbcl --load examples/polar-spiral.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig ax)
    (subplots 1 1 :projection :polar)
  (declare (ignore fig))
  (let* ((n 300)
         (theta (loop for i from 0 to n
                      collect (* i (/ (* 4.0d0 pi) n))))
         (r (mapcar (lambda (t_) (/ t_ (* 2.0d0 pi))) theta)))
    (plot theta r :color "C2"))
  (title "Archimedean Spiral: r = θ/(2π)")
  (savefig "examples/polar-spiral.png"))

(uiop:quit)
