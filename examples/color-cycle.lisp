;;;; color-cycle.lisp — Demo of multiple plots using the color cycle
;;;; Run: sbcl --load examples/color-cycle.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; Plot 8 sine waves with different phase shifts
;; Each line automatically gets a different color from the default cycle
(let ((xs (loop for i from 0 below 100
                collect (coerce (* i 0.063d0) 'double-float)))  ; 0 to ~2*pi
      (colors '("steelblue" "tomato" "seagreen" "darkorchid"
                "goldenrod" "deeppink" "teal" "coral")))
  (loop for k from 0 below 8
        for phi = (coerce (* k 0.4d0) 'double-float)
        for color in colors
        do (let ((ys (mapcar (lambda (x) (sin (+ x phi))) xs))
                 (lbl (format nil "phi = ~,1f" phi)))
             (plot xs ys :color color :linewidth 1.5 :label lbl))))

(xlabel "x")
(ylabel "sin(x + phi)")
(title "Color Cycle — Phase-Shifted Sine Waves")
(legend)
(grid :visible t)

(let ((out "examples/color-cycle.png"))
  (savefig out)
  (savefig "examples/color-cycle.svg")
  (savefig "examples/color-cycle.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
