;;;; gg-violin.lisp — violin plots per group
;;;; Twin of reference_scripts/gg/gg-violin.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (loop for g in '("a" "b" "c")
        for gi from 0
        do (loop for i from 0 below 80
                 for v = (+ (* 3.0d0 (sin (+ (* i 0.9d0) gi)))
                            (cos (* i 0.31d0))
                            (* gi 1.5d0))
                 do (push (list :grp g :v v) rows)))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :grp :y :v))
               (gg:geom-violin))
             "examples/gg/gg-violin.png")
  (format t "~&Saved examples/gg/gg-violin.png~%"))

(uiop:quit)
