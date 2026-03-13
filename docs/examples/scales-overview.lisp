;;;; scales-overview.lisp — 2x2 subplot grid showing all four scale types
;;;; Run: sbcl --load examples/scales-overview.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig axs) (subplots 2 2 :figsize '(10.0d0 8.0d0))
  (let ((xs (loop for i from 0 below 50
                  collect (coerce (* i 0.2d0) 'double-float))))

    (let* ((ax (aref axs 0 0))
           (ys (mapcar (lambda (x) (sin x)) xs)))
      (mpl.containers:plot ax xs ys :color "steelblue" :linewidth 1.5)
      (mpl.containers:axes-grid-toggle ax :visible t))

    (let* ((ax (aref axs 0 1))
           (ys (mapcar (lambda (x) (exp (* x 0.1d0))) xs)))
      (mpl.containers:plot ax xs ys :color "tomato" :linewidth 1.5)
      (mpl.containers:axes-set-yscale ax :log)
      (mpl.containers:axes-grid-toggle ax :visible t))

    (let* ((ax (aref axs 1 0))
           (ys (mapcar (lambda (x) (cos x)) xs)))
      (mpl.containers:plot ax xs ys :color "seagreen" :linewidth 1.5)
      (mpl.containers:axes-grid-toggle ax :visible t))

    (let* ((ax (aref axs 1 1))
           (ys (mapcar (lambda (x) (* x x)) xs)))
      (mpl.containers:plot ax xs ys :color "darkorchid" :linewidth 1.5)
      (mpl.containers:axes-grid-toggle ax :visible t)))

  (let ((out "examples/scales-overview.png"))
    (mpl.containers:savefig fig out)
    (mpl.containers:savefig fig "examples/scales-overview.svg")
    (mpl.containers:savefig fig "examples/scales-overview.pdf")
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
