;;;; horizontal-bar-stacked.lisp — Stacked horizontal bar chart
;;;; Run: ros run -- --noinform --load examples/horizontal-bar-stacked.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

(let* ((y        '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0))
       (values-a '(20.0d0 35.0d0 15.0d0 30.0d0 25.0d0))
       (values-b '(15.0d0 20.0d0 30.0d0 10.0d0 25.0d0))
       (values-c '(10.0d0 15.0d0 20.0d0 25.0d0 15.0d0))
       (left-c   (mapcar #'+ values-a values-b)))
  (barh y values-a :height 0.6 :label "Group A" :color "steelblue"
        :edgecolor "black" :linewidth 0.5)
  (barh y values-b :height 0.6 :left values-a :label "Group B" :color "tomato"
        :edgecolor "black" :linewidth 0.5)
  (barh y values-c :height 0.6 :left left-c :label "Group C" :color "seagreen"
        :edgecolor "black" :linewidth 0.5))

(ylabel "Category")
(xlabel "Value")
(title "Stacked Horizontal Bar Chart")
(legend)
(grid :visible t)

(let ((out "examples/horizontal-bar-stacked.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
