;;;; gg-histogram.lisp — geom-histogram
;;;; Twin of reference_scripts/gg/gg-histogram.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((vals (loop for i from 0 below 200
                   collect (+ (* 3.0d0 (sin (* i 0.7d0)))
                              (* 2.0d0 (cos (* i 0.13d0)))
                              (* i 0.01d0))))
       (data (list :v (coerce vals 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :v))
               (gg:geom-histogram :bins 20))
             "examples/gg/gg-histogram.png")
  (format t "~&Saved examples/gg/gg-histogram.png~%"))

(uiop:quit)
