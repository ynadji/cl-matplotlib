;;;; custom-markers.lisp — Various marker types with line styles
;;;; Run: sbcl --load examples/custom-markers.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let ((xs (loop for i from 0 below 8
                collect (coerce i 'double-float))))

  ;; Circles with solid line
  (let ((ys (mapcar (lambda (x) (* 1.0d0 x)) xs)))
    (plot xs ys :color "steelblue" :linewidth 1.5
                :marker :circle :label "circle (o)"))

  ;; Squares with dashed line
  (let ((ys (mapcar (lambda (x) (+ (* 1.0d0 x) 2.0d0)) xs)))
    (plot xs ys :color "tomato" :linewidth 1.5
                :linestyle :dashed :marker :square :label "square (s)"))

  ;; Triangles-up with dashdot line
  (let ((ys (mapcar (lambda (x) (+ (* 1.0d0 x) 4.0d0)) xs)))
    (plot xs ys :color "seagreen" :linewidth 1.5
                :linestyle :dashdot :marker :triangle-up :label "triangle-up (^)"))

  ;; Triangles-down with dotted line
  (let ((ys (mapcar (lambda (x) (+ (* 1.0d0 x) 6.0d0)) xs)))
    (plot xs ys :color "darkorchid" :linewidth 1.5
                :linestyle :dotted :marker :triangle-down :label "triangle-down (v)")))

(xlabel "x")
(ylabel "y")
(title "Custom Markers and Line Styles")
(legend)
(grid :visible t)

(let ((out "examples/custom-markers.png"))
  (savefig out)
  (savefig "examples/custom-markers.svg")
  (savefig "examples/custom-markers.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
