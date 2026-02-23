;;;; streamplot-basic.lisp — Streamplot of rotational flow
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)
(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((n 20)
       (x (loop for i from 0 below n
                collect (+ -3.0d0 (* i (/ 6.0d0 (1- n))))))
       (y (loop for i from 0 below n
                collect (+ -3.0d0 (* i (/ 6.0d0 (1- n))))))
       (u (make-array (list n n) :element-type 'double-float))
       (v (make-array (list n n) :element-type 'double-float)))
  ;; U = -Y, V = X
  (dotimes (row n)
    (dotimes (col n)
      (setf (aref u row col) (- (nth row y)))
      (setf (aref v row col) (nth col x))))
  (streamplot x y u v))

(title "Streamplot — Rotational Flow")
(xlabel "X")
(ylabel "Y")
(savefig "examples/streamplot-basic.png")
(uiop:quit)
