;;;; gg-freqpoly.lisp — frequency polygon
;;;; Twin of reference_scripts/gg/gg-freqpoly.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((vals (loop for i from 0 below 120
                   collect (+ 10.0d0 (* 4.0d0 (sin (* i 1.7d0)))
                              (* 2.5d0 (cos (* i 0.3d0))))))
       (data (list :v (coerce vals 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :v))
               (gg:geom-freqpoly :bins 15))
             "examples/gg/gg-freqpoly.png")
  (format t "~&Saved examples/gg/gg-freqpoly.png~%"))

(uiop:quit)
