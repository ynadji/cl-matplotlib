;;;; hlines-vlines.lisp — Horizontal and vertical lines demo
;;;; Run: sbcl --load examples/hlines-vlines.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8 5))

(plot '(0 1 2 3 4 5 6 7 8 9 10)
     '(0.5 1.8 2.5 1.2 3.0 2.2 3.5 1.5 2.8 3.8 2.0)
     :color "steelblue" :linewidth 1.5 :label "Data")

(hlines '(1.0d0 2.0d0 3.0d0) 0.0d0 10.0d0
        :colors '("red" "green" "blue") :linewidth 1.5 :linestyles :solid)

(vlines '(3.0d0 6.0d0 9.0d0) 0.0d0 4.0d0
        :colors '("orange" "purple" "brown") :linewidth 1.5 :linestyles :solid)

(xlim 0.0d0 10.0d0)
(ylim 0.0d0 4.0d0)
(title "Horizontal and Vertical Lines")
(xlabel "X")
(ylabel "Y")

(let ((out "examples/hlines-vlines.png"))
  (savefig out)
  (savefig "examples/hlines-vlines.svg")
  (savefig "examples/hlines-vlines.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
