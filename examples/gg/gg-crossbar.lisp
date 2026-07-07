;;;; gg-crossbar.lisp — hollow bar with middle line
;;;; Twin of reference_scripts/gg/gg-crossbar.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :trt #("a" "b" "c" "d")
                  :mid #(3.2d0 5.1d0 4.4d0 6.0d0)
                  :lo #(2.4d0 4.4d0 3.6d0 5.1d0)
                  :hi #(4.0d0 5.8d0 5.2d0 6.9d0))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :trt :y :mid
                                               :ymin :lo :ymax :hi))
               (gg:geom-crossbar :width 0.5d0))
             "examples/gg/gg-crossbar.png")
  (format t "~&Saved examples/gg/gg-crossbar.png~%"))

(uiop:quit)
