;;;; scatter.lisp — Scatter plot with random data
;;;; Run: sbcl --load examples/scatter.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; Simple linear-congruential PRNG (no external deps)
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

(figure :figsize '(8.0d0 6.0d0))

(let* ((n 200)
       (xs (loop repeat n collect (randn)))
       (ys (loop for x in xs collect (+ (* 0.7d0 x) (* 0.5d0 (randn))))))
  (scatter xs ys :s 25.0 :color "darkorchid" :alpha 0.6 :label "data"))

(xlabel "x")
(ylabel "y")
(title "Scatter Plot")
(legend)
(grid :visible t)

(let ((out "examples/scatter.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
