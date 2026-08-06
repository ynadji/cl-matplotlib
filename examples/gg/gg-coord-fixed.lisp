;;;; gg-coord-fixed.lisp — twin of reference_scripts/gg/gg-coord-fixed.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :x #(0.0d0 1 2 3 4 5 6 7 8 9 10)
                  :y #(0.0d0 2 1 3 2 4 3 5 4 6 5))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:geom-line)
               (gg:coord-fixed :ratio 1))
             "examples/gg/gg-coord-fixed.png")
  (format t "~&Saved examples/gg/gg-coord-fixed.png~%"))
(uiop:quit)
