;;;; gg-theme-seaborn.lisp — twin of reference_scripts/gg/gg-theme-seaborn.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data (list :x (coerce (loop for i from 0 below 21 collect (* i 0.5d0)) 'vector)
                  :y (coerce (loop for i from 0 below 21
                                   collect (* (/ (mod (* i 37) 97) 97.0d0) 8.0d0))
                             'vector)))
      (theme (gg:theme-seaborn)))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:geom-line)
               theme)
             "examples/gg/gg-theme-seaborn.png")
  (format t "~&Saved examples/gg/gg-theme-seaborn.png~%"))

(uiop:quit)
