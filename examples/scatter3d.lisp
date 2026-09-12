;;;; scatter3d.lisp — 3D scatter with depth shading and colormapped values
;;;; Run: ros run -- --load examples/scatter3d.lisp --quit

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; Deterministic points: three helical strands
(let ((xs '()) (ys '()) (zs '()) (cs '()))
  (dotimes (k 60)
    (let* ((tt (* 4.0d0 pi (/ k 59.0d0)))
           (r (+ 1.0d0 (* 0.02d0 k))))
      (push (* r (cos tt)) xs)
      (push (* r (sin tt)) ys)
      (push (/ k 10.0d0) zs)
      (push (/ k 59.0d0) cs)))
  (subplots 1 1 :projection :3d)
  (scatter3d (reverse xs) (reverse ys) (reverse zs) :c (reverse cs) :cmap "plasma" :s 30)
  (xlabel "x")
  (ylabel "y")
  (zlabel "z")
  (title "3D scatter"))

(let ((out "examples/scatter3d.png"))
  (savefig out)
  (savefig "examples/scatter3d.svg")
  (savefig "examples/scatter3d.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
