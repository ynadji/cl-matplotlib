;;;; histogram-stacked.lisp — Stacked histogram with 3 datasets
;;;; Run: sbcl --load examples/histogram-stacked.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

;; Deterministic data: same math as reference_scripts/histogram-stacked.py
(let* ((n 200)
       (d1 (loop for i from 0 below n collect (+ (* (sin (* i 0.05d0)) 20.0d0) 50.0d0)))
       (d2 (loop for i from 0 below n collect (+ (* (cos (* i 0.07d0)) 15.0d0) 45.0d0)))
       (d3 (loop for i from 0 below n collect (+ (* (sin (+ (* i 0.03d0) 1.0d0)) 25.0d0) 55.0d0)))
       ;; Explicit bin edges so both Python and CL share identical bins
       (bin-edges (loop for i from 0 to 15 collect (+ 25.0d0 (* i 4.0d0))))
       (bin-centers (loop for i from 0 below 15
                          collect (/ (+ (nth i bin-edges) (nth (1+ i) bin-edges)) 2.0d0)))
       (bin-width 4.0d0))
  (flet ((count-bins (data)
           (loop for b from 0 below 15
                 for lo = (nth b bin-edges)
                 for hi = (nth (1+ b) bin-edges)
                 collect (float (count-if (lambda (x) (and (>= x lo) (< x hi))) data) 1.0d0))))
    (let* ((c1 (count-bins d1))
           (c2 (count-bins d2))
           (c3 (count-bins d3))
           (bottom1 c1)
           (bottom2 (mapcar #'+ c1 c2)))
      (bar bin-centers c1 :width bin-width :color "#4C72B0" :label "Group A"
           :edgecolor "white" :linewidth 0.5d0)
      (bar bin-centers c2 :width bin-width :bottom bottom1 :color "#DD8452"
           :label "Group B" :edgecolor "white" :linewidth 0.5d0)
      (bar bin-centers c3 :width bin-width :bottom bottom2 :color "#55A868"
           :label "Group C" :edgecolor "white" :linewidth 0.5d0))))

(xlabel "Value")
(ylabel "Count")
(title "Stacked Histogram")
(legend)

(savefig "examples/histogram-stacked.png")
(savefig "examples/histogram-stacked.svg")
(savefig "examples/histogram-stacked.pdf")
(format t "~&Saved to examples/histogram-stacked.{png,svg,pdf}~%")

(uiop:quit)
