;;;; gg-boxplot.lisp — boxplots per group
;;;; Twin of reference_scripts/gg/gg-boxplot.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (loop for g in '("a" "b" "c")
        for gi from 0
        do (loop for i from 0 below 60
                 for v = (+ (* 3.0d0 (sin (+ (* i 0.9d0) gi)))
                            (* gi 1.5d0)
                            (* (if (= i 7) 2.5d0 0.0d0) (1+ gi)))
                 do (push (list :grp g :v v) rows)))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :grp :y :v))
               (gg:geom-boxplot))
             "examples/gg/gg-boxplot.png")
  (format t "~&Saved examples/gg/gg-boxplot.png~%"))

(uiop:quit)
