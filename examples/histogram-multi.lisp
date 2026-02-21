;;;; histogram-multi.lisp — Multiple overlapping histograms
;;;; Run: ros run -- --noinform --load examples/histogram-multi.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

(let* ((centers  '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0 7.0d0))
       (width    0.25d0)
       (counts-a '(3.0d0 5.0d0 4.0d0 6.0d0 3.0d0 2.0d0 1.0d0))
       (counts-b '(1.0d0 2.0d0 4.0d0 5.0d0 6.0d0 3.0d0 2.0d0))
       (counts-c '(0.0d0 1.0d0 2.0d0 3.0d0 5.0d0 5.0d0 4.0d0))
       (x-a (mapcar (lambda (c) (- c width)) centers))
       (x-c (mapcar (lambda (c) (+ c width)) centers)))
  (bar x-a counts-a :width width :color "steelblue" :label "Group A"
       :edgecolor "black" :linewidth 0.5)
  (bar centers counts-b :width width :color "tomato" :label "Group B"
       :edgecolor "black" :linewidth 0.5)
  (bar x-c counts-c :width width :color "seagreen" :label "Group C"
       :edgecolor "black" :linewidth 0.5))

(legend)
(xlabel "Bin")
(ylabel "Count")
(title "Multiple Histogram Groups")
(grid :visible t :axis :y)

(let ((out "examples/histogram-multi.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
