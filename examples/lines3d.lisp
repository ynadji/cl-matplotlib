;;;; lines3d.lisp — 3D parametric curves (plot3d)
;;;; Run: ros run -- --load examples/lines3d.lisp --quit

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let* ((n 200)
       (ts (loop for k below n collect (* 8.0d0 pi (/ k (1- n)))))
       (zs (loop for tt in ts collect (/ tt (* 8.0d0 pi))))
       (rs (loop for z in zs collect (+ 0.5d0 z)))
       (xs (mapcar (lambda (r tt) (* r (cos tt))) rs ts))
       (ys (mapcar (lambda (r tt) (* r (sin tt))) rs ts)))
  (subplots 1 1 :projection :3d)
  (plot3d xs ys zs :color "tab:blue" :linewidth 2 :label "helix")
  (plot3d (mapcar #'- xs) ys zs :color "tab:orange" :linewidth 1 :linestyle :dashed :label "mirror")
  (xlabel "x")
  (ylabel "y")
  (zlabel "z")
  (title "3D lines")
  (legend))

(let ((out "examples/lines3d.png"))
  (savefig out)
  (savefig "examples/lines3d.svg")
  (savefig "examples/lines3d.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
