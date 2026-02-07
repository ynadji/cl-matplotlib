;;;; bar-chart.lisp — Bar chart
;;;; Run: sbcl --load examples/bar-chart.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let ((langs   '(1    2    3    4    5    6))
      (scores  '(45.0 38.0 30.0 25.0 18.0 12.0))
      (colors  '("steelblue" "tomato" "seagreen" "goldenrod" "mediumpurple" "coral")))
  (bar langs scores :width 0.6 :color colors :edgecolor "black" :linewidth 0.8))

(xlabel "Language")
(ylabel "Popularity")
(title "Programming Language Popularity")
(grid :visible t)

(let ((out "examples/bar-chart.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
