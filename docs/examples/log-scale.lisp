;;;; log-scale.lisp — Logarithmic scale demo with exponential data
;;;; Run: sbcl --load examples/log-scale.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; y = exp(x) for x = 0 to 5
(let* ((xs (loop for i from 0 below 51
                 collect (coerce (* i 0.1d0) 'double-float)))
       (ys (mapcar (lambda (x) (exp x)) xs)))
  (plot xs ys :color "steelblue" :linewidth 2.0 :label "y = exp(x)"))

;; Set y-axis to logarithmic scale
(mpl.containers:axes-set-yscale (gca) :log)

(xlabel "x")
(ylabel "exp(x)")
(title "Logarithmic Scale Demo")
(legend)
(grid :visible t)

(let ((out "examples/log-scale.png"))
  (savefig out)
  (savefig "examples/log-scale.svg")
  (savefig "examples/log-scale.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
