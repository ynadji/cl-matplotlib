;;;; quiver-basic.lisp — Quiver plot: uniform flow
;;;; Run: sbcl --load examples/quiver-basic.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((x (loop for i from 0 below 5 collect (float i 1.0d0)))
       (y (loop for i from 0 below 5 collect (float i 1.0d0)))
       (u (loop for j from 0 below 5 collect
                (loop for i from 0 below 5 collect 1.0d0)))
       (v (loop for j from 0 below 5 collect
                (loop for i from 0 below 5 collect 0.0d0))))
  (quiver x y u v))

(xlabel "X")
(ylabel "Y")
(title "Quiver Plot — Uniform Flow")
(grid :visible t)

(let ((out "examples/quiver-basic.png"))
  (savefig out)
  (savefig "examples/quiver-basic.svg")
  (savefig "examples/quiver-basic.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
