;;;; image.lisp — imshow plotting function
;;;; Ported from matplotlib's axes/_axes.py Axes.imshow
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; imshow — Display 2D array as image
;;; ============================================================

(defun imshow (ax data &key (cmap nil) (norm nil) (interpolation :nearest)
                             (extent nil) (origin :upper) (aspect :equal)
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
                               (list -0.5d0 (- (float w 1.0d0) 0.5d0)
                                     -0.5d0 (- (float h 1.0d0) 0.5d0))))
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
    ;; Autoscale (tight for images — no margin, matching matplotlib's sticky edges)
    ;; For imshow, use tight autoscale (no extra margin) since the extent
    ;; already includes the 0.5-pixel margin around each pixel center.
    (axes-autoscale-view ax :tight t)
    ;; Handle aspect ratio (after autoscale so view-lim is set)
    (when (eq aspect :equal)
      ;; For equal aspect, matplotlib adjusts the AXES BOX (position) to be square.
      ;; The view limits are already correct from tight autoscale (= extent).
      ;; Adjust axes position to make the display box square
      (let* ((fig (axes-base-figure ax))
             (pos (axes-base-position ax))
             (left-frac (first pos))
             (bottom-frac (second pos))
             (width-frac (third pos))
             (height-frac (fourth pos))
             (fig-w (float (figure-width-px fig) 1.0d0))
             (fig-h (float (figure-height-px fig) 1.0d0))
             (ax-left-px (* left-frac fig-w))
             (ax-bottom-px (* bottom-frac fig-h))
             (ax-w (* width-frac fig-w))
             (ax-h (* height-frac fig-h))
             ;; Data aspect from effective-extent: (xmin xmax ymin ymax)
             (data-w (- (float (second effective-extent) 1.0d0)
                        (float (first effective-extent) 1.0d0)))
             (data-h (- (float (fourth effective-extent) 1.0d0)
                        (float (third effective-extent) 1.0d0)))
             (data-aspect (/ (abs data-w) (abs data-h)))
             (display-aspect (/ ax-w ax-h)))
        (cond
          ((> display-aspect data-aspect)
           ;; Axes wider than data: shrink width, center horizontally
           (let* ((new-ax-w (float (* ax-h data-aspect) 1.0d0))
                  (x-offset (/ (- ax-w new-ax-w) 2.0d0))
                  (new-left-frac (/ (+ ax-left-px x-offset) fig-w))
                  (new-width-frac (/ new-ax-w fig-w)))
             (setf (axes-base-position ax)
                   (list new-left-frac bottom-frac new-width-frac height-frac))
             (%setup-transforms ax)))
          ((< display-aspect data-aspect)
           ;; Axes taller than data: shrink height, center vertically
           (let* ((new-ax-h (float (/ ax-w data-aspect) 1.0d0))
                  (y-offset (/ (- ax-h new-ax-h) 2.0d0))
                  (new-bottom-frac (/ (+ ax-bottom-px y-offset) fig-h))
                  (new-height-frac (/ new-ax-h fig-h)))
             (setf (axes-base-position ax)
                   (list left-frac new-bottom-frac width-frac new-height-frac))
             (%setup-transforms ax))))))
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
