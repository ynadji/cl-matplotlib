;;;; gg-reverse.lisp — reversed y axis (depth-style plot)
;;;; Twin of reference_scripts/gg/gg-reverse.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((xs (loop for i from 0 below 41 collect (* i 0.25d0)))
       (ys (mapcar (lambda (x) (+ 5.0d0 (* 3.0d0 (sin x)) (* 0.4d0 x))) xs))
       (data (list :x (coerce xs 'vector) :depth (coerce ys 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :depth))
               (gg:geom-line)
               (gg:scale-y-reverse))
             "examples/gg/gg-reverse.png")
  (format t "~&Saved examples/gg/gg-reverse.png~%"))

(uiop:quit)
