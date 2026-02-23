;;;; violin-comparison.lisp — Violin plot with four distributions
;;;; Run: sbcl --load examples/violin-comparison.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; 4 groups with different distributions (fixed data, no randomness)
(let* ((data-a '(10.0d0 11.0d0 12.0d0 13.0d0 14.0d0 15.0d0 15.0d0
                 16.0d0 17.0d0 18.0d0 19.0d0 20.0d0 21.0d0))
       (data-b '(5.0d0 7.0d0 9.0d0 10.0d0 11.0d0 13.0d0 15.0d0
                 17.0d0 19.0d0 21.0d0 23.0d0 25.0d0 27.0d0))
       (data-c '(12.0d0 14.0d0 15.0d0 16.0d0 16.0d0 17.0d0 17.0d0
                 18.0d0 18.0d0 18.0d0 19.0d0 20.0d0 22.0d0))
       (data-d '(3.0d0 5.0d0 8.0d0 12.0d0 15.0d0 18.0d0 20.0d0
                 22.0d0 25.0d0 28.0d0 32.0d0 38.0d0 45.0d0)))
  (violinplot (list data-a data-b data-c data-d)))

(xlabel "Group")
(ylabel "Value")
(title "Violin Plot — Four Distributions")
(grid :visible t)

(let ((out "examples/violin-comparison.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
