;;;; threshold-lines.lisp — Line plot with threshold reference lines
;;;; Run: sbcl --load examples/threshold-lines.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8 5))

;; Deterministic sine data: y = sin(i*0.3)*2
(let* ((x (loop for i from 0 below 50 collect (coerce i 'double-float)))
       (y (loop for i from 0 below 50
                collect (* 2.0d0 (sin (* i 0.3d0)))))
       (n (length y))
       (mean-val (/ (reduce #'+ y) n))
       (std-val (sqrt (/ (reduce #'+ (mapcar (lambda (v) (expt (- v mean-val) 2)) y)) n))))

  (plot x y :color "steelblue" :linewidth 1.5 :label "Data")
  (axhline mean-val :color "red" :linestyle :dashed :linewidth 1.5 :label "Mean")
  (axhline (+ mean-val std-val) :color "orange" :linestyle :dotted :linewidth 1.5 :label "Mean+Std")
  (axhline (- mean-val std-val) :color "orange" :linestyle :dotted :linewidth 1.5 :label "Mean-Std"))

(title "Data with Threshold Lines")
(xlabel "Index")
(ylabel "Value")
(legend)

(let ((out "examples/threshold-lines.png"))
  (savefig out)
  (savefig "examples/threshold-lines.svg")
  (savefig "examples/threshold-lines.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
