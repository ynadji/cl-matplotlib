;;;; specgram-demo.lisp — chirp spectrogram
;;;; Twin of reference_scripts/specgram-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:sp-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:sp-example)

(let* ((n 2048) (fs 100.0d0)
       (x (loop for i from 0 below n
                collect (sin (/ (* 2 pi (+ 5.0d0 (/ (* 20.0d0 i) n)) i) fs)))))
  (figure)
  (specgram x :nfft 128 :fs fs :noverlap 64)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/specgram-demo.~a" ext)))
  (format t "~&Saved examples/specgram-demo.png~%"))
(uiop:quit)
