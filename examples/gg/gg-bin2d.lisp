;;;; gg-bin2d.lisp — 2D histogram heatmap
;;;; Twin of reference_scripts/gg/gg-bin2d.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((xs '()) (ys '()))
  ;; integer-mod quasi-random data: bit-exact across languages
  (dotimes (i 500)
    (push (- (* (/ (mod (* i 37) 97) 97.0d0) 7.0d0) 3.5d0) xs)
    (push (- (* (/ (mod (* i 53) 89) 89.0d0) 5.0d0) 2.5d0) ys))
  (gg:ggsave (gg:stack (gg:ggplot (list :x (coerce (nreverse xs) 'vector)
                                        :y (coerce (nreverse ys) 'vector))
                                  (gg:aes :x :x :y :y))
               (gg:geom-bin2d :bins 15))
             "examples/gg/gg-bin2d.png")
  (format t "~&Saved examples/gg/gg-bin2d.png~%"))

(uiop:quit)
