;;;; eventplot-demo.lisp — event raster rows
;;;; Twin of reference_scripts/eventplot-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:lt-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:lt-example)

(figure)
(eventplot '((1.0 2.5 3.0 4.2 6.0 7.5 9.0)
             (0.5 2.0 3.5 5.0 5.5 8.0)
             (1.5 4.0 4.5 6.5 8.5))
           :lineoffsets '(1 2 3) :linelengths 0.8
           :colors '("C0" "C1" "C2"))
(dolist (ext '("png" "svg" "pdf"))
  (savefig (format nil "examples/eventplot-demo.~a" ext)))
(format t "~&Saved examples/eventplot-demo.png~%")
(uiop:quit)
