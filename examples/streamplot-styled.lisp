;;;; streamplot-styled.lisp — Styled streamplot of saddle-point flow
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
  ;; U = X, V = -Y
  (dotimes (row n)
    (dotimes (col n)
      (setf (aref u row col) (nth col x))
      (setf (aref v row col) (- (nth row y)))))
  (streamplot x y u v :color "darkred" :linewidth 2.0d0))

(title "Streamplot — Saddle Point Flow")
(xlabel "X")
(ylabel "Y")
(savefig "examples/streamplot-styled.png")
(uiop:quit)
