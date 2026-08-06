;;;; date-formatter-demo.lisp — explicit month-locator + date-formatter.
;;;; Twin of reference_scripts/date-formatter-demo.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:date-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:date-example)

(let* ((start (local-time:encode-timestamp 0 0 0 0 1 1 2024
                                           :timezone local-time:+utc-zone+))
       (dates (loop for i from 0 below 60
                    collect (local-time:timestamp+ start (* 3 i) :day)))
       (vals (loop for i from 0 below 60
                   collect (+ 5.0d0 (* 2.0d0 (sin (* i 0.3d0)))
                              (* i 0.02d0)))))
  (figure)
  (plot dates vals)
  (let ((xaxis (cl-matplotlib.containers:axes-base-xaxis (gca))))
    (cl-matplotlib.containers:axis-set-major-locator xaxis (month-locator))
    (cl-matplotlib.containers:axis-set-major-formatter
     xaxis (make-instance 'date-formatter :fmt "%b %Y")))
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/date-formatter-demo.~a" ext)))
  (format t "~&Saved examples/date-formatter-demo.png~%"))

(uiop:quit)
