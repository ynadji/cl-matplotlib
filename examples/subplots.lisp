;;;; subplots.lisp — Multiple subplots in one figure
;;;; Run: sbcl --load examples/subplots.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig axs) (subplots 2 2 :figsize '(10.0d0 8.0d0))
  (let ((xs (loop for i from 0 below 50
                  collect (coerce (* i 0.2d0) 'double-float))))

    ;; Top-left: sin
    (let* ((ax (aref axs 0 0))
           (ys (mapcar (lambda (x) (sin x)) xs)))
      (mpl.containers:plot ax xs ys :color "steelblue" :linewidth 1.5)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Top-right: cos
    (let* ((ax (aref axs 0 1))
           (ys (mapcar (lambda (x) (cos x)) xs)))
      (mpl.containers:plot ax xs ys :color "tomato" :linewidth 1.5)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Bottom-left: sin * cos
    (let* ((ax (aref axs 1 0))
           (ys (mapcar (lambda (x) (* (sin x) (cos x))) xs)))
      (mpl.containers:plot ax xs ys :color "seagreen" :linewidth 1.5)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Bottom-right: sin^2
    (let* ((ax (aref axs 1 1))
           (ys (mapcar (lambda (x) (expt (sin x) 2)) xs)))
      (mpl.containers:plot ax xs ys :color "darkorchid" :linewidth 1.5)
      (mpl.containers:axes-grid-toggle ax :visible t)))

  (let ((out "examples/subplots.png"))
    (mpl.containers:savefig fig out)
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
