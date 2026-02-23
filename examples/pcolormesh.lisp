;;;; pcolormesh.lisp — Pseudocolor mesh plot
;;;; Run: sbcl --load examples/pcolormesh.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((rows 20)
       (cols 30)
       (data (make-array (list rows cols) :element-type 'double-float)))
  ;; Fill data: z = sin(x/5) * cos(y/5)
  (dotimes (i rows)
    (dotimes (j cols)
      (setf (aref data i j)
            (* (sin (/ (float j 1.0d0) 5.0d0))
               (cos (/ (float i 1.0d0) 5.0d0))))))

  (let ((sm (pcolormesh data :cmap :viridis)))
    (colorbar sm)))

(title "Pseudocolor Mesh: sin(x/5)*cos(y/5)")

(let ((out "examples/pcolormesh.png"))
  (savefig out)
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
