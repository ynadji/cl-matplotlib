;;;; gg-theme-538.lisp — twin of reference_scripts/gg/gg-theme-538.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :x (coerce (loop for i from 0 below 21 collect (* i 0.5d0)) 'vector)
                  :y (coerce (loop for i from 0 below 21
                                   collect (* (/ (mod (* i 37) 97) 97.0d0) 8.0d0))
                             'vector)))
      (theme (gg:theme-538)))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:geom-line)
               theme)
             "examples/gg/gg-theme-538.png")
  (format t "~&Saved examples/gg/gg-theme-538.png~%"))

(uiop:quit)
