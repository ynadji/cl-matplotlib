;;;; span-regions.lisp — Plot with axhspan + axvspan highlighted regions
;;;; Run: sbcl --load examples/span-regions.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(10.0d0 6.0d0))

(let ((x (loop for i from 0 below 200
               collect (* 20.0d0 (/ (float i 1.0d0) 199.0d0))))
      (y (loop for i from 0 below 200
               collect (sin (* 20.0d0 (/ (float i 1.0d0) 199.0d0))))))

  (plot x y :color "steelblue" :linewidth 2.0)

  (axhspan -0.5d0 0.5d0 :alpha 0.3d0 :color "yellow")
  (axvspan 5.0d0 10.0d0 :alpha 0.2d0 :color "blue"))

(xlabel "Time")
(ylabel "Amplitude")
(title "Sine Wave with Highlighted Regions")

(let ((out "examples/span-regions.png"))
  (savefig out)
  (savefig "examples/span-regions.svg")
  (savefig "examples/span-regions.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
