;;;; psd-demo.lisp — Welch power spectral density
;;;; Twin of reference_scripts/psd-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:sp-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:sp-example)

(let* ((n 1024) (fs 100.0d0)
       (x (loop for i from 0 below n
                collect (+ (sin (/ (* 2 pi 10.0d0 i) fs))
                           (* 0.5d0 (sin (/ (* 2 pi 25.0d0 i) fs)))
                           (* 0.1d0 (- (/ (mod (* i 37) 97) 97.0d0) 0.5d0))))))
  (figure)
  (psd x :nfft 256 :fs fs)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/psd-demo.~a" ext)))
  (format t "~&Saved examples/psd-demo.png~%"))
(uiop:quit)
