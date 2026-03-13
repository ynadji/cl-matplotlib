;;;; histogram.lisp — Histogram of normally-distributed data
;;;; Run: sbcl --load examples/histogram.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; Simple PRNG
(let ((seed 7))
  (defun my-random ()
    (setf seed (mod (+ (* seed 1103515245) 12345) (expt 2 31)))
    (/ (float seed 1.0d0) (float (expt 2 31) 1.0d0))))

(defun randn ()
  (let ((u1 (max 1d-10 (my-random)))
        (u2 (my-random)))
    (* (sqrt (* -2.0d0 (log u1)))
       (cos (* 2.0d0 pi u2)))))

(figure :figsize '(8.0d0 5.0d0))

(let ((data (loop repeat 1000 collect (+ 5.0d0 (* 2.0d0 (randn))))))
  (hist data :bins 30 :color "steelblue" :edgecolor "white" :alpha 0.85))

(xlabel "Value")
(ylabel "Count")
(title "Histogram (N=1000, mean=5, std=2)")
(grid :visible t)

(let ((out "examples/histogram.png"))
  (savefig out)
  (savefig "examples/histogram.svg")
  (savefig "examples/histogram.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
