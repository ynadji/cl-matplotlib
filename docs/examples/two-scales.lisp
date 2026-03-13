;;;; two-scales.lisp — Classic twinx example with two different scales
;;;; Run: sbcl --load examples/two-scales.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let ((t-vals (loop for i from 0 below 100
                    collect (* 10.0d0 (/ (float i 1.0d0) 99.0d0))))
      (s1 (loop for i from 0 below 100
                collect (sin (* 10.0d0 (/ (float i 1.0d0) 99.0d0)))))
      (s2 (loop for i from 0 below 100
                collect (exp (/ (* 10.0d0 (/ (float i 1.0d0) 99.0d0)) 3.0d0)))))

  (plot t-vals s1 :color "blue" :linewidth 2.0)
  (xlabel "Time (s)")
  (ylabel "sin(t)")

  (let ((ax2 (twinx)))
    (mpl.containers:plot ax2 t-vals s2 :color "red" :linewidth 2.0)
    (mpl.containers:axis-set-label-text
     (mpl.containers:axes-base-yaxis ax2) "exp(t/3)")))

(title "Two Scales: sin(t) and exp(t/3)")

(let ((out "examples/two-scales.png"))
  (savefig out)
  (savefig "examples/two-scales.svg")
  (savefig "examples/two-scales.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
