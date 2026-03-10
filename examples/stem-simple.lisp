;;;; stem-simple.lisp — Simple stem plot
;;;; Run: sbcl --load examples/stem-simple.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(stem '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0 7.0d0 8.0d0 9.0d0 10.0d0)
      '(1.5d0 -0.5d0 2.3d0 -1.2d0 3.0d0 -2.1d0 1.8d0 -0.8d0 2.5d0 -1.5d0))

(xlabel "x")
(ylabel "y")
(title "Stem Plot")
(grid :visible t)

(let ((out "examples/stem-simple.png"))
  (savefig out)
  (savefig "examples/stem-simple.svg")
  (savefig "examples/stem-simple.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
