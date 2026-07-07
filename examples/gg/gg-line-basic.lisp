;;;; gg-line-basic.lisp — default geom-line
;;;; Twin of reference_scripts/gg/gg-line-basic.py
;;;; Run: ros run -- --load examples/gg/gg-line-basic.lisp --quit

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((xs (loop for i from 0 to 40 collect (* i 0.25d0)))
       (ys (mapcar (lambda (x) (* (sin x) (exp (/ (- x) 5.0d0)))) xs))
       (data (list :t (coerce xs 'vector)
                   :signal (coerce ys 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :t :y :signal))
               (gg:geom-line)
               (gg:labs :x "time" :y "damped sine"))
             "examples/gg/gg-line-basic.png")
  (format t "~&Saved examples/gg/gg-line-basic.png~%"))

(uiop:quit)
