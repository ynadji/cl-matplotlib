;;;; bar3d.lisp — 3D bar chart (bar3d)
;;;; Run: ros run -- --load examples/bar3d.lisp --quit

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((xs '()) (ys '()) (dzs '()))
  (dotimes (i 4)
    (dotimes (j 4)
      (push i xs) (push j ys) (push (+ 1 i j (* 0.5d0 (mod (* i j) 3))) dzs)))
  (subplots 1 1 :projection :3d)
  (bar3d (reverse xs) (reverse ys) 0 0.6 0.6 (reverse dzs) :color "tab:blue")
  (xlabel "x")
  (ylabel "y")
  (zlabel "height")
  (title "3D bars"))

(let ((out "examples/bar3d.png"))
  (savefig out)
  (savefig "examples/bar3d.svg")
  (savefig "examples/bar3d.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
