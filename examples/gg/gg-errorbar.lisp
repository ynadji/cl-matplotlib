;;;; gg-errorbar.lisp — error bars over group means
;;;; Twin of reference_scripts/gg/gg-errorbar.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :trt #("a" "b" "c" "d")
                  :mean #(3.2d0 5.1d0 4.4d0 6.0d0)
                  :lo #(2.4d0 4.4d0 3.6d0 5.1d0)
                  :hi #(4.0d0 5.8d0 5.2d0 6.9d0))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :trt :y :mean))
               (gg:geom-errorbar :mapping (gg:aes :ymin :lo :ymax :hi)
                                 :width 0.2d0)
               (gg:geom-point :size 2))
             "examples/gg/gg-errorbar.png")
  (format t "~&Saved examples/gg/gg-errorbar.png~%"))

(uiop:quit)
