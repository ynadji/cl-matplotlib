;;;; gridspec-multi.lisp — Multi-panel layout with different plot types
;;;; Run: sbcl --load examples/gridspec-multi.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig axs) (subplots 1 3 :figsize '(12.0d0 4.0d0))
  (let ((x (loop for i from 0.0d0 to 10.0d0 by 1.0d0 collect i)))

    ;; Left panel: quadratic
    (let* ((ax (aref axs 0))
           (ys (mapcar (lambda (v) (* v v)) x)))
      (mpl.containers:plot ax x ys :color "steelblue" :linewidth 2.0)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Middle panel: square root
    (let* ((ax (aref axs 1))
           (ys (mapcar (lambda (v) (sqrt v)) x)))
      (mpl.containers:plot ax x ys :color "tomato" :linewidth 2.0)
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Right panel: bar chart
    (let ((ax (aref axs 2)))
      (mpl.containers:bar ax '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0)
                          '(10.0d0 20.0d0 15.0d0 25.0d0 18.0d0)
                          :color "seagreen" :width 0.6d0)
      (mpl.containers:axes-grid-toggle ax :visible t)))

  (let ((out "examples/gridspec-multi.png"))
    (mpl.containers:savefig fig out)
    (mpl.containers:savefig fig "examples/gridspec-multi.svg")
    (mpl.containers:savefig fig "examples/gridspec-multi.pdf")
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
