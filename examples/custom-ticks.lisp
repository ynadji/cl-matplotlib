;;;; custom-ticks.lisp — Sine wave with custom tick labels at multiples of pi
;;;; Run: sbcl --load examples/custom-ticks.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let* ((x (loop for i from 0 to 199
                collect (* 2.0d0 pi (/ i 199.0d0))))
       (y (mapcar #'sin x))
       (tick-pos (list 0.0d0 (* 0.5d0 pi) pi (* 1.5d0 pi) (* 2.0d0 pi)))
       (tick-labels '("0" "pi/2" "pi" "3pi/2" "2pi")))
  (figure :figsize '(8.0d0 5.0d0))
  (plot x y :color "steelblue" :linewidth 2.0)
  (set-xticks tick-pos :labels tick-labels)
  (title "Sine Wave with Custom Tick Labels")
  (xlabel "Angle")
  (ylabel "sin(x)"))

(let ((out "examples/custom-ticks.png"))
  (savefig out)
  (savefig "examples/custom-ticks.svg")
  (savefig "examples/custom-ticks.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
