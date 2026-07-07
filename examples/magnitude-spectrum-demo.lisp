;;;; magnitude-spectrum-demo.lisp — single-FFT magnitude spectrum
;;;; Twin of reference_scripts/magnitude-spectrum-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:sp-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:sp-example)

(let* ((n 512) (fs 100.0d0)
       (x (loop for i from 0 below n
                collect (+ (sin (/ (* 2 pi 15.0d0 i) fs))
                           (* 0.4d0 (sin (/ (* 2 pi 40.0d0 i) fs)))))))
  (figure)
  (magnitude-spectrum x :fs fs)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/magnitude-spectrum-demo.~a" ext)))
  (format t "~&Saved examples/magnitude-spectrum-demo.png~%"))
(uiop:quit)
