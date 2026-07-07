;;;; gg-segment-text.lisp — lollipop chart with value labels
;;;; Twin of reference_scripts/gg/gg-segment-text.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :name #("alpha" "beta" "gamma" "delta" "epsilon")
                  :v #(4.2d0 7.8d0 2.9d0 6.1d0 5.0d0))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :name :y :v))
               (gg:geom-segment :mapping (gg:aes :xend :name :y 0 :yend :v)
                                :color "#666666")
               (gg:geom-point :size 3 :color "#DB5F57")
               (gg:geom-text :mapping (gg:aes :label :v)
                             :nudge-y 0.45d0 :size 9))
             "examples/gg/gg-segment-text.png")
  (format t "~&Saved examples/gg/gg-segment-text.png~%"))

(uiop:quit)
