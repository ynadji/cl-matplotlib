;;;; gg-qq-basic.lisp — normal Q-Q plot
;;;; Twin of reference_scripts/gg/gg-qq-basic.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((vals (loop for i from 0 below 80
                   ;; integer-mod quasi-random: bit-exact across languages
                   collect (+ 3.0d0
                              (* 3.0d0
                                 (- (/ (mod (* i 37) 97) 97.0d0) 0.5d0)
                                 (+ (/ (mod (* i 53) 89) 89.0d0) 0.5d0)))))
       (data (list :v (coerce vals 'vector))))
  (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :sample :v))
               (gg:geom-qq))
             "examples/gg/gg-qq-basic.png")
  (format t "~&Saved examples/gg/gg-qq-basic.png~%"))

(uiop:quit)
