;;;; text-alignment.lisp — Text horizontal and vertical alignment demo
;;;; Run: sbcl --load examples/text-alignment.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((x '(1 2 3 4 5 6))
      (y '(3 5 2 6 4 7)))
  (figure :figsize '(7 5))
  (plot x y :color "steelblue" :linewidth 2.0 :marker :circle)
  (text 1 3 "left" :ha :left :va :bottom :fontsize 12 :color "tomato")
  (text 3 2 "center" :ha :center :va :top :fontsize 12 :color "tomato")
  (text 6 7 "right" :ha :right :va :bottom :fontsize 12 :color "tomato")
  (title "Text Alignment Demo")
  (xlim 0.5d0 6.5d0)
  (ylim 0 8))

(let ((out "examples/text-alignment.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
