;;;; logit-demo.lisp — Logit scale for probability data
;;;; Run: sbcl --load examples/logit-demo.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((ps (loop for i from 0 below 100
                 collect (+ 0.01d0 (* i (/ 0.98d0 99)))))
       (ys (mapcar (lambda (p) (* p (- 1.0d0 p))) ps)))
  (plot ps ys :color "green" :linestyle :solid :linewidth 1.5))

(grid :visible t)
(xlabel "Probability p")
(ylabel "p(1-p)")
(title "Probability Product p(1-p)")

(let ((out "examples/logit-demo.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
