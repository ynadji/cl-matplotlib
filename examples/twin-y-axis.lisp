;;;; twin-y-axis.lisp — True dual y-axis plot using twinx
;;;; Run: sbcl --load examples/twin-y-axis.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

(let ((months (loop for i from 1.0d0 to 12.0d0 collect i))
      (temps '(2.0d0 4.0d0 8.0d0 13.0d0 18.0d0 22.0d0
               25.0d0 24.0d0 20.0d0 14.0d0 8.0d0 3.0d0))
      (precip '(50.0d0 40.0d0 45.0d0 55.0d0 65.0d0 50.0d0
                35.0d0 40.0d0 55.0d0 70.0d0 65.0d0 55.0d0)))

  (plot months temps :color "blue" :linewidth 2.0)
  (xlabel "Month")
  (ylabel "Temperature (C)")

  (let ((ax2 (twinx)))
    (mpl.containers:plot ax2 months precip :color "red" :linewidth 2.0)
    (mpl.containers:axis-set-label-text
     (mpl.containers:axes-base-yaxis ax2) "Precipitation (mm)")))

(title "Monthly Temperature and Precipitation")

(let ((out "examples/twin-y-axis.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
