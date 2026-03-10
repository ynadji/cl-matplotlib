;;;; boxplot-styles.lisp — Boxplot with multiple groups
;;;; Run: ros run -- --noinform --load examples/boxplot-styles.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let ((data (list '(2.1d0 3.4d0 1.8d0 2.9d0 3.2d0 2.5d0 1.6d0 3.8d0 2.7d0 3.0d0)
                  '(4.2d0 5.1d0 3.8d0 4.9d0 5.3d0 4.0d0 3.5d0 5.8d0 4.6d0 5.2d0)
                  '(1.1d0 2.0d0 1.5d0 1.8d0 2.3d0 1.4d0 0.9d0 2.5d0 1.7d0 2.1d0))))
  (boxplot data :widths 0.5 :color "steelblue" :linewidth 1.5))

(ylabel "Value")
(title "Boxplot with Multiple Groups")
(grid :visible t :axis :y)

(let ((out "examples/boxplot-styles.png"))
  (savefig out)
  (savefig "examples/boxplot-styles.svg")
  (savefig "examples/boxplot-styles.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
