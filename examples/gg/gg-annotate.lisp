;;;; gg-annotate.lisp — reference lines and annotations
;;;; Twin of reference_scripts/gg/gg-annotate.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((xs (loop for i from 0 below 50 collect (* i 0.2d0)))
       (ys (mapcar (lambda (x) (* (sin x) (exp (/ (- x) 8.0d0)))) xs))
       (data (list :x (coerce xs 'vector) :y (coerce ys 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-line)
               (gg:geom-hline :yintercept 0 :linetype :dashed :color "#999999")
               (gg:geom-vline :xintercept pi :linetype :dashed :color "#999999")
               (gg:annotate :text :x (+ pi 2.2d0) :y 0.8d0
                            :label "first zero crossing")
               (gg:annotate :rect :xmin 6 :xmax 8 :ymin -0.3d0 :ymax 0.3d0
                            :alpha 0.2d0 :fill "#3366FF"))
             "examples/gg/gg-annotate.png")
  (format t "~&Saved examples/gg/gg-annotate.png~%"))

(uiop:quit)
