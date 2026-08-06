;;;; gg-coord-trans-log10.lisp — twin of
;;;; reference_scripts/gg/gg-coord-trans-log10.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :x #(1.0d0 2 5 10 20 50 100 200 500 1000)
                  :y #(1.0d0 3 2 5 4 7 6 8 7 9))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:coord-trans :x :log10))
             "examples/gg/gg-coord-trans-log10.png")
  (format t "~&Saved examples/gg/gg-coord-trans-log10.png~%"))
(uiop:quit)
