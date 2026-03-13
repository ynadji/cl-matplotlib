;;;; figure-sizes.lisp — Wide aspect ratio figure
;;;; Run: sbcl --load examples/figure-sizes.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; Wide panoramic figure (16x4)
(figure :figsize '(16.0d0 4.0d0))

;; Generate a long time series with many data points
(let* ((n 200)
       (xs (loop for i from 0 below n
                 collect (coerce (* i 0.05d0) 'double-float)))
       (ys (mapcar (lambda (x)
                     (+ (sin (* 2.0d0 x))
                        (* 0.5d0 (sin (* 5.0d0 x)))
                        (* 0.3d0 (sin (* 13.0d0 x)))))
                   xs)))
  (plot xs ys :color "steelblue" :linewidth 1.0 :label "composite signal"))

(xlabel "Time (s)")
(ylabel "Amplitude")
(title "Wide Aspect Ratio — Panoramic Time Series")
(legend)
(grid :visible t)

(let ((out "examples/figure-sizes.png"))
  (savefig out)
  (savefig "examples/figure-sizes.svg")
  (savefig "examples/figure-sizes.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
