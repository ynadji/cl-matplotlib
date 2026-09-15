;;;; interactor.lisp — backend-agnostic zoom/pan/rotate/reset state machine.
;;;;
;;;; All limit math runs in SCALED space (view limits pushed through
;;;; axes-base-trans-scale), which makes cursor-anchored zoom and pan
;;;; uniformly correct for linear and log axes; results map back through
;;;; (invert trans-scale) into axes-set-xlim/ylim, so sharex/sharey
;;;; propagation comes along for free.
;;;;
;;;; A 3D axes (axes-3d) rotates instead of panning: a drag changes the
;;;; camera's elevation and azimuth (Axes3D._on_move), and the wheel
;;;; scales the projected view window about its center. Its home state
;;;; is the view angles plus that window.
;;;;
;;;; Pixel coordinates arrive with the TOP-LEFT origin (browser/SDL/CAPI
;;;; native); the figure's display space is bottom-left, so y flips
;;;; against figure-height-px internally.
;;;;
;;;; Interaction feedback (the selected trace's highlight, pinned data
;;;; cursors) is drawn as an overlay after the figure, never by mutating
;;;; artists; see pick.lisp / commands.lisp / events.lisp for hit
;;;; testing, the clipboard and the event dispatcher.

(in-package #:cl-matplotlib.show)

(defclass interactor ()
  ((figure :initarg :figure :reader interactor-figure)
   (renderer :initform nil :accessor %interactor-renderer)
   (home-limits :initform nil :accessor %interactor-home-limits
                :documentation "Per axes, snapshotted after the first render: (axes :2d x0 x1 y0 y1) or (axes :3d elev azim roll view-lim).")
   (drag :initform nil :accessor %interactor-drag
         :documentation "Active drag: (:pan axes x0-px y0-px sxmin sxmax symin symax), (:rotate axes x0-px y0-px elev azim roll) or (:pan3d axes x0-px y0-px view-lim).")
   (saved-layout-engine :initform nil :accessor %interactor-saved-layout-engine)
   (first-render-done-p :initform nil :accessor %interactor-first-render-done-p)
   (mode :initform :pan :accessor interactor-mode
         :documentation ":pan (drag pans/rotates, click selects a trace) or :cursor (click pins a data cursor).")
   (selection :initform nil :accessor interactor-selection
              :documentation "The selected artist (a line), or NIL.")
   (pins :initform nil :accessor interactor-pins
         :documentation "Pinned data cursors: list of (artist index).")
   (history :initform nil :accessor %interactor-history
            :documentation "Undo stack of commands (most recent first).")
   (redo :initform nil :accessor %interactor-redo)
   (lock :initform (bt:make-lock "interactor") :reader %interactor-lock))
  (:documentation "Holds per-figure interaction state. Public operations
are serialized by an internal lock (adapters may call from several
threads; Vecto's canvas state is bound per render anyway)."))

(defun make-interactor (figure)
  "Create an interactor for FIGURE."
  (make-instance 'interactor :figure figure))

(defun %axes-3d-p (ax)
  (typep ax 'mpl.containers:axes-3d))

;;; ============================================================
;;; Rendering — first render settles autoscale + layout, then the
;;; layout engine is frozen so tight-layout can't drift axes positions
;;; between interaction frames.
;;; ============================================================

(defun %home-entry (ax)
  (if (%axes-3d-p ax)
      (list ax :3d
            (mpl.containers:axes-3d-elev ax)
            (mpl.containers:axes-3d-azim ax)
            (mpl.containers:axes-3d-roll ax)
            (mpl.containers:axes-base-view-lim ax))
      (multiple-value-bind (x0 x1) (mpl.containers:axes-get-xlim ax)
        (multiple-value-bind (y0 y1) (mpl.containers:axes-get-ylim ax)
          (list ax :2d x0 x1 y0 y1)))))

(defun %render-locked (it grab-fn)
  (let* ((fig (interactor-figure it))
         (renderer (setf (%interactor-renderer it)
                         (%ensure-renderer fig (%interactor-renderer it))))
         (result (%render-figure-grabbing
                  fig renderer grab-fn
                  :overlay-fn (lambda (r) (%interactor-draw-overlay it r)))))
    (unless (%interactor-first-render-done-p it)
      (setf (%interactor-home-limits it)
            (mapcar #'%home-entry (mpl.containers:figure-axes fig)))
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

(defun %figure-y (it y-px)
  "Display y (bottom-left origin) for a top-left-origin pixel row."
  (- (mpl.containers:figure-height-px (interactor-figure it)) y-px))

(defun %hit-axes (it x-px y-px)
  "The topmost axes whose pixel bbox contains the (top-left origin)
point, or NIL."
  (let* ((fig (interactor-figure it))
         (y-fig (%figure-y it y-px)))
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
;;; 3D helpers — the projected view window is the axes' 2D view-lim
;;; ============================================================

(defun %scale-view-window (ax factor)
  "Shrink (FACTOR > 1) or grow the 3D axes' projected window about its
center — the zoom of a 3D axes, which leaves its data limits and ticks
alone (matplotlib zooms 3D by moving the camera)."
  (let* ((v (mpl.containers:axes-base-view-lim ax))
         (x0 (mpl.primitives:bbox-x0 v)) (x1 (mpl.primitives:bbox-x1 v))
         (y0 (mpl.primitives:bbox-y0 v)) (y1 (mpl.primitives:bbox-y1 v))
         (cx (/ (+ x0 x1) 2)) (cy (/ (+ y0 y1) 2))
         (hw (/ (- x1 x0) 2 factor)) (hh (/ (- y1 y0) 2 factor)))
    (setf (mpl.containers:axes-base-view-lim ax)
          (mpl.primitives:make-bbox (- cx hw) (- cy hh) (+ cx hw) (+ cy hh)))
    (mpl.containers::%update-trans-data ax)
    (setf (mpl.rendering:artist-stale ax) t)))

(defun %shift-view-window (ax view-lim dx-frac dy-frac)
  "Pan the 3D axes' projected window by a fraction of its size."
  (let* ((w (- (mpl.primitives:bbox-x1 view-lim) (mpl.primitives:bbox-x0 view-lim)))
         (h (- (mpl.primitives:bbox-y1 view-lim) (mpl.primitives:bbox-y0 view-lim)))
         (dx (* dx-frac w)) (dy (* dy-frac h)))
    (setf (mpl.containers:axes-base-view-lim ax)
          (mpl.primitives:make-bbox (+ (mpl.primitives:bbox-x0 view-lim) dx)
                                    (+ (mpl.primitives:bbox-y0 view-lim) dy)
                                    (+ (mpl.primitives:bbox-x1 view-lim) dx)
                                    (+ (mpl.primitives:bbox-y1 view-lim) dy)))
    (mpl.containers::%update-trans-data ax)
    (setf (mpl.rendering:artist-stale ax) t)))

;;; ============================================================
;;; Zoom / pan / rotate / reset / cursor
;;; ============================================================

(defun interactor-zoom (it x-px y-px factor)
  "Zoom the axes under the cursor by FACTOR (> 1 zooms in), anchored at
the cursor: the data point under the pixel stays under it. A 3D axes
zooms about its center. Returns the axes zoomed, or NIL when the cursor
is outside every axes."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when ax
        (if (%axes-3d-p ax)
            (%scale-view-window ax (float factor 1.0d0))
            (multiple-value-bind (ax0 ay0 aw ah) (%axes-pixel-bbox it ax)
              (let* ((y-fig (%figure-y it y-px))
                     (fx (/ (- x-px ax0) aw))
                     (fy (/ (- y-fig ay0) ah)))
                (multiple-value-bind (sxmin sxmax symin symax) (%scaled-lims ax)
                  (let* ((f (float factor 1.0d0))
                         (cx (+ sxmin (* fx (- sxmax sxmin))))
                         (cy (+ symin (* fy (- symax symin)))))
                    (%set-lims-from-scaled
                     ax
                     (- cx (/ (- cx sxmin) f)) (+ cx (/ (- sxmax cx) f))
                     (- cy (/ (- cy symin) f)) (+ cy (/ (- symax cy) f)))))))))
      ax)))

(defun interactor-pan-start (it x-px y-px &key shift)
  "Begin a drag at the pixel: a pan on a 2D axes, a rotation on a 3D
axes (or a pan of its view with SHIFT). Returns the axes grabbed, or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when ax
        (setf (%interactor-drag it)
              (cond ((and (%axes-3d-p ax) shift)
                     (list :pan3d ax x-px y-px (mpl.containers:axes-base-view-lim ax)))
                    ((%axes-3d-p ax)
                     (list :rotate ax x-px y-px
                           (mpl.containers:axes-3d-elev ax)
                           (mpl.containers:axes-3d-azim ax)
                           (mpl.containers:axes-3d-roll ax)))
                    (t
                     (multiple-value-bind (sxmin sxmax symin symax) (%scaled-lims ax)
                       (list :pan ax x-px y-px sxmin sxmax symin symax))))))
      ax)))

(defun interactor-pan-move (it x-px y-px)
  "Continue a drag. Limits (or view angles) are recomputed from the
drag-start snapshot each move (no incremental error). Returns the axes,
or NIL when no drag is active."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((drag (%interactor-drag it)))
      (when drag
        (ecase (first drag)
          (:pan
           (destructuring-bind (ax x0 y0 sxmin sxmax symin symax) (rest drag)
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
             ax))
          (:rotate
           (destructuring-bind (ax x0 y0 elev0 azim0 roll0) (rest drag)
             (multiple-value-bind (ax0 ay0 aw ah) (%axes-pixel-bbox it ax)
               (declare (ignore ax0 ay0))
               ;; Axes3D._on_move: dx, dy as fractions of the axes box
               ;; (display y up, so the pixel dy is negated).
               (let* ((dx (/ (- x-px x0) aw))
                      (dy (/ (- (- y-px y0)) ah))
                      (roll (* (/ pi 180) roll0))
                      (delev (+ (* (- dy) 180 (cos roll)) (* dx 180 (sin roll))))
                      (dazim (- (* (- dy) 180 (sin roll)) (* dx 180 (cos roll)))))
                 (mpl.containers:view-init ax
                                           :elev (mpl.primitives:norm-angle (+ elev0 delev))
                                           :azim (mpl.primitives:norm-angle (+ azim0 dazim)))))
             ax))
          (:pan3d
           (destructuring-bind (ax x0 y0 view-lim) (rest drag)
             (multiple-value-bind (ax0 ay0 aw ah) (%axes-pixel-bbox it ax)
               (declare (ignore ax0 ay0))
               (%shift-view-window ax view-lim
                                   (- (/ (- x-px x0) aw))
                                   (/ (- y-px y0) ah)))
             ax)))))))

(defun interactor-pan-end (it)
  "End the drag. Returns the axes that was dragged, or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((drag (%interactor-drag it)))
      (setf (%interactor-drag it) nil)
      (second drag))))

(defun interactor-rotate-start (it x-px y-px)
  "Begin a rotation drag on the 3D axes under the pixel (same as
interactor-pan-start on a 3D axes)."
  (interactor-pan-start it x-px y-px))

(defun interactor-rotate-move (it x-px y-px)
  "Continue a rotation drag (same as interactor-pan-move)."
  (interactor-pan-move it x-px y-px))

(defun interactor-reset (it)
  "Restore every axes to its home state (limits, or view angles and
window for a 3D axes) captured after the first render — matplotlib's
Home button."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (dolist (entry (%interactor-home-limits it))
      (ecase (second entry)
        (:2d (destructuring-bind (ax x0 x1 y0 y1) (cons (first entry) (cddr entry))
               (mpl.containers:axes-set-xlim ax :min x0 :max x1)
               (mpl.containers:axes-set-ylim ax :min y0 :max y1)))
        (:3d (destructuring-bind (ax elev azim roll view-lim) (cons (first entry) (cddr entry))
               (mpl.containers:view-init ax :elev elev :azim azim :roll roll)
               (setf (mpl.containers:axes-base-view-lim ax) view-lim)
               (mpl.containers::%update-trans-data ax)))))
    (values)))

(defun interactor-cursor-coords (it x-px y-px)
  "Data coordinates under the pixel: (values x-data y-data axes), or NIL
outside every axes or over a 3D axes (whose pixels do not map to a data
point). Goes through (invert trans-data) so log scales read correctly."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when (and ax (not (%axes-3d-p ax)))
        (let* ((y-fig (%figure-y it y-px))
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

;;; ============================================================
;;; Selection, pins and the overlay
;;; ============================================================

(defun interactor-select (it artist)
  "Make ARTIST the selection (NIL clears it)."
  (bt:with-lock-held ((%interactor-lock it))
    (setf (interactor-selection it) artist)))

(defun interactor-clear-selection (it)
  (interactor-select it nil))

(defun interactor-pin-point (it artist index)
  "Pin a data cursor at vertex INDEX of ARTIST."
  (bt:with-lock-held ((%interactor-lock it))
    (pushnew (list artist index) (interactor-pins it) :test #'equal)))

(defun interactor-clear-pins (it)
  (bt:with-lock-held ((%interactor-lock it))
    (setf (interactor-pins it) nil)))

(defun %artist-display-points (artist)
  "The vertices of a line artist in display pixels (bottom-left origin),
as a list of (x . y). For a 3D line these are its last projection."
  (when (and (typep artist 'mpl.rendering:line-2d)
             (mpl.rendering:artist-visible artist))
    (let ((tr (mpl.rendering:get-artist-transform artist)))
      (map 'list (lambda (x y)
                   (let ((p (mpl.primitives:transform-point tr (list (float x 1.0d0) (float y 1.0d0)))))
                     (cons (elt p 0) (elt p 1))))
           (mpl.rendering:line-2d-xdata artist)
           (mpl.rendering:line-2d-ydata artist)))))

(defun %artist-data-point (artist index)
  "(values x y z) of vertex INDEX in data coordinates; Z is NIL for a 2D line."
  (if (typep artist 'mpl.rendering:line-3d)
      (values (elt (mpl.rendering:line-3d-xs artist) index)
              (elt (mpl.rendering:line-3d-ys artist) index)
              (elt (mpl.rendering:line-3d-zs artist) index))
      (values (elt (mpl.rendering:line-2d-xdata artist) index)
              (elt (mpl.rendering:line-2d-ydata artist) index)
              nil)))

(defun %interactor-draw-overlay (it renderer)
  "Selection highlight and pinned cursors, drawn on top of the figure."
  (let ((sel (interactor-selection it)))
    (when (and sel (typep sel 'mpl.rendering:line-2d))
      (let ((pts (%artist-display-points sel)))
        (when (>= (length pts) 2)
          (let* ((n (length pts))
                 (verts (make-array (list n 2) :element-type 'double-float))
                 (rgba (mpl.colors:to-rgba (mpl.rendering:line-2d-color sel)))
                 (lw (+ 4.0 (float (mpl.rendering:line-2d-linewidth sel) 1.0)))
                 (gc (mpl.backends:make-graphics-context
                      :facecolor nil
                      :edgecolor (list (float (elt rgba 0) 1.0) (float (elt rgba 1) 1.0)
                                       (float (elt rgba 2) 1.0) 0.35)
                      :linewidth lw :capstyle :round :joinstyle :round)))
            (loop for (x . y) in pts for i from 0
                  do (setf (aref verts i 0) (float x 1.0d0) (aref verts i 1) (float y 1.0d0)))
            (mpl.backends:draw-path renderer gc (mpl.primitives:make-path :vertices verts) nil nil))))))
  (dolist (pin (interactor-pins it))
    (destructuring-bind (artist index) pin
      (let ((pts (%artist-display-points artist)))
        (when (< index (length pts))
          (destructuring-bind (px . py) (nth index pts)
            (multiple-value-bind (x y z) (%artist-data-point artist index)
              (let* ((rgba (mpl.colors:to-rgba (mpl.rendering:line-2d-color artist)))
                     (edge (list (float (elt rgba 0) 1.0) (float (elt rgba 1) 1.0)
                                 (float (elt rgba 2) 1.0) 1.0))
                     (gc (mpl.backends:make-graphics-context
                          :facecolor '(1.0 1.0 1.0 1.0) :edgecolor edge :linewidth 1.5))
                     (circle (mpl.primitives:path-unit-circle))
                     (tr (mpl.primitives:make-affine-2d :scale (list 4.0d0 4.0d0)
                                                        :translate (list (float px 1.0d0) (float py 1.0d0))))
                     (label (if z
                                (format nil "x=~,4G y=~,4G z=~,4G" x y z)
                                (format nil "x=~,4G y=~,4G" x y)))
                     (txt (make-instance 'mpl.rendering:text-artist
                                         :x (+ (float px 1.0d0) 8.0d0) :y (+ (float py 1.0d0) 8.0d0)
                                         :text label :fontsize 9.0 :color "black"
                                         :horizontalalignment :left :verticalalignment :bottom)))
                (mpl.backends:draw-path renderer gc circle tr '(1.0 1.0 1.0 1.0))
                (setf (mpl.rendering:artist-transform txt) (mpl.primitives:make-identity-transform))
                (mpl.rendering:draw txt renderer)))))))))
