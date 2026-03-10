;;;; quiver-gradient.lisp — Quiver plot: gradient field of f(x,y) = x² + y²
;;;; Run: sbcl --load examples/quiver-gradient.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((n 6)
       (step (/ 6.0d0 (1- n)))
       (x (loop for i from 0 below n collect (+ -3.0d0 (* i step))))
       (y (loop for j from 0 below n collect (+ -3.0d0 (* j step))))
       (u (loop for j from 0 below n collect
                (loop for i from 0 below n collect (* 2.0d0 (nth i x)))))
       (v (loop for j from 0 below n collect
                (loop for i from 0 below n collect (* 2.0d0 (nth j y))))))
  (quiver x y u v))

(xlabel "X")
(ylabel "Y")
(title "Quiver Plot — Gradient Field")
(grid :visible t)

(let ((out "examples/quiver-gradient.png"))
  (savefig out)
  (savefig "examples/quiver-gradient.svg")
  (savefig "examples/quiver-gradient.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
