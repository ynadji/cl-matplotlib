;;;; polar-rose.lisp — Rose curve: r = |cos(4θ)| (8-petal rose)
;;;; Run: sbcl --load examples/polar-rose.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig ax)
    (subplots 1 1 :projection :polar)
  (declare (ignore fig))
  (let* ((n 400)
         (theta (loop for i from 0 to n
                      collect (* i (/ (* 2.0d0 pi) n))))
         (r (mapcar (lambda (t_) (abs (cos (* 4.0d0 t_)))) theta)))
    (plot theta r :color "C1"))
  (title "Rose Curve: r = |cos(4θ)|")
  (savefig "examples/polar-rose.png"))

(uiop:quit)
