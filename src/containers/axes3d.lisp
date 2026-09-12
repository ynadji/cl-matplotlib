;;;; axes3d.lisp — axes-3d: the :3d projection.
;;;; Port of mpl_toolkits/mplot3d/axes3d.py (matplotlib 3.8.4), the parts
;;;; behind projection='3d', view_init, the z limits and Axes3D.draw.
;;;;
;;;; How it fits the 2D machinery ("top view", Axes3D.set_top_view): the
;;;; axes' ordinary view-lim is pinned to the window x,y ∈ (-0.095, 0.09)
;;;; that Axes3D.get_proj projects into, so transData maps projected view
;;;; coordinates to pixels and every 2D artist draw, clip and hit test
;;;; works unchanged. The 3D limits live in their own slots; the x/y limit
;;;; functions are generic and dispatch here.
;;;;
;;;; Per draw (Axes3D.draw): square the box (apply_aspect), recompute
;;;; transforms, compute M, ask every 3D artist to project itself and
;;;; order them back to front, then draw panes, grids, axes, artists,
;;;; legend.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Class
;;; ============================================================

(defclass axes-3d (axes-base)
  ((elev :initarg :elev :initform 30.0d0 :accessor axes-3d-elev)
   (azim :initarg :azim :initform -60.0d0 :accessor axes-3d-azim)
   (roll :initarg :roll :initform 0.0d0 :accessor axes-3d-roll)
   (box-aspect :initarg :box-aspect :initform (mpl.primitives:default-box-aspect)
               :accessor axes-3d-box-aspect
               :documentation "vec3 plot-box aspect (Axes3D._box_aspect); default (4,4,3) scaled.")
   (dist :initarg :dist :initform 10.0d0 :accessor axes-3d-dist)
   (focal-length :initarg :focal-length :initform 1.0d0 :accessor axes-3d-focal-length
                 :documentation "Perspective focal length; NIL for an orthographic projection.")
   (proj-matrix :initform nil :accessor axes-3d-proj-matrix
                :documentation "mat4 of the last draw (Axes3D.M).")
   (inv-proj-matrix :initform nil :accessor axes-3d-inv-proj-matrix)
   (xy-view-lim :initform (mpl.primitives:make-bbox 0.0d0 0.0d0 1.0d0 1.0d0)
                :accessor axes-3d-xy-view-lim
                :documentation "3D x/y view limits (Axes3D.xy_viewLim).")
   (z-view-lim :initform (cons 0.0d0 1.0d0) :accessor axes-3d-z-view-lim
               :documentation "(zmin . zmax) view limits (Axes3D.zz_viewLim).")
   (xy-data-lim :initform (mpl.primitives:bbox-null) :accessor axes-3d-xy-data-lim)
   (z-data-lim :initform nil :accessor axes-3d-z-data-lim
               :documentation "(zmin . zmax) of the data, or NIL before any data.")
   (autoscale-z-p :initform t :accessor axes-3d-autoscale-z-p)
   (zmargin :initform 0.0d0 :accessor axes-3d-zmargin
            :documentation "Autoscale margin for z. Axes3D starts at 0 (unlike rc axes.zmargin); scatter raises it to 0.05.")
   (zaxis :initform nil :accessor axes-3d-zaxis)
   (grid-on :initarg :grid :initform t :accessor axes-3d-grid-on
            :documentation "Draw grid lines on the panes (rc axes3d.grid, default T).")
   (axis3d-on :initform t :accessor axes-3d-axis-on
              :documentation "Draw panes, grids and axes (Axes3D.set_axis_on/off).")
   (computed-zorder :initarg :computed-zorder :initform t :accessor axes-3d-computed-zorder)
   (original-position :initform nil :accessor %axes-3d-original-position)
   (applied-position :initform nil :accessor %axes-3d-applied-position))
  (:documentation "A 3D axes (projection :3d)."))

