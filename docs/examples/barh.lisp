;;;; barh.lisp — Horizontal bar chart
;;;; Run: sbcl --load examples/barh.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

;; Programming language popularity scores
(let ((positions '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0))
      (scores    '(45.0d0 38.0d0 30.0d0 25.0d0 18.0d0)))
  (barh positions scores :height 0.6 :color "steelblue" :edgecolor "black" :linewidth 0.8))

(xlabel "Popularity Score")
(ylabel "Language")
(title "Programming Language Popularity (Horizontal)")
(grid :visible t)

(let ((out "examples/barh.png"))
  (savefig out)
  (savefig "examples/barh.svg")
  (savefig "examples/barh.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
