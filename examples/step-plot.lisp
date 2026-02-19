;;;; step-plot.lisp — Step plot showing discrete signal
;;;; Run: sbcl --load examples/step-plot.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 5.0d0))

;; Digital signal: alternating 0/1 with varying durations
(let* ((xs '(0.0d0 1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0 7.0d0
             8.0d0 9.0d0 10.0d0 11.0d0 12.0d0 13.0d0 14.0d0 15.0d0))
       (ys '(0.0d0 1.0d0 1.0d0 0.0d0 0.0d0 1.0d0 0.0d0 1.0d0
             1.0d0 1.0d0 0.0d0 0.0d0 1.0d0 0.0d0 1.0d0 1.0d0)))
  (step-plot xs ys :where :post :color "steelblue" :linewidth 2.0
             :label "Digital Signal (post)"))

(xlabel "Time (μs)")
(ylabel "Amplitude")
(title "Step Plot — Digital Signal")
(legend)
(grid :visible t)

(let ((out "examples/step-plot.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
