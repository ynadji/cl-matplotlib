;;;; categorical-scatter.lisp — Scatter plot with string x-axis categories
;;;; Run: sbcl --load examples/categorical-scatter.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; Simple linear-congruential PRNG (seed 42)
(let ((seed 42))
  (defun my-random ()
    (setf seed (mod (+ (* seed 1103515245) 12345) (expt 2 31)))
    (/ (float seed 1.0d0) (float (expt 2 31) 1.0d0))))

(defun randn ()
  "Approximate standard normal via Box-Muller."
  (let ((u1 (max 1d-10 (my-random)))
        (u2 (my-random)))
    (* (sqrt (* -2.0d0 (log u1)))
       (cos (* 2.0d0 pi u2)))))

(figure :figsize '(8.0d0 5.0d0))

(let ((categories '("Alpha" "Beta" "Gamma" "Delta" "Epsilon")))
  (loop for i from 0
        for cat in categories
        do (let ((y (loop repeat 20 collect (+ (float i 1.0d0) (* 0.3d0 (randn)))))
                 (x (loop repeat 20 collect cat)))
             (scatter x y :alpha 0.6d0 :s 30.0d0))))

(xlabel "Category")
(ylabel "Value")
(title "Categorical Scatter Plot")

(savefig "examples/categorical-scatter.png")
(savefig "examples/categorical-scatter.svg")
(savefig "examples/categorical-scatter.pdf")
(format t "~&Saved to examples/categorical-scatter.{png,svg,pdf}~%")

(uiop:quit)
