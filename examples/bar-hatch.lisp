;;;; bar-hatch.lisp — Bar chart with hatch patterns
;;;; Run: sbcl --load examples/bar-hatch.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

;; Draw each bar individually with its own hatch pattern
(let ((categories '("A" "B" "C" "D"))
      (values '(4.2d0 6.1d0 3.8d0 5.5d0))
      (hatches '("/" "\\" "x" "o"))
      (colors '("#4C72B0" "#DD8452" "#55A868" "#C44E52")))
  (loop for cat in categories
        for val in values
        for hatch in hatches
        for color in colors
        do (let ((rects (bar (list cat) (list val)
                            :color color :edgecolor "black"
                            :linewidth 0.8d0)))
             (setf (cl-matplotlib.rendering:patch-hatch (first rects)) hatch))))

(xlabel "Category")
(ylabel "Value")
(title "Bar Chart with Hatch Patterns")

(savefig "examples/bar-hatch.png")
(savefig "examples/bar-hatch.svg")
(savefig "examples/bar-hatch.pdf")
(format t "~&Saved to examples/bar-hatch.{png,svg,pdf}~%")

(uiop:quit)
