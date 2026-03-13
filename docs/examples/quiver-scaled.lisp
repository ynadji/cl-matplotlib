;;;; quiver-scaled.lisp — Quiver plot: wind-like patterns
;;;; Run: sbcl --load examples/quiver-scaled.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((n 7)
       (step (/ (* 2.0d0 pi) (1- n)))
       (x (loop for i from 0 below n collect (* i step)))
       (y (loop for j from 0 below n collect (* j step)))
       (u (loop for j from 0 below n collect
                (loop for i from 0 below n collect (cos (nth j y)))))
       (v (loop for j from 0 below n collect
                (loop for i from 0 below n collect (sin (nth i x))))))
  (quiver x y u v))

(xlabel "X")
(ylabel "Y")
(title "Quiver Plot — Wind Patterns")
(grid :visible t)

(let ((out "examples/quiver-scaled.png"))
  (savefig out)
  (savefig "examples/quiver-scaled.svg")
  (savefig "examples/quiver-scaled.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
