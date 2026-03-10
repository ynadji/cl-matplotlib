;;;; legend-styles.lisp — Multiple legend styles and positions
;;;; Run: sbcl --load examples/legend-styles.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

;; Three different functions with different line styles
(let ((xs (loop for i from 0 to 50
                collect (coerce i 'double-float))))
  ;; Linear
  (plot xs (mapcar (lambda (x) (* 2.0d0 x)) xs)
        :color "steelblue" :linewidth 2.0
        :linestyle :solid :label "Linear: y = 2x")
  ;; Quadratic
  (plot xs (mapcar (lambda (x) (* 0.04d0 x x)) xs)
        :color "tomato" :linewidth 2.0
        :linestyle :dashed :label "Quadratic: y = 0.04x^2")
  ;; Square root
  (plot xs (mapcar (lambda (x) (* 10.0d0 (sqrt x))) xs)
        :color "forestgreen" :linewidth 2.0
        :linestyle :dotted :label "Root: y = 10*sqrt(x)"))

(legend :loc :upper-left :fontsize 11.0 :frameon t
        :title-text "Function Comparison"
        :facecolor "#f0f0f0" :edgecolor "gray")

(xlabel "x")
(ylabel "y")
(title "Legend Styles — Multiple Functions")
(grid :visible t)

(let ((out "examples/legend-styles.png"))
  (savefig out)
  (savefig "examples/legend-styles.svg")
  (savefig "examples/legend-styles.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
