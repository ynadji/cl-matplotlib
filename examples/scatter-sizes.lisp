;;;; scatter-sizes.lisp — Scatter with varying point sizes and colors
;;;; Run: sbcl --load examples/scatter-sizes.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let ((xs '(1.0d0 2.5d0 3.7d0 5.1d0 6.4d0 7.2d0 8.9d0 3.3d0 4.8d0 6.1d0
            1.5d0 2.0d0 4.5d0 5.8d0 7.7d0 8.3d0 2.7d0 6.8d0 9.1d0 0.8d0
            3.1d0 4.2d0 5.5d0 7.0d0 8.6d0 1.2d0 2.9d0 5.2d0 6.7d0 9.4d0))
      (ys '(2.1d0 3.4d0 1.8d0 4.5d0 2.9d0 6.1d0 3.8d0 5.2d0 1.5d0 4.0d0
            6.7d0 2.3d0 5.6d0 3.1d0 4.9d0 7.3d0 1.9d0 5.8d0 2.6d0 7.8d0
            3.7d0 4.3d0 6.4d0 2.8d0 5.1d0 8.2d0 3.5d0 7.6d0 1.4d0 4.7d0))
      (sizes '(50 100 200 80 150 30 250 120 60 180
               90 220 45 160 75 300 110 40 190 85
               130 70 240 55 170 95 280 65 145 210))
      (colors '("#1f77b4" "#ff7f0e" "#2ca02c" "#d62728" "#9467bd"
               "#8c564b" "#e377c2" "#7f7f7f" "#bcbd22" "#17becf"
               "#1f77b4" "#ff7f0e" "#2ca02c" "#d62728" "#9467bd"
               "#8c564b" "#e377c2" "#7f7f7f" "#bcbd22" "#17becf"
               "#1f77b4" "#ff7f0e" "#2ca02c" "#d62728" "#9467bd"
               "#8c564b" "#e377c2" "#7f7f7f" "#bcbd22" "#17becf")))
  (scatter xs ys :s sizes :c colors :alpha 0.7))

(xlabel "X")
(ylabel "Y")
(title "Scatter with Varying Sizes")

(let ((out "examples/scatter-sizes.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
