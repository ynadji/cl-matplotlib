;;;; colormaps-extended.lisp — gradient strips through the extended
;;;; colormap registry (matplotlib-parity tables + _r variants)
;;;; Twin of reference_scripts/colormaps-extended.py

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:cmap-example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:cmap-example)

(defparameter *cmaps*
  '("turbo" "tab10" "PuOr" "YlGnBu" "twilight" "seismic"
    "Oranges" "cubehelix" "viridis_r"))

(let ((gradient (make-array '(1 256))))
  (dotimes (j 256)
    (setf (aref gradient 0 j) (/ j 255.0d0)))
  (multiple-value-bind (fig axes)
      (subplots (length *cmaps*) 1 :figsize '(6.4d0 4.8d0) :dpi 100)
    (declare (ignore fig))
    (loop for i from 0 below (length *cmaps*)
          for name in *cmaps*
          for ax = (aref axes i)
          do (cl-matplotlib.containers:imshow
              ax gradient
              :cmap (cl-matplotlib.primitives:get-colormap name)
              :aspect :auto)
             (cl-matplotlib.containers:axes-set-xticks ax '())
             (cl-matplotlib.containers:axes-set-yticks ax '())
             ;; axes-fraction label left of the strip
             (let ((label (cl-matplotlib.containers:text
                           ax -0.01d0 0.5d0 name
                           :fontsize 9.0d0 :ha :right :va :center)))
               (setf (cl-matplotlib.rendering:artist-transform label)
                     (cl-matplotlib.containers:axes-base-trans-axes ax))))
    (dolist (ext '("png" "svg" "pdf"))
      (savefig (format nil "examples/colormaps-extended.~a" ext)))
    (format t "~&Saved examples/colormaps-extended.png~%")))

(uiop:quit)
