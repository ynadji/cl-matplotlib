;;;; gg-facet-grid.lisp — panel matrix with row and column strips
;;;; Twin of reference_scripts/gg/gg-facet-grid.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (loop for g in '("u" "v") for gi from 0 do
    (loop for h in '("p" "q" "r") for hi from 0 do
      (dotimes (i 8)
        (push (list :g g :h h
                    :x (+ (* i 0.6d0) (* 0.3d0 gi))
                    :y (+ (sin (float (+ i gi (* 2 hi)) 1d0)) (* 2 hi) gi))
              rows))))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:facet-grid :rows :g :cols :h))
             "examples/gg/gg-facet-grid.png")
  (format t "~&Saved examples/gg/gg-facet-grid.png~%"))

(uiop:quit)
