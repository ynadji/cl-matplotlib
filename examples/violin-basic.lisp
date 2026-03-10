;;;; violin-basic.lisp — Violin plot comparison
;;;; Run: sbcl --load examples/violin-basic.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; 3 groups with different distributions (fixed data, no randomness)
(let* ((group-a '(3.0d0 5.0d0 7.0d0 8.0d0 9.0d0 10.0d0 11.0d0 12.0d0
                  13.0d0 14.0d0 15.0d0 16.0d0 17.0d0 18.0d0 20.0d0))
       (group-b '(1.0d0 2.0d0 2.0d0 3.0d0 3.0d0 4.0d0 4.0d0 5.0d0
                  6.0d0 15.0d0 16.0d0 17.0d0 17.0d0 18.0d0 19.0d0))
       (group-c '(8.0d0 9.0d0 10.0d0 10.0d0 11.0d0 11.0d0 12.0d0 12.0d0
                  12.0d0 13.0d0 13.0d0 14.0d0 14.0d0 15.0d0 16.0d0)))
  (violinplot (list group-a group-b group-c)))

(xlabel "Group")
(ylabel "Value")
(title "Violin Plot — Distribution Comparison")
(grid :visible t)

(let ((out "examples/violin-basic.png"))
  (savefig out)
  (savefig "examples/violin-basic.svg")
  (savefig "examples/violin-basic.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
