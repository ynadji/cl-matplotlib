;;;; interactor.lisp — backend-agnostic zoom/pan/reset state machine.
;;;;
;;;; All limit math runs in SCALED space (view limits pushed through
;;;; axes-base-trans-scale), which makes cursor-anchored zoom and pan
;;;; uniformly correct for linear and log axes; results map back through
;;;; (invert trans-scale) into axes-set-xlim/ylim, so sharex/sharey
;;;; propagation comes along for free.
;;;;
;;;; Pixel coordinates arrive with the TOP-LEFT origin (browser/SDL/CAPI
;;;; native); the figure's display space is bottom-left, so y flips
;;;; against figure-height-px internally.

(in-package #:cl-matplotlib.show)

(defclass interactor ()
  ((figure :initarg :figure :reader interactor-figure)
   (renderer :initform nil :accessor %interactor-renderer)
   (home-limits :initform nil :accessor %interactor-home-limits
                :documentation "List of (axes x0 x1 y0 y1) snapshotted after the first render.")
   (drag :initform nil :accessor %interactor-drag
         :documentation "Active pan: (axes x0-px y0-px sxmin sxmax symin symax), limits in scaled space at drag start.")
   (saved-layout-engine :initform nil :accessor %interactor-saved-layout-engine)
   (first-render-done-p :initform nil :accessor %interactor-first-render-done-p)
   (lock :initform (bt:make-lock "interactor") :reader %interactor-lock))
  (:documentation "Holds per-figure interaction state. Public operations
are serialized by an internal lock (adapters may call from several
threads; Vecto's canvas state is bound per render anyway)."))

(defun make-interactor (figure)
  "Create an interactor for FIGURE."
  (make-instance 'interactor :figure figure))

;;; ============================================================
;;; Rendering — first render settles autoscale + layout, then the
;;; layout engine is frozen so tight-layout can't drift axes positions
;;; between interaction frames.
;;; ============================================================

(defun %render-locked (it grab-fn)
  (let* ((fig (interactor-figure it))
         (renderer (setf (%interactor-renderer it)
                         (%ensure-renderer fig (%interactor-renderer it))))
         (result (%render-figure-grabbing fig renderer grab-fn)))
    (unless (%interactor-first-render-done-p it)
      (setf (%interactor-home-limits it)
            (mapcar (lambda (ax)
                      (multiple-value-bind (x0 x1) (mpl.containers:axes-get-xlim ax)
                        (multiple-value-bind (y0 y1) (mpl.containers:axes-get-ylim ax)
                          (list ax x0 x1 y0 y1))))
                    (mpl.containers:figure-axes fig)))
      (setf (%interactor-saved-layout-engine it)
            (mpl.containers:figure-get-layout-engine fig))
      (mpl.containers:figure-set-layout-engine fig :none)
      (setf (%interactor-first-render-done-p it) t))
    (values result
            (mpl.backends:renderer-width renderer)
            (mpl.backends:renderer-height renderer))))

(defun %ensure-first-render (it)
  "Geometry (axes positions, autoscaled limits) is only settled after a
draw; run a throwaway render if none has happened yet."
  (unless (%interactor-first-render-done-p it)
    (%render-locked it (constantly nil))))

(defun interactor-render-rgba (it)
  "Render the figure; (values rgba-octets width height)."
  (bt:with-lock-held ((%interactor-lock it))
    (%render-locked it #'%grab-rgba)))

(defun interactor-render-png (it)
  "Render the figure; (values png-octets width height)."
  (bt:with-lock-held ((%interactor-lock it))
    (%render-locked it #'%grab-png)))

;;; ============================================================
;;; Geometry
;;; ============================================================

(defun %axes-pixel-bbox (it ax)
  "(values x0 y0 width height) of AX in display pixels (bottom-left
origin), from its position fractions — the settled post-layout value."
  (let* ((fig (interactor-figure it))
         (pos (mpl.containers:axes-base-position ax))
         (fw (float (mpl.containers:figure-width-px fig) 1.0d0))
         (fh (float (mpl.containers:figure-height-px fig) 1.0d0)))
    (values (* (first pos) fw)
            (* (second pos) fh)
            (* (third pos) fw)
            (* (fourth pos) fh))))

(defun %hit-axes (it x-px y-px)
  "The topmost axes whose pixel bbox contains the (top-left origin)
point, or NIL."
  (let* ((fig (interactor-figure it))
         (y-fig (- (mpl.containers:figure-height-px fig) y-px)))
    ;; figure-axes is in creation order; later axes draw on top
    (dolist (ax (reverse (mpl.containers:figure-axes fig)))
      (multiple-value-bind (ax0 ay0 aw ah) (%axes-pixel-bbox it ax)
        (when (and (<= ax0 x-px (+ ax0 aw))
                   (<= ay0 y-fig (+ ay0 ah)))
          (return ax))))))

(defun interactor-hit-axes (it x-px y-px)
  "The axes under pixel (X-PX, Y-PX) (top-left origin), or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (%hit-axes it x-px y-px)))

;;; ============================================================
;;; Scaled-space limit access
;;; ============================================================

(defun %scaled-lims (ax)
  "(values sxmin sxmax symin symax) — view limits in scaled space."
  (let ((tr (mpl.containers:axes-base-trans-scale ax)))
    (multiple-value-bind (x0 x1) (mpl.containers:axes-get-xlim ax)
      (multiple-value-bind (y0 y1) (mpl.containers:axes-get-ylim ax)
        (let ((p0 (mpl.primitives:transform-point tr (list x0 y0)))
              (p1 (mpl.primitives:transform-point tr (list x1 y1))))
          (values (elt p0 0) (elt p1 0) (elt p0 1) (elt p1 1)))))))

(defun %set-lims-from-scaled (ax sxmin sxmax symin symax)
  "Set AX view limits from scaled-space values (inverse of %scaled-lims)."
  (let* ((inv (mpl.primitives:invert (mpl.containers:axes-base-trans-scale ax)))
         (p0 (mpl.primitives:transform-point inv (list sxmin symin)))
         (p1 (mpl.primitives:transform-point inv (list sxmax symax))))
    (mpl.containers:axes-set-xlim ax :min (elt p0 0) :max (elt p1 0))
    (mpl.containers:axes-set-ylim ax :min (elt p0 1) :max (elt p1 1))))

;;; ============================================================
;;; Zoom / pan / reset / cursor
;;; ============================================================

(defun interactor-zoom (it x-px y-px factor)
  "Zoom the axes under the cursor by FACTOR (> 1 zooms in), anchored at
the cursor: the data point under the pixel stays under it. Returns the
axes zoomed, or NIL when the cursor is outside every axes."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when ax
        (multiple-value-bind (ax0 ay0 aw ah) (%axes-pixel-bbox it ax)
          (let* ((fig (interactor-figure it))
                 (y-fig (- (mpl.containers:figure-height-px fig) y-px))
                 (fx (/ (- x-px ax0) aw))
                 (fy (/ (- y-fig ay0) ah)))
            (multiple-value-bind (sxmin sxmax symin symax) (%scaled-lims ax)
              (let* ((f (float factor 1.0d0))
                     (cx (+ sxmin (* fx (- sxmax sxmin))))
                     (cy (+ symin (* fy (- symax symin)))))
                (%set-lims-from-scaled
                 ax
                 (- cx (/ (- cx sxmin) f)) (+ cx (/ (- sxmax cx) f))
                 (- cy (/ (- cy symin) f)) (+ cy (/ (- symax cy) f)))))))
        ax))))

(defun interactor-pan-start (it x-px y-px)
  "Begin a drag pan at the pixel. Returns the axes grabbed, or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when ax
        (multiple-value-bind (sxmin sxmax symin symax) (%scaled-lims ax)
          (setf (%interactor-drag it)
                (list ax x-px y-px sxmin sxmax symin symax))))
      ax)))

(defun interactor-pan-move (it x-px y-px)
  "Continue a drag pan. Limits are recomputed from the drag-start
snapshot each move (no incremental error). Returns the axes, or NIL
when no drag is active."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((drag (%interactor-drag it)))
      (when drag
        (destructuring-bind (ax x0 y0 sxmin sxmax symin symax) drag
          (multiple-value-bind (ax0 ay0 aw ah) (%axes-pixel-bbox it ax)
            (declare (ignore ax0 ay0))
            ;; Content follows the cursor: view limits shift opposite the
            ;; drag. Mouse y grows downward, display y upward, so the y
            ;; shift keeps the raw (y-px - y0) sign.
            (let ((dx (* (- (/ (- x-px x0) aw)) (- sxmax sxmin)))
                  (dy (* (/ (- y-px y0) ah) (- symax symin))))
              (%set-lims-from-scaled ax
                                     (+ sxmin dx) (+ sxmax dx)
                                     (+ symin dy) (+ symax dy))))
          ax)))))

(defun interactor-pan-end (it)
  "End the drag pan. Returns the axes that was dragged, or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((drag (%interactor-drag it)))
      (setf (%interactor-drag it) nil)
      (first drag))))

(defun interactor-reset (it)
  "Restore every axes to its home limits (the autoscaled limits captured
after the first render) — matplotlib's Home button."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (dolist (entry (%interactor-home-limits it))
      (destructuring-bind (ax x0 x1 y0 y1) entry
        (mpl.containers:axes-set-xlim ax :min x0 :max x1)
        (mpl.containers:axes-set-ylim ax :min y0 :max y1)))
    (values)))

