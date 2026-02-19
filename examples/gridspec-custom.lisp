;;;; gridspec-custom.lisp — Non-uniform grid layout with varied plots
;;;; Run: sbcl --load examples/gridspec-custom.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; 2x2 grid with different mathematical functions in each cell
(multiple-value-bind (fig axs) (subplots 2 2 :figsize '(10.0d0 8.0d0))
  (let ((xs (loop for i from 0 below 50
                  collect (coerce (* i 0.2d0) 'double-float))))

    ;; Top-left: quadratic curve
    (let* ((ax (aref axs 0 0))
           (ys (mapcar (lambda (x) (* 0.1d0 x x)) xs)))
      (mpl.containers:plot ax xs ys :color "steelblue" :linewidth 2.0)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Top-right: exponential decay
    (let* ((ax (aref axs 0 1))
           (ys (mapcar (lambda (x) (exp (* -0.3d0 x))) xs)))
      (mpl.containers:plot ax xs ys :color "tomato" :linewidth 2.0)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Bottom-left: sine wave
    (let* ((ax (aref axs 1 0))
           (ys (mapcar (lambda (x) (sin x)) xs)))
      (mpl.containers:plot ax xs ys :color "seagreen" :linewidth 2.0)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Bottom-right: damped oscillation
    (let* ((ax (aref axs 1 1))
           (ys (mapcar (lambda (x) (* (exp (* -0.2d0 x)) (sin (* 2.0d0 x)))) xs)))
      (mpl.containers:plot ax xs ys :color "darkorchid" :linewidth 2.0)
      (mpl.containers:axes-grid-toggle ax :visible t)))

  (let ((out "examples/gridspec-custom.png"))
    (mpl.containers:savefig fig out)
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
