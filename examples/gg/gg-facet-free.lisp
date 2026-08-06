;;;; gg-facet-free.lisp — facet-wrap with free y scales
;;;; Twin of reference_scripts/gg/gg-facet-free.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (loop for g in '("a" "b" "c" "d") for gi from 0 do
    (let ((scale (expt 10 gi)))
      (dotimes (i 12)
        (push (list :g g
                    :x (* i 0.5d0)
                    :y (* scale (+ 1.0d0 (* 0.4d0 (sin (float (+ i gi) 1d0))))))
              rows))))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :x :y :y))
               (gg:geom-point)
               (gg:facet-wrap :g :scales :free-y))
             "examples/gg/gg-facet-free.png")
  (format t "~&Saved examples/gg/gg-facet-free.png~%"))

(uiop:quit)
