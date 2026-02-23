;;;; bar-colors.lisp — Bar chart with per-bar colors
;;;; Run: ros run -- --noinform --load examples/bar-colors.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let ((x       '(1 2 3 4 5 6))
      (heights '(45.0d0 30.0d0 55.0d0 20.0d0 40.0d0 35.0d0))
      (colors  '("steelblue" "tomato" "seagreen" "goldenrod" "mediumpurple" "coral")))
  (bar x heights :color colors :edgecolor "black" :linewidth 0.8 :width 0.6))

(xlabel "Category")
(ylabel "Value")
(title "Bar Chart with Individual Colors")
(grid :visible t :axis :y)

(let ((out "examples/bar-colors.png"))
  (savefig out)
  (savefig "examples/bar-colors.svg")
  (savefig "examples/bar-colors.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
