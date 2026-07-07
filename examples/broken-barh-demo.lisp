;;;; broken-barh-demo.lisp — horizontal bar segments
;;;; Twin of reference_scripts/broken-barh-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:lt-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:lt-example)

(figure)
(broken-barh '((110 30) (150 10)) '(10 9) :facecolors "tab:blue")
(broken-barh '((10 50) (100 20) (130 10)) '(20 9)
             :facecolors '("tab:orange" "tab:green" "tab:red"))
(ylim 5 35)
(xlim 0 200)
(dolist (ext '("png" "svg" "pdf"))
  (savefig (format nil "examples/broken-barh-demo.~a" ext)))
(format t "~&Saved examples/broken-barh-demo.png~%")
(uiop:quit)
