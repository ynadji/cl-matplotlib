;;;; gg-area-stacked.lisp — stacked area chart
;;;; Twin of reference_scripts/gg/gg-area-stacked.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (loop for x from 0 below 30
        do (loop for s in '("u" "v" "w")
                 for si from 0
                 for y = (+ 2.0d0 si
                            (sin (+ (* x 0.4d0) (* si 2.0d0)))
                            (* 0.05d0 x))
                 do (push (list :x (float x 1.0d0) :s s :y y) rows)))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :x :y :y :fill :s))
               (gg:geom-area))
             "examples/gg/gg-area-stacked.png")
  (format t "~&Saved examples/gg/gg-area-stacked.png~%"))

(uiop:quit)
