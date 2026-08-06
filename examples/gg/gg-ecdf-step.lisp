;;;; gg-ecdf-step.lisp — empirical CDF
;;;; Twin of reference_scripts/gg/gg-ecdf-step.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((vals (loop for i from 0 below 60
                   collect (+ 5.0d0 (* 2.0d0 (sin (* i 0.7d0))) (* i 0.05d0))))
       (data (list :v (coerce vals 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :v))
               (gg:geom-step :stat :ecdf))
             "examples/gg/gg-ecdf-step.png")
  (format t "~&Saved examples/gg/gg-ecdf-step.png~%"))

(uiop:quit)
