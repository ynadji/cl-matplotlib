;;;; date-scatter.lisp — scatter with timestamps on x.
;;;; Twin of reference_scripts/date-scatter.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:date-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:date-example)

(let* ((start (local-time:encode-timestamp 0 0 0 0 1 6 2024
                                           :timezone local-time:+utc-zone+))
       (dates (loop for i from 0 below 10
                    collect (local-time:timestamp+ start i :day)))
       (vals (loop for i from 0 below 10
                   collect (+ 3.0d0 (cos (* i 0.8d0))))))
  (figure)
  (scatter dates vals)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/date-scatter.~a" ext)))
  (format t "~&Saved examples/date-scatter.png~%"))

(uiop:quit)
