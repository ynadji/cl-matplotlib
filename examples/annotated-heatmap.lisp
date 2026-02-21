;;;; annotated-heatmap.lisp — Heatmap with text annotations in each cell
;;;; Run: sbcl --load examples/annotated-heatmap.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(let ((data #2A((0.1d0 0.2d0 0.5d0 0.3d0)
                (0.4d0 0.8d0 0.1d0 0.6d0)
                (0.7d0 0.3d0 0.9d0 0.2d0)
                (0.5d0 0.6d0 0.4d0 0.7d0))))
  (figure :figsize '(6 5))
  (imshow data :cmap "Blues")
  (dotimes (i 4)
    (dotimes (j 4)
      (text j i (format nil "~,1F" (aref data i j))
            :ha :center :va :center :fontsize 12 :color "black")))
  (title "Annotated Heatmap"))

(let ((out "examples/annotated-heatmap.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
