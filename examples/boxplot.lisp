;;;; boxplot.lisp — Box and whisker plot
;;;; Run: sbcl --load examples/boxplot.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; 4 groups with different spreads (fixed data, no randomness)
(let* ((group-a '(10.0d0 12.0d0 14.0d0 15.0d0 16.0d0 18.0d0 20.0d0
                  22.0d0 24.0d0 25.0d0 26.0d0 28.0d0 30.0d0))
       (group-b '(5.0d0 8.0d0 10.0d0 12.0d0 14.0d0 15.0d0 15.0d0
                  16.0d0 17.0d0 18.0d0 20.0d0 25.0d0 35.0d0))
       (group-c '(18.0d0 19.0d0 20.0d0 20.0d0 21.0d0 21.0d0 22.0d0
                  22.0d0 23.0d0 23.0d0 24.0d0 24.0d0 25.0d0))
       (group-d '(2.0d0 5.0d0 8.0d0 11.0d0 15.0d0 20.0d0 25.0d0
                  30.0d0 35.0d0 38.0d0 40.0d0 42.0d0 45.0d0)))
  (boxplot (list group-a group-b group-c group-d)
           :widths 0.5 :color "steelblue" :linewidth 1.5))

(xlabel "Group")
(ylabel "Value")
(title "Box and Whisker Plot — 4 Groups")
(grid :visible t)

(let ((out "examples/boxplot.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
