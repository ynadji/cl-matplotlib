;;;; gg-scatter-color.lisp — colored scatter with legend
;;;; Twin of reference_scripts/gg/gg-scatter-color.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((grp (loop for i from 0 below 20
                  collect (elt '("a" "b" "c" "a" "b") (mod i 5))))
       (data (list :wt #(0.5d0 1.0d0 1.5d0 2.0d0 2.5d0 3.0d0 3.5d0 4.0d0 4.5d0 5.0d0
                         1.2d0 2.3d0 3.1d0 4.2d0 1.8d0 2.9d0 3.7d0 4.6d0 0.8d0 3.4d0)
                   :mpg #(1.1d0 1.9d0 3.2d0 4.1d0 5.4d0 6.2d0 7.7d0 8.1d0 9.6d0 10.2d0
                          2.6d0 4.9d0 6.5d0 8.8d0 3.5d0 5.8d0 7.2d0 9.3d0 1.5d0 6.9d0)
                   :grp (coerce grp 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :wt :y :mpg :color :grp))
               (gg:geom-point))
             "examples/gg/gg-scatter-color.png")
  (format t "~&Saved examples/gg/gg-scatter-color.png~%"))

(uiop:quit)
