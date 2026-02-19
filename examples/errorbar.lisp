;;;; errorbar.lisp — Error bar plot
;;;; Run: sbcl --load examples/errorbar.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; y = x^2 with y error bars of ±x and x error bars of ±0.2
(let* ((xs (loop for x from 0.5d0 to 5.0d0 by 0.5d0
                 collect (coerce x 'double-float)))
       (ys (mapcar (lambda (x) (* x x)) xs))
       (yerrs (mapcar (lambda (x) x) xs))   ; ±x
       (xerrs (mapcar (lambda (x) (declare (ignore x)) 0.2d0) xs)))  ; ±0.2
  (errorbar xs ys :yerr yerrs :xerr xerrs
            :color "steelblue" :ecolor "tomato"
            :capsize 4.0 :linewidth 1.5
            :marker :circle :label "y = x² ± errors"))

(xlabel "x")
(ylabel "y")
(title "Error Bar Plot")
(legend)
(grid :visible t)

(let ((out "examples/errorbar.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
