;;;; gg-pie.lisp — pie chart: stacked bar + coord-polar :theta :y.
;;;; No plotnine reference exists (plotnine has no coord_polar); this
;;;; demo is validated by the coord unit tests.

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :cat #("a" "b" "c" "d")
                  :value #(30.0d0 25 25 20))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x 0 :y :value :fill :cat))
               (gg:geom-bar :stat :identity :width 1)
               (gg:coord-polar :theta :y))
             "examples/gg/gg-pie.png")
  (format t "~&Saved examples/gg/gg-pie.png~%"))
(uiop:quit)
