;;;; tricontourf-demo.lisp — twin of reference_scripts/tricontourf-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:tri-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:tri-example)

(let* ((n 200)
       (xs (loop for i from 0 below n collect (* (/ (mod (* i 37) 97) 97.0d0) 10.0d0)))
       (ys (loop for i from 0 below n collect (* (/ (mod (* i 53) 89) 89.0d0) 8.0d0)))
       (zs (mapcar (lambda (x y) (* (sin (* x 0.6d0)) (cos (* y 0.5d0)))) xs ys)))
  (figure)
  (tricontourf xs ys zs :n-levels 7)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/tricontourf-demo.~a" ext)))
  (format t "~&Saved examples/tricontourf-demo.png~%"))
(uiop:quit)
