;;;; render.lisp — render a figure to an in-memory buffer.
;;;; Mirrors print-png (src/backends/backend-vecto.lisp) but grabs the
;;;; pixels instead of writing a file: raw RGBA straight from the zpng
;;;; image behind the Vecto canvas, or encoded PNG octets via
;;;; vecto:save-png-stream.

(in-package #:cl-matplotlib.show)

(defun %ensure-renderer (figure renderer)
  "Return RENDERER sized to FIGURE, creating a renderer-vecto when NIL.
Reusing a renderer across frames keeps its font cache warm; its
width/height slots are re-synced here because renderers memoize size."
  (let ((w (mpl.containers:figure-width-px figure))
        (h (mpl.containers:figure-height-px figure)))
    (if renderer
        (progn
          (setf (mpl.backends:renderer-width renderer) w
                (mpl.backends:renderer-height renderer) h)
          renderer)
        (make-instance 'mpl.backends:renderer-vecto
                       :width w :height h
                       :dpi (mpl.containers:figure-dpi figure)))))

(defun %render-figure-grabbing (figure renderer grab-fn)
  "Draw FIGURE with RENDERER on a fresh Vecto canvas, then call GRAB-FN
with no arguments while the canvas is still live and return its value."
  (let ((w (mpl.backends:renderer-width renderer))
        (h (mpl.backends:renderer-height renderer)))
    (vecto:with-canvas (:width w :height h)
      (setf (mpl.backends:renderer-active-p renderer) t)
      (unwind-protect
           (progn
             ;; White background, as in print-png
             (vecto:set-rgb-fill 1.0 1.0 1.0)
             (vecto:rectangle 0 0 w h)
             (vecto:fill-path)
             (mpl.rendering:draw figure renderer)
             (funcall grab-fn))
        (setf (mpl.backends:renderer-active-p renderer) nil)))))

(defun %grab-rgba ()
  "The canvas pixels as a flat RGBA (unsigned-byte 8) vector, row-major
from the top-left. The zpng image outlives with-canvas (the macro only
unbinds the special), and each render allocates a fresh canvas, so the
returned array is safe to keep."
  (zpng:image-data (vecto::image vecto::*graphics-state*)))

(defun %grab-png ()
  "The canvas encoded as PNG octets, in memory. Coerced to a simple
array because consumers (websocket-driver, SDL) require one."
  (coerce (flexi-streams:with-output-to-sequence (s)
            (vecto:save-png-stream s))
          '(simple-array (unsigned-byte 8) (*))))

(defun render-figure-to-rgba (figure &key renderer)
  "Render FIGURE and return (values rgba-octets width height renderer).
RGBA-OCTETS is a flat (unsigned-byte 8) vector, 4 bytes per pixel,
row-major from the top-left. Pass the returned RENDERER back in to reuse
its font cache across frames."
  (let ((renderer (%ensure-renderer figure renderer)))
    (values (%render-figure-grabbing figure renderer #'%grab-rgba)
            (mpl.backends:renderer-width renderer)
            (mpl.backends:renderer-height renderer)
            renderer)))

(defun render-figure-to-png-octets (figure &key renderer)
  "Render FIGURE and return (values png-octets width height renderer).
PNG-OCTETS is a complete PNG file as an octet vector."
  (let ((renderer (%ensure-renderer figure renderer)))
    (values (%render-figure-grabbing figure renderer #'%grab-png)
            (mpl.backends:renderer-width renderer)
            (mpl.backends:renderer-height renderer)
            renderer)))
