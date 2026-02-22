;;;; violin-styled.lisp — Horizontal violin plot
;;;; Run: sbcl --load examples/violin-styled.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; 3 groups of scores (fixed data, no randomness)
(let* ((scores-a '(60.0d0 65.0d0 70.0d0 72.0d0 74.0d0 75.0d0 76.0d0
                   78.0d0 80.0d0 82.0d0 85.0d0 88.0d0 90.0d0))
       (scores-b '(55.0d0 60.0d0 63.0d0 65.0d0 68.0d0 70.0d0 72.0d0
                   73.0d0 75.0d0 78.0d0 80.0d0 85.0d0 92.0d0))
       (scores-c '(70.0d0 72.0d0 74.0d0 75.0d0 76.0d0 77.0d0 78.0d0
                   79.0d0 80.0d0 81.0d0 82.0d0 83.0d0 85.0d0)))
  (violinplot (list scores-a scores-b scores-c)
              :vert nil :widths 0.7))

(xlabel "Score")
(ylabel "Group")
(title "Violin Plot — Horizontal Orientation")
(grid :visible t)

(let ((out "examples/violin-styled.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
