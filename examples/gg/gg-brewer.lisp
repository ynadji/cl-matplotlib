;;;; gg-brewer.lisp — ColorBrewer discrete fills
;;;; Twin of reference_scripts/gg/gg-brewer.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :grp #("a" "b" "c" "d" "e")
                  :v #(4.0d0 7.0d0 3.0d0 5.5d0 6.2d0))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :grp :y :v :fill :grp))
               (gg:geom-col)
               (gg:scale-fill-brewer :palette "Set2"))
             "examples/gg/gg-brewer.png")
  (format t "~&Saved examples/gg/gg-brewer.png~%"))

(uiop:quit)
