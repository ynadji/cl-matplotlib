;;;; gg-bar-stacked.lisp — stacked bars via fill aesthetic
;;;; Twin of reference_scripts/gg/gg-bar-stacked.py

(require :asdf)
(asdf:load-system :ggplot)

(defpackage #:gg-example (:use #:cl))
(in-package #:gg-example)

(let* ((rows '())
       (spec '(("Fair" ("D" 2) ("E" 3) ("F" 1))
               ("Good" ("D" 5) ("E" 4) ("F" 6))
               ("Ideal" ("D" 8) ("E" 10) ("F" 7)))))
  (dolist (entry spec)
    (destructuring-bind (cut &rest clarity-counts) entry
      (dolist (cc clarity-counts)
        (destructuring-bind (clarity n) cc
          (dotimes (_ n)
            (push (list :cut cut :clarity clarity) rows))))))
  (let ((data (nreverse rows)))
    (gg:ggsave (gg:stack (gg:ggplot data (gg:aes :x :cut :fill :clarity))
                 (gg:geom-bar))
               "examples/gg/gg-bar-stacked.png")
    (format t "~&Saved examples/gg/gg-bar-stacked.png~%")))

(uiop:quit)
