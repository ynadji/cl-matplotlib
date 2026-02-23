;;;; stem-plot.lisp — Stem plot of sin(x)
;;;; Run: sbcl --load examples/stem-plot.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 5.0d0))

;; Stem plot of y = sin(x) for x = 0, 0.5, 1.0, ..., 4*pi
(let* ((xs (loop for x from 0.0d0 to (* 4.0d0 pi) by 0.5d0
                 collect x))
       (ys (mapcar (lambda (x) (sin x)) xs)))
  (stem xs ys :linefmt "steelblue" :markerfmt "steelblue"
        :basefmt "gray" :label "sin(x)"))

(xlabel "x (radians)")
(ylabel "sin(x)")
(title "Stem Plot — sin(x)")
(legend)
(grid :visible t)

(let ((out "examples/stem-plot.png"))
  (savefig out)
  (savefig "examples/stem-plot.svg")
  (savefig "examples/stem-plot.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
