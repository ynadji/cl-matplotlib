;;;; gg-bar-percent.lisp — bar heights as fractions via after-stat expression
;;;; Twin of reference_scripts/gg/gg-bar-percent.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((cuts (append (make-list 3 :initial-element "Fair")
                     (make-list 9 :initial-element "Good")
                     (make-list 14 :initial-element "Ideal")
                     (make-list 7 :initial-element "Premium")
                     (make-list 11 :initial-element "Very Good")))
       (data (list :cut (coerce cuts 'vector))))
  (gg:ggsave
   (gg:stack (gg:ggplot data
                        (gg:aes :x :cut
                                :y (gg:after-stat
                                    (lambda (tbl)
                                      (let* ((c (gg:ggcolumn tbl :count))
                                             (total (reduce #'+ c)))
                                        (map 'vector
                                             (lambda (v) (/ v total))
                                             c))))))
     (gg:geom-bar))
   "examples/gg/gg-bar-percent.png")
  (format t "~&Saved examples/gg/gg-bar-percent.png~%"))

(uiop:quit)
