;;;; date-plot.lisp — local-time timestamps plotted directly; the unit
;;;; converter installs the date scale (AutoDateLocator + concise labels).
;;;; Twin of reference_scripts/date-plot.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:date-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:date-example)

(let ((dates (loop for m from 1 to 12
                   collect (local-time:encode-timestamp
                            0 0 0 0 1 m 2024
                            :timezone local-time:+utc-zone+)))
      (vals (loop for i from 0 below 12
                  collect (+ 10.0d0 (* 3.0d0 (sin (* i 0.9d0)))))))
  (figure)
  (plot dates vals)
  (dolist (ext '("png" "svg" "pdf"))
    (savefig (format nil "examples/date-plot.~a" ext)))
  (format t "~&Saved examples/date-plot.png~%"))

(uiop:quit)