(defun interactor-cursor-coords (it x-px y-px)
  "Data coordinates under the pixel: (values x-data y-data axes), or NIL
outside every axes. Goes through (invert trans-data) so log scales read
correctly."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when ax
        (let* ((fig (interactor-figure it))
               (y-fig (- (mpl.containers:figure-height-px fig) y-px))
               (inv (mpl.primitives:invert
                     (mpl.containers:axes-base-trans-data ax)))
               (p (mpl.primitives:transform-point
                   inv (list (float x-px 1.0d0) (float y-fig 1.0d0)))))
          (values (elt p 0) (elt p 1) ax))))))

(defun interactor-resize (it width-px height-px)
  "Resize the figure to WIDTH-PX x HEIGHT-PX: restore the original
layout engine, resize, render once so layout settles at the new size,
then re-freeze. View limits are preserved (matplotlib behavior)."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let* ((fig (interactor-figure it))
           (dpi (mpl.containers:figure-dpi fig)))
      (mpl.containers:figure-set-layout-engine
       fig (%interactor-saved-layout-engine it))
      (mpl.containers:figure-set-size-inches
       fig (/ width-px dpi) (/ height-px dpi))
      (%render-figure-grabbing fig
                               (setf (%interactor-renderer it)
                                     (%ensure-renderer fig (%interactor-renderer it)))
                               (constantly nil))
      (mpl.containers:figure-set-layout-engine fig :none))
    (values)))
