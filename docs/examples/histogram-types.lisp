;;;; histogram-types.lisp — Demo of histogram histtype settings in subplots
;;;; Run: ros run -- --noinform --load examples/histogram-types.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(defvar *data*
  '(-2.5d0 -2.1d0 -1.8d0 -1.6d0 -1.4d0 -1.3d0 -1.2d0 -1.0d0 -0.9d0 -0.8d0
    -0.7d0 -0.6d0 -0.5d0 -0.5d0 -0.4d0 -0.3d0 -0.3d0 -0.2d0 -0.2d0 -0.1d0
     0.0d0  0.0d0  0.1d0  0.1d0  0.2d0  0.3d0  0.3d0  0.4d0  0.5d0  0.5d0
     0.6d0  0.7d0  0.8d0  0.9d0  1.0d0  1.2d0  1.3d0  1.4d0  1.6d0  1.8d0
     2.1d0  2.5d0))

(multiple-value-bind (fig axs) (subplots 2 2 :figsize '(10.0d0 8.0d0))

  (let ((ax (aref axs 0 0)))
    (mpl.containers:hist ax *data* :bins 10 :histtype :bar :color "steelblue" :edgecolor "black")
    (mpl.containers:axes-grid-toggle ax :visible t))

  (let ((ax (aref axs 0 1)))
    (mpl.containers:hist ax *data* :bins 10 :histtype :step :color "tomato")
    (mpl.containers:axes-grid-toggle ax :visible t))

  (let ((ax (aref axs 1 0)))
    (mpl.containers:hist ax *data* :bins 10 :histtype :stepfilled :color "seagreen" :alpha 0.7)
    (mpl.containers:axes-grid-toggle ax :visible t))

  (let ((ax (aref axs 1 1)))
    (mpl.containers:hist ax *data* :bins 10 :histtype :bar :color "goldenrod" :edgecolor "black" :alpha 0.8)
    (mpl.containers:axes-grid-toggle ax :visible t))

  (let ((out "examples/histogram-types.png"))
    (mpl.containers:savefig fig out)
    (mpl.containers:savefig fig "examples/histogram-types.svg")
    (mpl.containers:savefig fig "examples/histogram-types.pdf")
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
