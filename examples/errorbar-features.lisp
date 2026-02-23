;;;; errorbar-features.lisp — Different errorbar configurations
;;;; Run: sbcl --load examples/errorbar-features.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let ((x '(1 2 3 4 5))
      (y1 '(2.0d0 3.5d0 2.8d0 4.2d0 3.9d0)))

  (errorbar x y1 :yerr 0.4d0 :color "blue" :capsize 5 :linewidth 1.5)

  (let ((y2 (mapcar (lambda (v) (+ v 2.5d0)) y1)))
    (errorbar x y2 :yerr 0.5d0 :xerr 0.2d0 :color "red" :capsize 5 :linewidth 1.5)))
(grid :visible t)
(xlabel "x")
(ylabel "y")
(title "Error Bar Types")

(let ((out "examples/errorbar-features.png"))
  (savefig out)
  (savefig "examples/errorbar-features.svg")
  (savefig "examples/errorbar-features.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
