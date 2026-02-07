;;;; image.lisp — imshow plotting function
;;;; Ported from matplotlib's axes/_axes.py Axes.imshow
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; imshow — Display 2D array as image
;;; ============================================================

(defun imshow (ax data &key (cmap nil) (norm nil) (interpolation :nearest)
                             (extent nil) (origin :upper) (aspect :auto)
                             (alpha nil) (vmin nil) (vmax nil) (zorder 0))
  "Display a 2D data array as an image on axes AX.

AX — an axes-base instance.
DATA — a 2D array (grayscale) or 3D array (RGB/RGBA).
CMAP — colormap (keyword like :viridis, or colormap instance). Default: viridis.
NORM — normalize instance for scalar→[0,1] mapping. Auto-created if nil.
INTERPOLATION — :nearest or :bilinear (default :nearest).
EXTENT — list (xmin xmax ymin ymax) mapping data to axes coords.
         Default: (0 W 0 H) where W=cols, H=rows.
ORIGIN — :upper (row 0 at top, default) or :lower (row 0 at bottom).
ASPECT — :auto (fill axes), :equal (1:1 pixels), or numeric ratio.
ALPHA — transparency (nil = opaque).
VMIN, VMAX — data range for normalization (auto-detected if nil).
ZORDER — drawing order (default 0).

Returns the created AxesImage."
  ;; Resolve colormap
  (let* ((cmap-obj (cond
                     ((null cmap) (mpl.primitives:get-colormap :viridis))
                     ((typep cmap 'mpl.primitives:colormap) cmap)
                     (t (mpl.primitives:get-colormap cmap))))
         ;; Compute default extent from data dimensions
         (h (array-dimension data 0))
         (w (if (> (array-rank data) 1)
                (array-dimension data 1)
                1))
         (effective-extent (or extent
                               (list 0.0d0 (float w 1.0d0)
                                     0.0d0 (float h 1.0d0))))
         ;; Create normalize if needed
         (norm-obj (cond
                     (norm norm)
                     (t (let ((n (mpl.primitives:make-normalize
                                  :vmin (when vmin (float vmin 1.0d0))
                                  :vmax (when vmax (float vmax 1.0d0)))))
                          ;; Auto-detect vmin/vmax for 2D scalar data
                          (when (= (array-rank data) 2)
                            (let ((dmin most-positive-double-float)
                                  (dmax most-negative-double-float))
                              (dotimes (i h)
                                (dotimes (j w)
                                  (let ((v (float (aref data i j) 1.0d0)))
                                    (when (< v dmin) (setf dmin v))
                                    (when (> v dmax) (setf dmax v)))))
                              (when (null (mpl.primitives:norm-vmin n))
                                (setf (mpl.primitives:norm-vmin n) dmin))
                              (when (null (mpl.primitives:norm-vmax n))
                                (setf (mpl.primitives:norm-vmax n) dmax))))
                          n))))
         ;; Create AxesImage
         (img (make-instance 'mpl.rendering:axes-image
                              :data data
                              :cmap cmap-obj
                              :norm norm-obj
                              :interpolation interpolation
                              :extent effective-extent
                              :origin origin
                              :aspect aspect
                              :vmin vmin
                              :vmax vmax
                              :alpha (when alpha (float alpha 1.0d0))
                              :zorder zorder)))
    ;; Set the transform on the image to transData
    (setf (mpl.rendering:artist-transform img)
          (axes-base-trans-data ax))
    ;; Add image to axes images list
    (axes-add-image ax img)
    ;; Update data limits from extent
    (let ((xmin (float (first effective-extent) 1.0d0))
          (xmax (float (second effective-extent) 1.0d0))
          (ymin (float (third effective-extent) 1.0d0))
          (ymax (float (fourth effective-extent) 1.0d0)))
      (axes-update-datalim ax (list xmin xmax) (list ymin ymax)))
    ;; Handle aspect ratio
    (when (eq aspect :equal)
      ;; For equal aspect, adjust view limits to maintain 1:1 pixel ratio
      (let* ((ext-w (- (float (second effective-extent) 1.0d0)
                       (float (first effective-extent) 1.0d0)))
             (ext-h (- (float (fourth effective-extent) 1.0d0)
                       (float (third effective-extent) 1.0d0))))
        (declare (ignore ext-w ext-h))
        ;; Let autoscale handle it for now; full aspect enforcement
        ;; would require knowing the display bbox dimensions
        nil))
    ;; Autoscale
    (axes-autoscale-view ax)
    ;; Return the image
    img))

;;; ============================================================
;;; axes-add-image — add AxesImage to axes
;;; ============================================================

(defun axes-add-image (ax img)
  "Add an AxesImage to the axes."
  (push img (axes-base-images ax))
  (setf (mpl.rendering:artist-axes img) ax)
  (setf (mpl.rendering:artist-figure img) (axes-base-figure ax))
  (setf (mpl.rendering:artist-stale ax) t)
  img)