(defconstant +axes3d-top-view-lo+ -0.095d0 "−0.95/dist for the default dist of 10")
(defconstant +axes3d-top-view-hi+ 0.09d0 "0.9/dist")

(defmethod initialize-instance :after ((ax axes-3d) &key)
  ;; the 2D window every projection lands in
  (setf (axes-base-view-lim ax)
        (mpl.primitives:make-bbox +axes3d-top-view-lo+ +axes3d-top-view-lo+
                                  +axes3d-top-view-hi+ +axes3d-top-view-hi+))
  ;; 3D axes replace the rectilinear x/y axes and add z
  (setf (axes-base-xaxis ax) (make-instance 'axis-3d :axes ax :index 0)
        (axes-base-yaxis ax) (make-instance 'axis-3d :axes ax :index 1)
        (axes-3d-zaxis ax) (make-instance 'axis-3d :axes ax :index 2))
  ;; no spines, and the background patch has no edge
  (setf (axes-base-spines ax) nil)
  (when (axes-base-patch ax)
    (setf (mpl.rendering:patch-linewidth (axes-base-patch ax)) 0.0
          (mpl.rendering:patch-edgecolor (axes-base-patch ax)) nil))
  (%update-trans-data ax))

;;; ============================================================
;;; Limits — the 2D generics dispatch here
;;; ============================================================

(defmethod axes-get-xlim ((ax axes-3d))
  (let ((v (axes-3d-xy-view-lim ax)))
    (values (mpl.primitives:bbox-x0 v) (mpl.primitives:bbox-x1 v))))

(defmethod axes-get-ylim ((ax axes-3d))
  (let ((v (axes-3d-xy-view-lim ax)))
    (values (mpl.primitives:bbox-y0 v) (mpl.primitives:bbox-y1 v))))

(defun axes-get-zlim (ax)
  "Return (values zmin zmax) of an axes-3d."
  (let ((z (axes-3d-z-view-lim ax)))
    (values (car z) (cdr z))))

(defmethod axes-set-xlim ((ax axes-3d) &key min max)
  (let ((v (axes-3d-xy-view-lim ax)))
    (setf (axes-3d-xy-view-lim ax)
          (mpl.primitives:make-bbox (if min (float min 1.0d0) (mpl.primitives:bbox-x0 v))
                                    (mpl.primitives:bbox-y0 v)
                                    (if max (float max 1.0d0) (mpl.primitives:bbox-x1 v))
                                    (mpl.primitives:bbox-y1 v)))
    (when (or min max) (setf (axes-base-autoscale-x-p ax) nil))
    (setf (mpl.rendering:artist-stale ax) t)
    (values)))

(defmethod axes-set-ylim ((ax axes-3d) &key min max)
  (let ((v (axes-3d-xy-view-lim ax)))
    (setf (axes-3d-xy-view-lim ax)
          (mpl.primitives:make-bbox (mpl.primitives:bbox-x0 v)
                                    (if min (float min 1.0d0) (mpl.primitives:bbox-y0 v))
                                    (mpl.primitives:bbox-x1 v)
                                    (if max (float max 1.0d0) (mpl.primitives:bbox-y1 v))))
    (when (or min max) (setf (axes-base-autoscale-y-p ax) nil))
    (setf (mpl.rendering:artist-stale ax) t)
    (values)))

(defun axes-set-zlim (ax &key min max)
  "Set the z view limits of an axes-3d; a limit left NIL is unchanged.
Setting either turns z autoscaling off."
  (let ((z (axes-3d-z-view-lim ax)))
    (setf (axes-3d-z-view-lim ax)
          (cons (if min (float min 1.0d0) (car z))
                (if max (float max 1.0d0) (cdr z))))
    (when (or min max) (setf (axes-3d-autoscale-z-p ax) nil))
    (setf (mpl.rendering:artist-stale ax) t)
    (values)))

(defun axes-3d-xy-data-interval (ax index)
  "(values lo hi) of the x (INDEX 0) or y (1) data limits, or the view limits before any data."
  (let ((d (axes-3d-xy-data-lim ax)))
    (if (mpl.primitives:bbox-null-p d)
        (if (zerop index) (axes-get-xlim ax) (axes-get-ylim ax))
        (if (zerop index)
            (values (mpl.primitives:bbox-x0 d) (mpl.primitives:bbox-x1 d))
            (values (mpl.primitives:bbox-y0 d) (mpl.primitives:bbox-y1 d))))))

(defun axes-3d-z-data-interval (ax)
  (let ((d (axes-3d-z-data-lim ax)))
    (if d (values (car d) (cdr d)) (axes-get-zlim ax))))

(defun %nonsingular (lo hi)
  "Expand a degenerate interval the way matplotlib's locator.nonsingular does."
  (cond ((< hi lo) (%nonsingular hi lo))
        ((= lo hi)
         (if (zerop lo)
             (values -0.001d0 0.001d0)
             (let ((d (* 0.001d0 (abs lo)))) (values (- lo d) (+ lo d)))))
        (t (values lo hi))))

(defun %seq-min-max (seq)
  "(values min max) over the finite numbers of SEQ (any sequence, possibly nested lists/arrays), or NIL."
  (let ((lo nil) (hi nil))
    (labels ((visit (v)
               (cond ((numberp v)
                      (let ((f (float v 1.0d0)))
                        (when (or (null lo) (< f lo)) (setf lo f))
                        (when (or (null hi) (> f hi)) (setf hi f))))
                     ((arrayp v) (dotimes (i (array-total-size v)) (visit (row-major-aref v i))))
                     ((listp v) (dolist (e v) (visit e))))))
      (visit seq))
    (if lo (values lo hi) nil)))

(defun axes-3d-auto-scale-xyz (ax xs ys zs)
  "Grow the 3D data limits by XS YS ZS (sequences or arrays, any nesting)
and re-autoscale the view limits (Axes3D.auto_scale_xyz + autoscale_view)."
  (multiple-value-bind (xlo xhi) (%seq-min-max xs)
    (multiple-value-bind (ylo yhi) (%seq-min-max ys)
      (when (and xlo ylo)
        (let ((d (axes-3d-xy-data-lim ax)))
          (setf (axes-3d-xy-data-lim ax)
                (if (mpl.primitives:bbox-null-p d)
                    (mpl.primitives:make-bbox xlo ylo xhi yhi)
                    (mpl.primitives:make-bbox (min xlo (mpl.primitives:bbox-x0 d))
                                              (min ylo (mpl.primitives:bbox-y0 d))
                                              (max xhi (mpl.primitives:bbox-x1 d))
                                              (max yhi (mpl.primitives:bbox-y1 d)))))))))
  (when zs
    (multiple-value-bind (zlo zhi) (%seq-min-max zs)
      (when zlo
        (let ((d (axes-3d-z-data-lim ax)))
          (setf (axes-3d-z-data-lim ax)
                (if d (cons (min zlo (car d)) (max zhi (cdr d))) (cons zlo zhi)))))))
  (axes-3d-autoscale-view ax))

(defun axes-3d-autoscale-view (ax)
  "Set each autoscaled 3D view limit to its data limit padded by the margin
(Axes3D.autoscale_view with the default 'data' autolimit mode)."
  (let ((margin (axes-base-autoscale-margin ax)))
    (flet ((padded (lo hi m)
             (multiple-value-bind (lo hi) (%nonsingular lo hi)
               (let ((delta (* (- hi lo) m)))
                 (values (- lo delta) (+ hi delta))))))
      (let ((d (axes-3d-xy-data-lim ax)))
        (unless (mpl.primitives:bbox-null-p d)
          (let ((v (axes-3d-xy-view-lim ax)))
            (multiple-value-bind (x0 x1)
                (if (axes-base-autoscale-x-p ax)
                    (padded (mpl.primitives:bbox-x0 d) (mpl.primitives:bbox-x1 d) margin)
                    (values (mpl.primitives:bbox-x0 v) (mpl.primitives:bbox-x1 v)))
              (multiple-value-bind (y0 y1)
                  (if (axes-base-autoscale-y-p ax)
                      (padded (mpl.primitives:bbox-y0 d) (mpl.primitives:bbox-y1 d) margin)
                      (values (mpl.primitives:bbox-y0 v) (mpl.primitives:bbox-y1 v)))
                (setf (axes-3d-xy-view-lim ax) (mpl.primitives:make-bbox x0 y0 x1 y1)))))))
      (let ((d (axes-3d-z-data-lim ax)))
        (when (and d (axes-3d-autoscale-z-p ax))
          (multiple-value-bind (z0 z1) (padded (car d) (cdr d) (axes-3d-zmargin ax))
            (setf (axes-3d-z-view-lim ax) (cons z0 z1)))))))
  (setf (mpl.rendering:artist-stale ax) t))

;;; ============================================================
;;; View
;;; ============================================================

(defun view-init (ax &key elev azim roll)
  "Set the camera elevation, azimuth and roll (degrees) of an axes-3d;
an angle left NIL keeps its value (Axes3D.view_init). Returns AX."
  (when elev (setf (axes-3d-elev ax) (float elev 1.0d0)))
  (when azim (setf (axes-3d-azim ax) (float azim 1.0d0)))
  (when roll (setf (axes-3d-roll ax) (float roll 1.0d0)))
  (setf (mpl.rendering:artist-stale ax) t)
  ax)

(defun axes-3d-get-proj (ax)
  "The projection matrix for the current view and limits (Axes3D.get_proj)."
  (multiple-value-bind (xmin xmax) (axes-get-xlim ax)
    (multiple-value-bind (ymin ymax) (axes-get-ylim ax)
      (multiple-value-bind (zmin zmax) (axes-get-zlim ax)
        (mpl.primitives:projection-matrix (axes-3d-elev ax) (axes-3d-azim ax) (axes-3d-roll ax)
                                          xmin xmax ymin ymax zmin zmax
                                          :box-aspect (axes-3d-box-aspect ax)
                                          :dist (axes-3d-dist ax)
                                          :focal-length (axes-3d-focal-length ax))))))

(defun axes-set-box-aspect (ax aspect &key (zoom 1.0d0))
  "Set the x:y:z box aspect (a 3-sequence, default 4 4 3) and overall ZOOM."
  (setf (axes-3d-box-aspect ax)
        (mpl.primitives:default-box-aspect
         :aspect (mpl.primitives:vec3 (elt aspect 0) (elt aspect 1) (elt aspect 2))
         :zoom zoom))
  (setf (mpl.rendering:artist-stale ax) t)
  ax)

;;; ============================================================
;;; Labels and ticks
;;; ============================================================

(defun axes-set-zlabel (ax text &key fontsize)
  (axis-set-label-text (axes-3d-zaxis ax) text :fontsize fontsize)
  (setf (mpl.rendering:artist-stale ax) t)
  text)

(defun axes-set-zticks (ax ticks)
  "Fix the z major tick positions."
  (axis-set-major-locator (axes-3d-zaxis ax)
                          (make-instance 'fixed-locator :locs (map 'list (lambda (v) (float v 1.0d0)) ticks)))
  (setf (mpl.rendering:artist-stale ax) t)
  ticks)

;;; ============================================================
;;; apply_aspect — a square active box, anchored at the center
;;; ============================================================

(defun %axes-3d-square-position (ax)
  "Shrink the original position to a square box in display units, centered
(Axes3D.apply_aspect with box_aspect 1 and anchor 'C')."
  (let ((pos (axes-base-position ax)))
    ;; A layout engine (or the user) moved the axes since we last squared:
    ;; take the new rectangle as the original.
    (unless (and (%axes-3d-applied-position ax) (equal pos (%axes-3d-applied-position ax)))
      (setf (%axes-3d-original-position ax) (copy-list pos)))
    (let* ((orig (%axes-3d-original-position ax))
           (fig (axes-base-figure ax))
           (fig-w (if fig (float (figure-width-px fig) 1.0d0) 640.0d0))
           (fig-h (if fig (float (figure-height-px fig) 1.0d0) 480.0d0))
           (fig-aspect (/ fig-h fig-w))
           (w (third orig)) (h (fourth orig))
           ;; shrunk_to_aspect(1, container=pb, fig_aspect)
           (hh (/ w fig-aspect))
           (ww w))
      (when (> hh h)
        (setf ww (* h fig-aspect) hh h))
      (let ((squared (list (+ (first orig) (* 0.5d0 (- w ww)))
                           (+ (second orig) (* 0.5d0 (- h hh)))
                           ww hh)))
        (setf (axes-base-position ax) squared
              (%axes-3d-applied-position ax) (copy-list squared))))))

;;; ============================================================
;;; Draw
;;; ============================================================

(defun %axes-3d-projectable-p (artist)
  (or (typep artist 'mpl.rendering:line-3d)
      (typep artist 'mpl.rendering:path-3d-collection)
      (typep artist 'mpl.rendering:poly-3d-collection)))

(defmethod mpl.rendering:draw ((ax axes-3d) renderer)
  (unless (mpl.rendering:artist-visible ax)
    (return-from mpl.rendering:draw))
  ;; 1. square box, transforms, projection
  (%axes-3d-square-position ax)
  (%setup-transforms ax)
  (let ((m (axes-3d-get-proj ax)))
    (setf (axes-3d-proj-matrix ax) m
          (axes-3d-inv-proj-matrix ax) (ignore-errors (mpl.primitives:mat4-invert m)))
    ;; 2. every artist draws through transData
    (let ((td (axes-base-trans-data ax)))
      (dolist (group (list (axes-base-patches ax) (axes-base-lines ax) (axes-base-artists ax)))
        (dolist (a group)
          (when (or (%axes-3d-projectable-p a) (null (mpl.rendering:artist-transform a)))
            (setf (mpl.rendering:artist-transform a) td)))))
    ;; 3. project 3D artists and order them back to front
    (let ((projected
            (loop for a in (append (axes-base-patches ax) (axes-base-lines ax) (axes-base-artists ax))
                  when (and (%axes-3d-projectable-p a) (mpl.rendering:artist-visible a))
                    collect (cons (mpl.rendering:do-3d-projection a m) a))))
      (when (axes-3d-computed-zorder ax)
        (let ((zorder 1.0d0))   ; above panes/grids/axes, which are drawn first anyway
          (dolist (entry (stable-sort (remove nil projected :key #'car) #'> :key #'car))
            (setf (mpl.rendering:artist-zorder (cdr entry)) zorder)
            (incf zorder))))))
  ;; 4. background
  (when (and (axes-base-frameon-p ax) (axes-base-patch ax))
    (%draw-axes-background ax renderer))
  ;; 5. panes, grids, axes
  (when (axes-3d-axis-on ax)
    (let ((axes3 (list (axes-base-xaxis ax) (axes-base-yaxis ax) (axes-3d-zaxis ax))))
      (dolist (a axes3) (axis3d-draw-pane a ax renderer))
      (dolist (a axes3) (axis3d-draw-grid a ax renderer))
      (dolist (a axes3) (axis3d-draw a ax renderer))))
  ;; 6. artists in zorder
  (let ((artists (axes-get-all-artists ax)))
    (when (axes-base-patch ax)
      (setf artists (remove (axes-base-patch ax) artists)))
    (dolist (artist artists)
      (when (and (typep artist 'mpl.rendering:artist)
                 (mpl.rendering:artist-visible artist))
        (mpl.rendering:draw artist renderer))))
  ;; 7. legend
  (when (axes-base-legend ax)
    (mpl.rendering:draw (axes-base-legend ax) renderer))
  (setf (mpl.rendering:artist-stale ax) nil))
