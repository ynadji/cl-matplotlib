;;;; spy-demo.lisp — sparsity pattern
;;;; Twin of reference_scripts/spy-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:lt-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:lt-example)

(let ((z (make-array '(20 20) :initial-element 0.0d0)))
  (dotimes (i 20)
    (setf (aref z i i) 1.0d0)
    (setf (aref z i (mod (* i 7) 20)) 1.0d0)
    (when (> i 2)
      (setf (aref z i (- i 3)) 1.0d0)))
  (figure)
  (spy z)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/spy-demo.~a" ext)))
  (format t "~&Saved examples/spy-demo.png~%"))
(uiop:quit)
