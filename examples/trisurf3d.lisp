;;;; trisurf3d.lisp — triangulated surface of scattered points (plot-trisurf)
;;;; Run: ros run -- --load examples/trisurf3d.lisp --quit

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; Points on a polar grid (radii × angles), z = sin(-x y)
(let ((xs '()) (ys '()) (zs '()))
  (loop for ri from 1 to 8
        for r = (/ ri 8.0d0)
        do (loop for ai below 24
                 for a = (* 2.0d0 pi (/ ai 24.0d0))
                 do (let ((x (* r (cos a))) (y (* r (sin a))))
                      (push x xs) (push y ys) (push (sin (* -1.0d0 x y)) zs))))
  (subplots 1 1 :projection :3d)
  (plot-trisurf (reverse xs) (reverse ys) (reverse zs) :cmap "viridis" :linewidth 0.2 :edgecolor "black")
  (xlabel "x")
  (ylabel "y")
  (zlabel "z")
  (title "triangulated surface"))

(let ((out "examples/trisurf3d.png"))
  (savefig out)
  (savefig "examples/trisurf3d.svg")
  (savefig "examples/trisurf3d.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
