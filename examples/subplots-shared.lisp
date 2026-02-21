;;;; subplots-shared.lisp — 2x2 subplots with shared x and y axes
;;;; Run: sbcl --load examples/subplots-shared.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig axs) (subplots 2 2 :figsize '(10.0d0 8.0d0) :sharex t :sharey t)
  (let ((x '(0.0d0 1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0)))

    ;; Top-left
    (let ((ax (aref axs 0 0)))
      (mpl.containers:plot ax x '(0.0d0 0.8d0 0.9d0 0.1d0 -0.8d0 -0.9d0 0.0d0)
                           :color "blue" :linewidth 1.5))

    (let ((ax (aref axs 0 1)))
      (mpl.containers:plot ax x '(0.0d0 0.6d0 0.8d0 0.2d0 -0.6d0 -0.8d0 0.0d0)
                           :color "red" :linewidth 1.5))

    (let ((ax (aref axs 1 0)))
      (mpl.containers:plot ax x '(0.5d0 0.9d0 0.4d0 -0.4d0 -0.9d0 -0.4d0 0.5d0)
                           :color "green" :linewidth 1.5))

    (let ((ax (aref axs 1 1)))
      (mpl.containers:plot ax x '(-0.5d0 0.3d0 0.9d0 0.9d0 0.3d0 -0.5d0 -0.9d0)
                           :color "purple" :linewidth 1.5))

)

  (let ((out "examples/subplots-shared.png"))
    (mpl.containers:savefig fig out)
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
