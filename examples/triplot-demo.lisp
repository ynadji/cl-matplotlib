;;;; triplot-demo.lisp — twin of reference_scripts/triplot-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:tri-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:tri-example)

(let* ((n 40)
       (xs (loop for i from 0 below n collect (* (/ (mod (* i 37) 97) 97.0d0) 10.0d0)))
       (ys (loop for i from 0 below n collect (* (/ (mod (* i 53) 89) 89.0d0) 8.0d0))))
  (figure)
  (triplot xs ys :color "C0" :linewidth 1.0)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/triplot-demo.~a" ext)))
  (format t "~&Saved examples/triplot-demo.png~%"))
(uiop:quit)
