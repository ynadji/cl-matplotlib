;;;; reference-grid.lisp — Scatter plot with horizontal reference lines
;;;; Run: sbcl --load examples/reference-grid.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(7 5))

;; Scatter data
(scatter '(1 2 3 4 5 6 7 8 9 10)
         '(3.2 5.1 2.8 6.4 4.9 7.2 3.5 5.8 4.1 6.7)
         :color "steelblue" :s 60.0 :zorder 3)

;; Set limits before axhline so span computation is correct
(xlim 0.5d0 10.5d0)
(ylim 1.5d0 8.5d0)

;; Reference lines at key values
(axhline 2.5d0 :color "green" :linewidth 1.0 :linestyle :dashed :alpha 0.7)
(axhline 5.0d0 :color "orange" :linewidth 1.0 :linestyle :dashed :alpha 0.7)
(axhline 7.5d0 :color "red" :linewidth 1.0 :linestyle :dashed :alpha 0.7)

(title "Scatter with Reference Lines")
(xlabel "X")
(ylabel "Y")

(let ((out "examples/reference-grid.png"))
  (savefig out)
  (savefig "examples/reference-grid.svg")
  (savefig "examples/reference-grid.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
