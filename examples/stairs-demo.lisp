;;;; stairs-demo.lisp — filled and outlined step functions
;;;; Twin of reference_scripts/stairs-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:lt-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:lt-example)

(let ((values (loop for i from 0 below 14 collect (+ (sin (* i 0.5d0)) 2d0)))
      (edges (loop for i from 0 to 14 collect (* i 0.5d0))))
  (figure)
  (stairs values edges :fill t :alpha 0.4 :color "C0")
  (stairs (mapcar (lambda (v) (+ v 1d0)) values) edges
          :color "C1" :linewidth 2)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/stairs-demo.~a" ext)))
  (format t "~&Saved examples/stairs-demo.png~%"))
(uiop:quit)
