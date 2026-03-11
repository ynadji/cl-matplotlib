;;;; fill-between-where.lisp — Conditional fill between two curves
;;;; Run: sbcl --load examples/fill-between-where.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((n 200)
       (xs (loop for i from 0 below n
                 collect (* i (/ (* 4.0d0 pi) (1- n)))))
       (y1 (mapcar #'sin xs))
       (y2 (mapcar (lambda (x) (* 0.5d0 (sin (* 2.0d0 x)))) xs)))
  (plot xs y1 :color "blue" :linewidth 1.5 :label "sin(x)")
  (plot xs y2 :color "red" :linewidth 1.5 :label "0.5·sin(2x)")
  (fill-between xs y1 y2
                :where (mapcar (lambda (a b) (> a b)) y1 y2)
                :alpha 0.4 :color "green" :label "y1 > y2")
  (fill-between xs y1 y2
                :where (mapcar (lambda (a b) (<= a b)) y1 y2)
                :alpha 0.4 :color "red" :label "y1 <= y2"))

(xlabel "x")
(ylabel "y")
(title "fill_between with where condition")
(legend)

(let ((out "examples/fill-between-where.png"))
  (savefig out)
  (savefig "examples/fill-between-where.svg")
  (savefig "examples/fill-between-where.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
