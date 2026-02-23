;;;; pcolormesh-basic.lisp — Pseudocolor mesh with colorbar
;;;; Run: sbcl --load examples/pcolormesh-basic.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((rows 20)
       (cols 30)
       (data (make-array (list rows cols) :element-type 'double-float)))
  (dotimes (i rows)
    (dotimes (j cols)
      (let ((x (/ (- (float j 1.0d0) 15.0d0) 5.0d0))
            (y (/ (- (float i 1.0d0) 10.0d0) 5.0d0)))
        (setf (aref data i j)
              (* (cos (sqrt (+ (* x x) (* y y) 0.01d0)))
                 (exp (* -0.1d0 (+ (* x x) (* y y)))))))))

  (let ((sm (pcolormesh data :cmap :plasma)))
    (colorbar sm)))

(title "Radial Wave: cos(r)*exp(-r^2/10)")

(let ((out "examples/pcolormesh-basic.png"))
  (savefig out)
  (savefig "examples/pcolormesh-basic.svg")
  (savefig "examples/pcolormesh-basic.pdf")
  (format t "~&Saved to ~A~%" out))

(uiop:quit)
