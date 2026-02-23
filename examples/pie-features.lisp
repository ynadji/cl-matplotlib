;;;; pie-features.lisp — Pie chart with labels, autopct, and colors
;;;; Run: sbcl --load examples/pie-features.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(pie '(35.0d0 25.0d0 20.0d0 15.0d0 5.0d0)
     :labels '("Python" "Java" "C++" "JavaScript" "Others")
     :autopct "%1.1f%%"
     :colors '("steelblue" "tomato" "seagreen" "goldenrod" "mediumpurple")
     :startangle 90)

(title "Programming Languages")

(let ((out "examples/pie-features.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
