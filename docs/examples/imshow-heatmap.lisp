;;;; imshow-heatmap.lisp — Heatmap displayed with imshow
;;;; Run: sbcl --load examples/imshow-heatmap.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

;; Create 10x10 gradient heatmap: value = row*0.1 + col*0.1
(let* ((n 10)
       (data (make-array (list n n) :element-type 'double-float)))
  (loop for i below n do
    (loop for j below n do
      (setf (aref data i j)
            (+ (* (float i 1.0d0) 0.1d0)
               (* (float j 1.0d0) 0.1d0)))))
  (imshow data :cmap :viridis :origin :lower))

(xlabel "Column")
(ylabel "Row")
(title "Heatmap — Gradient Pattern")

(let ((out "examples/imshow-heatmap.png"))
  (savefig out)
  (savefig "examples/imshow-heatmap.svg")
  (savefig "examples/imshow-heatmap.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
