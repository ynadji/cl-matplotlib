;;;; annotations.lisp — Plot with arrow annotations
;;;; Run: sbcl --load examples/annotations.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

;; Plot sin(x) and annotate the maximum at pi/2
(let* ((xs (loop for i from 0 to 100
                 collect (* 2.0d0 pi (/ (float i 1.0d0) 100.0d0))))
       (ys (mapcar #'sin xs))
       (peak-x (/ pi 2.0d0))
       (peak-y 1.0d0))
  (plot xs ys :color "steelblue" :linewidth 2.0 :label "sin(x)")
  (annotate "Maximum"
            (list peak-x peak-y)
            :xytext (list (+ peak-x 1.0d0) (- peak-y 0.3d0))
            :fontsize 12.0
            :arrowprops '(:arrowstyle "->" :color "red")
            :color "red"))

(xlabel "x (radians)")
(ylabel "sin(x)")
(title "Annotated Plot — sin(x) with Peak")
(legend)
(grid :visible t)

(let ((out "examples/annotations.png"))
  (savefig out)
  (savefig "examples/annotations.svg")
  (savefig "examples/annotations.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
