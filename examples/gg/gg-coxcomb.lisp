;;;; gg-coxcomb.lisp — coxcomb/rose chart: bar + coord-polar :theta :x.
;;;; No plotnine reference exists (plotnine has no coord_polar).

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :cat #("a" "b" "c" "d" "e" "f")
                  :value #(4.0d0 7 3 6 5 8))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :cat :y :value :fill :cat))
               (gg:geom-bar :stat :identity :width 1)
               (gg:coord-polar :theta :x))
             "examples/gg/gg-coxcomb.png")
  (format t "~&Saved examples/gg/gg-coxcomb.png~%"))
(uiop:quit)
