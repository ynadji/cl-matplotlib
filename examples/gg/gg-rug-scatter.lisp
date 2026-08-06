;;;; gg-rug-scatter.lisp — scatter with marginal rugs
;;;; Twin of reference_scripts/gg/gg-rug-scatter.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((xs (loop for i from 0 below 40
                 collect (+ (* i 0.25d0) (* 0.5d0 (sin (float i 1d0))))))
       (ys (mapcar (lambda (x) (+ 2.0d0 (* 0.8d0 x) (* 1.5d0 (cos x)))) xs))
       (data (list :x (coerce xs 'vector) :y (coerce ys 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:geom-rug))
             "examples/gg/gg-rug-scatter.png")
  (format t "~&Saved examples/gg/gg-rug-scatter.png~%"))

(uiop:quit)
