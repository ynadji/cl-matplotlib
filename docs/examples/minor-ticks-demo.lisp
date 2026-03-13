;;;; minor-ticks-demo.lisp — Sine wave with minor tick marks and grid
;;;; Run: sbcl --load examples/minor-ticks-demo.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((n 100)
       (x (loop for i below n collect (* (float i 1.0d0) (/ 10.0d0 (1- n)))))
       (y (mapcar #'sin x)))
  (plot x y :color "blue" :linewidth 1.5d0))

(minorticks-on)
(grid :visible t :which :major :alpha 0.5d0)
(grid :visible t :which :minor :alpha 0.2d0 :linestyle ":")

(xlabel "x")
(ylabel "sin(x)")
(title "Minor Ticks Demo")

(savefig "examples/minor-ticks-demo.png")
(savefig "examples/minor-ticks-demo.svg")
(savefig "examples/minor-ticks-demo.pdf")
(format t "~&Saved to examples/minor-ticks-demo.{png,svg,pdf}~%")

(uiop:quit)
