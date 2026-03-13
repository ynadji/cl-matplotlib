;;;; symlog-demo.lisp — Symmetric log scale plot
;;;; Run: sbcl --load examples/symlog-demo.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((xs (loop for i from 0 below 200
                 collect (+ -10.0d0 (* i 0.1d0))))
       (ys (mapcar (lambda (x)
                     (/ (- (exp x) (exp (- x))) 2.0d0))
                   xs)))
  (plot xs ys :color "blue" :linestyle :solid :linewidth 1.5))

(grid :visible t)
(xlabel "x")
(ylabel "sinh(x)")
(title "sinh(x) — Hyperbolic Sine")

(let ((out "examples/symlog-demo.png"))
  (savefig out)
  (savefig "examples/symlog-demo.svg")
  (savefig "examples/symlog-demo.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
