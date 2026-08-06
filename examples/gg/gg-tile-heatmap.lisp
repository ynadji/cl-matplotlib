;;;; gg-tile-heatmap.lisp — heatmap via geom-tile + gradient fill
;;;; Twin of reference_scripts/gg/gg-tile-heatmap.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (dotimes (i 12)
    (dotimes (j 10)
      (push (list :x (float i 1.0d0) :y (float j 1.0d0)
                  :v (* (sin (* i 0.5d0)) (cos (* j 0.6d0))))
            rows)))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :x :y :y :fill :v))
               (gg:geom-tile))
             "examples/gg/gg-tile-heatmap.png")
  (format t "~&Saved examples/gg/gg-tile-heatmap.png~%"))

(uiop:quit)
