;;;; ggblank.lisp — empty ggplot panel (theme-gray calibration target)
;;;; Twin of reference_scripts/gg/ggblank.py
;;;; Run: ros run -- --load examples/gg/ggblank.lisp --quit

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((data '(:x #(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0)
              :y #(10.0d0 12.0d0 16.0d0 13.0d0 20.0d0))))
  (gg:ggsave (gg:ggplot data (gg:aes :x :x :y :y))
             "examples/gg/ggblank.png")
  (format t "~&Saved examples/gg/ggblank.png~%"))

(uiop:quit)
