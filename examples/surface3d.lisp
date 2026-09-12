;;;; surface3d.lisp — 3D surface plot (plot-surface with a colormap)
;;;; Run: ros run -- --load examples/surface3d.lisp --quit

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(defparameter *n* 40)

(defun sinc-grid (n)
  "X, Y, Z arrays of sin(r)/r over [-5, 5]²."
  (let ((x (make-array (list n n) :element-type 'double-float))
        (y (make-array (list n n) :element-type 'double-float))
        (z (make-array (list n n) :element-type 'double-float)))
    (dotimes (i n)
      (dotimes (j n)
        (let* ((xv (- (* 10.0d0 (/ j (1- n))) 5.0d0))
               (yv (- (* 10.0d0 (/ i (1- n))) 5.0d0))
               (r (sqrt (+ (* xv xv) (* yv yv)))))
          (setf (aref x i j) xv
                (aref y i j) yv
                (aref z i j) (if (zerop r) 1.0d0 (/ (sin r) r))))))
    (values x y z)))

(multiple-value-bind (x y z) (sinc-grid *n*)
  (subplots 1 1 :projection :3d)
  (plot-surface x y z :cmap "viridis")
  (xlabel "x")
  (ylabel "y")
  (zlabel "sinc")
  (title "3D surface"))

(let ((out "examples/surface3d.png"))
  (savefig out)
  (savefig "examples/surface3d.svg")
  (savefig "examples/surface3d.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
