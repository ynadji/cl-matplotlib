;;;; quiver-colored.lisp — Quiver plot: rotational field
;;;; Run: sbcl --load examples/quiver-colored.lisp

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
                (loop for i from 0 below n collect (- (nth j y)))))
       (v (loop for j from 0 below n collect
                (loop for i from 0 below n collect (nth i x)))))
  (quiver x y u v))

(xlabel "X")
(ylabel "Y")
(title "Quiver Plot — Rotational Field")
(grid :visible t)

(let ((out "examples/quiver-colored.png"))
  (savefig out)
  (savefig "examples/quiver-colored.svg")
  (savefig "examples/quiver-colored.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
