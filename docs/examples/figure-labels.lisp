;;;; figure-labels.lisp — 2x2 subplots with suptitle, supxlabel, supylabel
;;;; Run: sbcl --load examples/figure-labels.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let* ((x (loop for i from 0 below 50
                collect (* 2.0d0 pi (/ i 49.0d0)))))
  (multiple-value-bind (fig axs) (subplots 2 2 :figsize '(10.0d0 8.0d0))
    (mpl.containers:plot (aref axs 0 0) x (mapcar #'sin x) :color "steelblue")
    (mpl.containers:plot (aref axs 0 1) x (mapcar #'cos x) :color "orange")
    (mpl.containers:plot (aref axs 1 0) x (mapcar (lambda (v) (sin (* 2.0d0 v))) x) :color "green")
    (mpl.containers:plot (aref axs 1 1) x (mapcar (lambda (v) (cos (* 2.0d0 v))) x) :color "red")
    (suptitle "Trigonometric Functions" :fontsize 14.0)
    (supxlabel "Angle (radians)")
    (supylabel "Amplitude")
    (mpl.containers:savefig fig "examples/figure-labels.png")
    (mpl.containers:savefig fig "examples/figure-labels.svg")
    (mpl.containers:savefig fig "examples/figure-labels.pdf")))

(uiop:quit)
