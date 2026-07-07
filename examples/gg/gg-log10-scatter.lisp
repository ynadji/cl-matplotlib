;;;; gg-log10-scatter.lisp — log10 scales on both axes
;;;; Twin of reference_scripts/gg/gg-log10-scatter.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((xs (loop for i from 0 below 19 collect (expt 10 (/ i 6.0d0))))
       (ys (mapcar (lambda (x) (* 3.0d0 (expt x 1.7d0))) xs))
       (data (list :x (coerce xs 'vector) :y (coerce ys 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:scale-x-log10)
               (gg:scale-y-log10))
             "examples/gg/gg-log10-scatter.png")
  (format t "~&Saved examples/gg/gg-log10-scatter.png~%"))

(uiop:quit)
