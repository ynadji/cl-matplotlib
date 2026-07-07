;;;; gg-gradient2.lisp — diverging fill gradient on a tile map
;;;; Twin of reference_scripts/gg/gg-gradient2.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (dotimes (i 12)
    (dotimes (j 10)
      (push (list :x (float i 1d0) :y (float j 1d0)
                  :v (* (sin (* i 0.5d0)) (cos (* j 0.6d0)))) rows)))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :x :y :y :fill :v))
               (gg:geom-tile)
               (gg:scale-fill-gradient2 :low "#832424" :mid "#FFFFFF"
                                        :high "#3A3A98" :midpoint 0))
             "examples/gg/gg-gradient2.png")
  (format t "~&Saved examples/gg/gg-gradient2.png~%"))

(uiop:quit)
