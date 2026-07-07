;;;; gg-abline.lisp — slope/intercept reference line
;;;; Twin of reference_scripts/gg/gg-abline.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((xs (loop for i from 0 below 21 collect (* i 0.5d0)))
       (ys (mapcar (lambda (x) (+ (* 1.2d0 x) 0.8d0
                                  (* 1.5d0 (sin (* x 1.9d0)))))
                   xs))
       (data (list :x (coerce xs 'vector) :y (coerce ys 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:geom-abline :slope 1.2d0 :intercept 0.8d0
                               :color "#DB5F57" :linetype :dashed :size 1))
             "examples/gg/gg-abline.png")
  (format t "~&Saved examples/gg/gg-abline.png~%"))

(uiop:quit)
