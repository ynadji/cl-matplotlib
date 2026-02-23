;;;; polar-styled.lisp — Styled polar: cardioid with custom color/linewidth
;;;; Run: sbcl --load examples/polar-styled.lisp

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
    (plot theta r :color "darkred" :linewidth 2.5))
  (title "Styled Polar Plot")
  (savefig "examples/polar-styled.png"))

(uiop:quit)
