;;;; gg-smooth-lm.lisp — linear smoother with confidence ribbon
;;;; Twin of reference_scripts/gg/gg-smooth-lm.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((xs (loop for i from 0 below 40 collect (* i 0.25d0)))
       (ys (mapcar (lambda (x) (+ (* 1.5d0 x) 2.0d0
                                  (* 2.5d0 (sin (* x 2.7d0)))))
                   xs))
       (data (list :x (coerce xs 'vector) :y (coerce ys 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:geom-smooth :method :lm))
             "examples/gg/gg-smooth-lm.png")
  (format t "~&Saved examples/gg/gg-smooth-lm.png~%"))

(uiop:quit)
