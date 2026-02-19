;;;; shared-axes.lisp — Two subplots with shared x-axis
;;;; Run: sbcl --load examples/shared-axes.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig axs) (subplots 2 1 :sharex t :figsize '(8.0d0 6.0d0))
  (let ((xs (loop for i from 0 below 100
                  collect (coerce (* i 0.126d0) 'double-float))))  ; 0 to ~4*pi

    ;; Top subplot: sin(x)
    (let* ((ax (aref axs 0))
           (ys (mapcar #'sin xs)))
      (mpl.containers:plot ax xs ys :color "steelblue" :linewidth 1.5)
      (mpl.containers:axis-set-label-text
       (mpl.containers:axes-base-yaxis ax) "sin(x)")
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Bottom subplot: cos(x)
    (let* ((ax (aref axs 1))
           (ys (mapcar #'cos xs)))
      (mpl.containers:plot ax xs ys :color "tomato" :linewidth 1.5)
      (mpl.containers:axis-set-label-text
       (mpl.containers:axes-base-xaxis ax) "x (radians)")
      (mpl.containers:axis-set-label-text
       (mpl.containers:axes-base-yaxis ax) "cos(x)")
      (mpl.containers:axes-grid-toggle ax :visible t)))

  (let ((out "examples/shared-axes.png"))
    (mpl.containers:savefig fig out)
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
