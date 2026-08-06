;;;; csd-demo.lisp — cross spectral density
;;;; Twin of reference_scripts/csd-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:sp-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:sp-example)

(let* ((n 1024) (fs 100.0d0)
       (x (loop for i from 0 below n
                collect (+ (sin (/ (* 2 pi 10.0d0 i) fs))
                           (* 0.2d0 (- (/ (mod (* i 37) 97) 97.0d0) 0.5d0)))))
       (y (loop for i from 0 below n
                collect (+ (sin (+ (/ (* 2 pi 10.0d0 i) fs) 0.7d0))
                           (* 0.2d0 (- (/ (mod (* i 53) 89) 89.0d0) 0.5d0))))))
  (figure)
  (csd x y :nfft 256 :fs fs)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/csd-demo.~a" ext)))
  (format t "~&Saved examples/csd-demo.png~%"))
(uiop:quit)
