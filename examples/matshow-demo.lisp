;;;; matshow-demo.lisp — matrix display with top ticks
;;;; Twin of reference_scripts/matshow-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:lt-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:lt-example)

(let ((z (make-array '(10 12))))
  (dotimes (i 10)
    (dotimes (j 12)
      (setf (aref z i j) (* (sin (* i 0.7d0)) (cos (* j 0.5d0))))))
  (figure)
  (matshow z)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/matshow-demo.~a" ext)))
  (format t "~&Saved examples/matshow-demo.png~%"))
(uiop:quit)
