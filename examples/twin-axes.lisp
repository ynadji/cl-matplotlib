;;;; twin-axes.lisp — Dual y-axes demonstration using side-by-side subplots
;;;; Run: sbcl --load examples/twin-axes.lisp
;;;;
;;;; Demonstrates two related datasets with different scales
;;;; using a 1x2 subplot layout (line plot + bar chart).

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(multiple-value-bind (fig axs) (subplots 1 2 :figsize '(12.0d0 5.0d0))
  ;; Months as x-axis
  (let ((months (loop for i from 1.0d0 to 12.0d0 collect i))
        ;; Temperature data (Celsius)
        (temps '(2.0d0 4.0d0 8.0d0 13.0d0 18.0d0 22.0d0
                 25.0d0 24.0d0 20.0d0 14.0d0 8.0d0 3.0d0))
        ;; Precipitation data (mm)
        (precip '(50.0d0 40.0d0 45.0d0 55.0d0 65.0d0 50.0d0
                  35.0d0 40.0d0 55.0d0 70.0d0 65.0d0 55.0d0)))

    ;; Left panel: Temperature (line plot)
    (let ((ax (aref axs 0)))
      (mpl.containers:plot ax months temps :color "tomato" :linewidth 2.0)
      (mpl.containers:axis-set-label-text
       (mpl.containers:axes-base-xaxis ax) "Month")
      (mpl.containers:axis-set-label-text
       (mpl.containers:axes-base-yaxis ax) "Temperature (C)")
      (mpl.containers:axes-grid-toggle ax :visible t))

    ;; Right panel: Precipitation (bar chart)
    (let ((ax (aref axs 1)))
      (mpl.containers:bar ax months precip :color "steelblue" :width 0.6d0)
      (mpl.containers:axis-set-label-text
       (mpl.containers:axes-base-xaxis ax) "Month")
      (mpl.containers:axis-set-label-text
       (mpl.containers:axes-base-yaxis ax) "Precipitation (mm)")
      (mpl.containers:axes-grid-toggle ax :visible t)))

  (let ((out "examples/twin-axes.png"))
    (mpl.containers:savefig fig out)
    (format t "~&Saved to ~A~%" out)))

(uiop:quit)
