;;;; gg-count.lisp — points sized by overlap count
;;;; Twin of reference_scripts/gg/gg-count.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (dotimes (i 120)
    (push (list :x (float (mod (* i i) 5) 1d0)
                :y (float (mod (* i 7) 4) 1d0))
          rows))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :x :y :y))
               (gg:geom-count))
             "examples/gg/gg-count.png")
  (format t "~&Saved examples/gg/gg-count.png~%"))

(uiop:quit)
