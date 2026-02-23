;;;; bar-labels.lisp — Bar chart with value labels above bars
;;;; Run: sbcl --load examples/bar-labels.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((values '(23 45 12 67 34))
      (x '(0 1 2 3 4))
      (categories '("A" "B" "C" "D" "E")))
  (figure :figsize '(7 5))
  (bar x values :color "steelblue")
  (loop for xi in x for val in values do
    (text xi (+ val 1) (format nil "~D" val) :ha :center :va :bottom :fontsize 11))
  (set-xticks x :labels categories)
  (ylim 0 80)
  (title "Bar Chart with Labels"))

(let ((out "examples/bar-labels.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
