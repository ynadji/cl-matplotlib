;;;; gg-dates.lisp — date axis with calendar breaks
;;;; Twin of reference_scripts/gg/gg-dates.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((dates (loop for i from 0 below 24
                    collect (multiple-value-bind (y m)
                                (floor (+ (* 2023 12) i) 12)
                              (gg:date y (1+ m) 1))))
       (vals (loop for i from 0 below 24
                   collect (+ 10.0d0 (* 3.0d0 (sin (* i 0.6d0))) (* i 0.2d0))))
       (data (list :d (coerce dates 'vector) :v (coerce vals 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :d :y :v))
               (gg:geom-line)
               (gg:scale-x-date :date-breaks '(:month 6)
                                :date-labels "%Y-%m"))
             "examples/gg/gg-dates.png")
  (format t "~&Saved examples/gg/gg-dates.png~%"))

(uiop:quit)
