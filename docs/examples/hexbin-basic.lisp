;;;; hexbin-basic.lisp — Hexagonal binning plot
;;;; Run: sbcl --load examples/hexbin-basic.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let* ((n 1000)
       (x (loop for i from 0 below n collect (+ (* (sin (* i 0.1d0)) 3.0d0) (* (cos (* i 0.037d0)) 2.0d0))))
       (y (loop for i from 0 below n collect (+ (* (cos (* i 0.1d0)) 3.0d0) (* (sin (* i 0.053d0)) 2.0d0)))))
  (let ((hb (hexbin x y :gridsize 20 :cmap :inferno)))
    (colorbar hb :label "Count")))

(xlabel "X")
(ylabel "Y")
(title "Hexbin Plot")

(savefig "examples/hexbin-basic.png")
(savefig "examples/hexbin-basic.svg")
(savefig "examples/hexbin-basic.pdf")
(format t "~&Saved to examples/hexbin-basic.{png,svg,pdf}~%")

(uiop:quit)
