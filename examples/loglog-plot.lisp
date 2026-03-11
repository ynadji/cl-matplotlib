;;;; loglog-plot.lisp — Log-log and semi-log plots in 2×1 subplots
;;;; Run: sbcl --load examples/loglog-plot.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

;; Helper: add title to a specific axes object (mirrors pyplot:title but for any axes)
(defun add-title-to-axes (ax text)
  (let* ((fig (mpl.containers:axes-base-figure ax))
         (dpi (if fig (mpl.containers:figure-dpi fig) 100))
         (title-pad-px (+ (* 6.0 (/ dpi 72.0)) 1.0))
         (pos (mpl.containers:axes-base-position ax))
         (axes-h-px (* (fourth pos)
                       (if fig
                           (float (mpl.containers:figure-height-px fig) 1.0d0)
                           500.0d0)))
         (y-title (+ 1.0d0 (if (> axes-h-px 0.0d0) (/ title-pad-px axes-h-px) 0.02d0)))
         (txt (make-instance 'mpl.rendering:text-artist
                              :x 0.5d0 :y y-title
                              :text text
                              :fontsize 12.0
                              :horizontalalignment :center
                              :verticalalignment :baseline
                              :zorder 3)))
    (setf (mpl.rendering:artist-transform txt)
          (mpl.containers:axes-base-trans-axes ax))
    (push txt (mpl.containers:axes-base-texts ax))
    (setf (mpl.rendering:artist-stale ax) t)
    txt))

;; x = logspace(0, 3, 50) → 1 to 1000
(let* ((n 50)
       (x (loop for i from 0 below n
                collect (expt 10.0d0 (* 3.0d0 (/ (float i 1.0d0) (1- n))))))
       (y1 (mapcar (lambda (xi) (expt xi 2.0d0)) x))
       (y2 (mapcar (lambda (xi) (expt xi 1.5d0)) x))
       (log10-y1 (mapcar (lambda (yi) (log yi 10.0d0)) y1))
       (log10-y2 (mapcar (lambda (yi) (log yi 10.0d0)) y2)))

  (multiple-value-bind (fig axs) (subplots 2 1 :figsize '(8.0d0 6.0d0))
    ;; Top subplot: loglog
    (let ((ax1 (aref axs 0)))
      (mpl.containers:plot ax1 x y1 :color "blue" :linewidth 1.5d0 :label "x²")
      (mpl.containers:axes-set-xscale ax1 :log)
      (mpl.containers:axes-set-yscale ax1 :log)
      (mpl.containers:plot ax1 x y2 :color "red" :linewidth 1.5d0 :linestyle :dashed :label "x^1.5")
      (mpl.containers:axis-set-label-text (mpl.containers:axes-base-xaxis ax1) "x")
      (mpl.containers:axis-set-label-text (mpl.containers:axes-base-yaxis ax1) "y")
      (mpl.containers:axes-legend ax1 :loc :best)
      (mpl.containers:axes-grid-toggle ax1 :visible t :which :both :alpha 0.3d0)
      (add-title-to-axes ax1 "Log-Log Plot"))

    ;; Bottom subplot: semilogx
    (let ((ax2 (aref axs 1)))
      (mpl.containers:plot ax2 x log10-y1 :color "blue" :linewidth 1.5d0 :label "log₁₀(x²)")
      (mpl.containers:axes-set-xscale ax2 :log)
      (mpl.containers:plot ax2 x log10-y2 :color "red" :linewidth 1.5d0 :linestyle :dashed :label "log₁₀(x^1.5)")
      (mpl.containers:axis-set-label-text (mpl.containers:axes-base-xaxis ax2) "x")
      (mpl.containers:axis-set-label-text (mpl.containers:axes-base-yaxis ax2) "log₁₀(y)")
      (mpl.containers:axes-legend ax2 :loc :best)
      (mpl.containers:axes-grid-toggle ax2 :visible t :which :both :alpha 0.3d0)
      (add-title-to-axes ax2 "Semi-Log X Plot"))

    (mpl.containers:savefig fig "examples/loglog-plot.png")
    (mpl.containers:savefig fig "examples/loglog-plot.svg")
    (mpl.containers:savefig fig "examples/loglog-plot.pdf")
    (format t "~&Saved to examples/loglog-plot.{png,svg,pdf}~%")))

(uiop:quit)
