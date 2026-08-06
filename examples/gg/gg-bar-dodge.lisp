;;;; gg-bar-dodge.lisp — dodged bars
;;;; Twin of reference_scripts/gg/gg-bar-dodge.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let ((rows '()))
  (dolist (entry '(("Fair" ("D" 2) ("E" 3) ("F" 1))
                   ("Good" ("D" 5) ("E" 4) ("F" 6))
                   ("Ideal" ("D" 8) ("E" 10) ("F" 7))))
    (destructuring-bind (cut &rest clarity-counts) entry
      (dolist (cc clarity-counts)
        (destructuring-bind (clarity n) cc
          (dotimes (_ n)
            (push (list :cut cut :clarity clarity) rows))))))
  (gg:ggsave (gg:stack (gg:ggplot (nreverse rows) (gg:aes :x :cut :fill :clarity))
               (gg:geom-bar :position :dodge))
             "examples/gg/gg-bar-dodge.png")
  (format t "~&Saved examples/gg/gg-bar-dodge.png~%"))

(uiop:quit)
