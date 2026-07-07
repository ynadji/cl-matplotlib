;;;; axline-demo.lisp — infinite reference lines
;;;; Twin of reference_scripts/axline-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:lt-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:lt-example)

(figure)
(axline '(0 0) :slope 1 :color "C0" :linewidth 2)
(axline '(0 2) :xy2 '(1 3) :color "C1" :linestyle :dashed)
(axline '(2 0) :slope -0.5 :color "C2")
(xlim -1 5)
(ylim -1 5)
(dolist (ext '("png" "svg" "pdf"))
  (savefig (format nil "examples/axline-demo.~a" ext)))
(format t "~&Saved examples/axline-demo.png~%")
(uiop:quit)
