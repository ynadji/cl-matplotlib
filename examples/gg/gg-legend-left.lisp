;;;; gg-legend-left.lisp — twin of reference_scripts/gg/gg-legend-left.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :x #(1.0d0 2 3 4 5 6)
                  :y #(2.0d0 4 3 5 4 6)
                  :grp #("a" "b" "c" "a" "b" "c"))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y :color :grp))
               (gg:geom-point :size 3)
               (gg:theme :legend-position :left))
             "examples/gg/gg-legend-left.png")
  (format t "~&Saved examples/gg/gg-legend-left.png~%"))

(uiop:quit)
