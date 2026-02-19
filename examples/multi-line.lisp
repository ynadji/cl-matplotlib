;;;; multi-line.lisp — Multiple lines with different styles
;;;; Run: sbcl --load examples/multi-line.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

;; Four trig lines with different styles and colors
(let ((xs (loop for i from 0 to 100
                collect (* 0.1d0 (coerce i 'double-float)))))
  ;; Solid
  (plot xs (mapcar (lambda (x) (sin x)) xs)
        :color "steelblue" :linewidth 2.0
        :linestyle :solid :label "sin(x)")
  ;; Dashed
  (plot xs (mapcar (lambda (x) (cos x)) xs)
        :color "tomato" :linewidth 2.0
        :linestyle :dashed :label "cos(x)")
  ;; Dotted
  (plot xs (mapcar (lambda (x) (* 0.5d0 (sin (* 2.0d0 x)))) xs)
        :color "forestgreen" :linewidth 2.5
        :linestyle :dotted :label "0.5*sin(2x)")
  ;; Dashdot
  (plot xs (mapcar (lambda (x) (* 0.5d0 (cos (* 2.0d0 x)))) xs)
        :color "darkorange" :linewidth 2.0
        :linestyle :dashdot :label "0.5*cos(2x)"))

(legend :loc :upper-right :fontsize 10.0)

(xlabel "x")
(ylabel "y")
(title "Multiple Lines — Different Styles")
(grid :visible t)

(let ((out "examples/multi-line.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
