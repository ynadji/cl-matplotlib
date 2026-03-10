;;;; stacked-bar.lisp — Stacked bar chart using bottom parameter
;;;; Run: sbcl --load examples/stacked-bar.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

(let* ((categories '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0))
       (values-a '(20.0d0 35.0d0 30.0d0 25.0d0 15.0d0))
       (values-b '(15.0d0 20.0d0 25.0d0 30.0d0 35.0d0))
       (values-c '(10.0d0 15.0d0 20.0d0 25.0d0 30.0d0))
       (bottom-c (mapcar #'+ values-a values-b)))
  (bar categories values-a :width 0.6 :label "Group A" :color "steelblue"
       :edgecolor "black" :linewidth 0.5)
  (bar categories values-b :width 0.6 :bottom values-a :label "Group B" :color "tomato"
       :edgecolor "black" :linewidth 0.5)
  (bar categories values-c :width 0.6 :bottom bottom-c :label "Group C" :color "seagreen"
       :edgecolor "black" :linewidth 0.5))

(xlabel "Category")
(ylabel "Value")
(title "Stacked Bar Chart")
(legend)
(grid :visible t)

(let ((out "examples/stacked-bar.png"))
  (savefig out)
  (savefig "examples/stacked-bar.svg")
  (savefig "examples/stacked-bar.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
