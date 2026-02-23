;;;; text-watermark.lisp — Quadratic plot with large semi-transparent text overlay
;;;; Run: sbcl --load examples/text-watermark.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let* ((x '(0 1 2 3 4 5 6 7 8 9 10))
       (y (mapcar (lambda (i) (* i i)) x)))
  (figure :figsize '(7 5))
  (plot x y :color "steelblue" :linewidth 2.0)
  (title "Plot with Watermark")
  (text 5.0d0 50.0d0 "DRAFT" :fontsize 36.0 :color "gray" :alpha 0.4d0
        :ha :center :va :center :rotation 30.0))

(let ((out "examples/text-watermark.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
