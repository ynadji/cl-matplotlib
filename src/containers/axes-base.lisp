;;;; axes-base.lisp — AxesBase class with coordinate system, transforms, data limits
;;;; Ported from matplotlib's axes/_base.py _AxesBase
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; AxesBase — base class for all Axes types
;;; ============================================================

(defclass axes-base (mpl.rendering:artist)
  ((axes-figure :initarg :figure
                :initform nil
                :accessor axes-base-figure
                :documentation "Parent figure for this axes.")
   (position :initarg :position
             :initform nil
             :accessor axes-base-position
             :documentation "BBox in figure coordinates (left bottom width height).")
   (facecolor :initarg :facecolor
              :initform "white"
              :accessor axes-base-facecolor
              :documentation "Background color of the axes.")
   (frameon :initarg :frameon
            :initform t
            :accessor axes-base-frameon-p
            :type boolean
            :documentation "Whether to draw the axes frame/background.")
   ;; Transforms
   (trans-data :initform nil
               :accessor axes-base-trans-data
               :documentation "Data coordinates → display coordinates transform.")
   (trans-axes :initform nil
               :accessor axes-base-trans-axes
               :documentation "Axes coordinates (0-1) → display coordinates transform.")
   (trans-scale :initform nil
                :accessor axes-base-trans-scale
                :documentation "Data → scaled data transform (for log scale, etc.).")
   ;; Data limits
   (data-lim :initform nil
             :accessor axes-base-data-lim
             :documentation "BBox of data limits (xmin ymin xmax ymax).")
   (view-lim :initform nil
             :accessor axes-base-view-lim
             :documentation "BBox of view limits (what is visible).")
   ;; Artist lists
   (axes-lines :initform nil
               :accessor axes-base-lines
               :documentation "List of Line2D artists.")
   (axes-patches :initform nil
                 :accessor axes-base-patches
                 :documentation "List of Patch artists.")
   (axes-artists :initform nil
                 :accessor axes-base-artists
                 :documentation "List of extra artists.")
   (axes-texts :initform nil
               :accessor axes-base-texts
               :documentation "List of Text artists.")
   (axes-images :initform nil
                :accessor axes-base-images
                :documentation "List of image artists.")
    ;; Background patch
    (axes-patch :initform nil
                :accessor axes-base-patch
                :documentation "Rectangle patch for axes background.")
    ;; Axis objects
    (xaxis :initform nil
           :accessor axes-base-xaxis
           :documentation "XAxis object for this axes.")
    (yaxis :initform nil
           :accessor axes-base-yaxis
           :documentation "YAxis object for this axes.")
     ;; Spines
     (axes-spines :initform nil
                  :accessor axes-base-spines
                  :documentation "Spines container for axes borders.")
     ;; Legend
     (axes-legend :initform nil
                  :accessor axes-base-legend
                  :documentation "Legend object for this axes.")
   ;; Autoscaling
   (autoscale-x-p :initform t
                   :accessor axes-base-autoscale-x-p
                   :type boolean
                   :documentation "Whether to autoscale X axis.")
   (autoscale-y-p :initform t
                   :accessor axes-base-autoscale-y-p
                   :type boolean
                   :documentation "Whether to autoscale Y axis.")
   (autoscale-margin :initform 0.05d0
                      :accessor axes-base-autoscale-margin
                      :type double-float
                      :documentation "Margin fraction for autoscaling (5% default).")
   ;; Shared axes
   (sharex-group :initform nil
                 :accessor axes-base-sharex-group
                 :documentation "List of axes sharing X limits with this one.")
   (sharey-group :initform nil
                 :accessor axes-base-sharey-group
                 :documentation "List of axes sharing Y limits with this one.")
   (%propagating-limits :initform nil
                        :accessor axes-base-%propagating-p
                        :type boolean
                        :documentation "Guard against circular limit propagation."))
  (:default-initargs :zorder 0)
  (:documentation "Base class for all Axes types.
Handles coordinate transforms, data limits, artist management, and drawing.
Ported from matplotlib.axes._base._AxesBase."))

;;; ============================================================
;;; Initialization
;;; ============================================================

(defmethod initialize-instance :after ((ax axes-base) &key figure position)
  "Initialize axes with figure and position."
  ;; Set position from args or default to full figure
  (unless position
    (setf (axes-base-position ax)
          (list 0.125d0 0.11d0 0.775d0 0.77d0)))
  ;; Initialize data limits to null bbox
  (setf (axes-base-data-lim ax)
        (mpl.primitives:bbox-null))
  ;; Initialize view limits to unit bbox (0,0 → 1,1)
  (setf (axes-base-view-lim ax)
        (mpl.primitives:make-bbox 0.0d0 0.0d0 1.0d0 1.0d0))
  ;; Create background patch
  (setf (axes-base-patch ax)
        (make-instance 'mpl.rendering:rectangle
                       :x0 0.0d0 :y0 0.0d0
                       :width 1.0d0 :height 1.0d0
                       :facecolor (axes-base-facecolor ax)
                       :edgecolor "black"
                       :linewidth 1.0
                       :zorder 0))
   ;; Set figure reference
   (when figure
     (setf (axes-base-figure ax) figure)
     (setf (mpl.rendering:artist-figure ax) figure))
   ;; Set up transforms
   (%setup-transforms ax)
   ;; Create xaxis and yaxis
   (setf (axes-base-xaxis ax)
         (make-instance 'x-axis :axes ax))
   (setf (axes-base-yaxis ax)
         (make-instance 'y-axis :axes ax))
   ;; Create spines
   (setf (axes-base-spines ax) (make-spines ax)))

;;; ============================================================
;;; Coordinate transform setup
;;; ============================================================

(defun %compute-display-bbox (ax)
  "Compute the display-space (pixel) bbox for axes based on figure size and position.
Returns (values x0-px y0-px width-px height-px)."
  (let* ((fig (axes-base-figure ax))
         (pos (axes-base-position ax))
         (left (first pos))
         (bottom (second pos))
         (width (third pos))
         (height (fourth pos)))
    (if fig
        (let ((fig-w (float (figure-width-px fig) 1.0d0))
              (fig-h (float (figure-height-px fig) 1.0d0)))
          (values (* left fig-w)
                  (* bottom fig-h)
                  (* width fig-w)
                  (* height fig-h)))
        ;; No figure — use default 640x480
        (values (* left 640.0d0)
                (* bottom 480.0d0)
                (* width 640.0d0)
                (* height 480.0d0)))))

(defun %setup-transforms (ax)
  "Set up transAxes, transScale, and transData for the axes.
Ported from _AxesBase._set_lim_and_transforms."
  ;; transAxes: axes coords (0-1) → display coords
  ;; This is a BboxTransform from unit bbox to display bbox
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (let* ((display-bbox (mpl.primitives:make-bbox dx dy (+ dx dw) (+ dy dh)))
           (unit-bbox (mpl.primitives:make-bbox 0.0d0 0.0d0 1.0d0 1.0d0)))
      (setf (axes-base-trans-axes ax)
            (mpl.primitives:make-bbox-transform unit-bbox display-bbox))))
  ;; transScale: identity for linear (will be replaced for log scale)
  (setf (axes-base-trans-scale ax)
        (mpl.primitives:make-identity-transform))
  ;; transData: data coords → display coords
  ;; This is: transScale + (viewLim → unit bbox) + transAxes
  ;; i.e., data → scaled data → [0,1] → display
  (%update-trans-data ax))

(defun %update-trans-data (ax)
  "Recompute transData from current view limits and axes position.
transData = viewLim→unitBbox ∘ transAxes"
  (let* ((view-lim (axes-base-view-lim ax))
         (unit-bbox (mpl.primitives:make-bbox 0.0d0 0.0d0 1.0d0 1.0d0))
         ;; viewLim → unit bbox: maps view limits to [0,1]
         (view-to-unit (mpl.primitives:make-bbox-transform view-lim unit-bbox))
         ;; Compose: data → unit → display
         (trans-data (mpl.primitives:compose view-to-unit
                                             (axes-base-trans-axes ax))))
    (setf (axes-base-trans-data ax) trans-data)))

;;; ============================================================
;;; Data limit tracking
;;; ============================================================

(defun axes-update-datalim (ax xdata ydata)
  "Update the data limits of AX to include the given X and Y data.
XDATA and YDATA are sequences of numbers."
  (let ((datalim (axes-base-data-lim ax)))
    (flet ((expand-lim (data dim)
             (let ((current-min (if (mpl.primitives:bbox-null-p datalim)
                                    most-positive-double-float
                                    (if (= dim 0)
                                        (mpl.primitives:bbox-x0 datalim)
                                        (mpl.primitives:bbox-y0 datalim))))
                   (current-max (if (mpl.primitives:bbox-null-p datalim)
                                    most-negative-double-float
                                    (if (= dim 0)
                                        (mpl.primitives:bbox-x1 datalim)
                                        (mpl.primitives:bbox-y1 datalim)))))
               (map nil
                    (lambda (v)
                      (let ((fv (float v 1.0d0)))
                        (when (< fv current-min) (setf current-min fv))
                        (when (> fv current-max) (setf current-max fv))))
                    data)
               (values current-min current-max))))
      (multiple-value-bind (x0 x1) (expand-lim xdata 0)
        (multiple-value-bind (y0 y1) (expand-lim ydata 1)
          (setf (axes-base-data-lim ax)
                (mpl.primitives:make-bbox x0 y0 x1 y1)))))))

(defun axes-autoscale-view (ax &key (tight nil))
  "Set view limits from data limits with autoscale margins.
If TIGHT is T, use exact data limits (no margin)."
  (let ((datalim (axes-base-data-lim ax)))
    (when (mpl.primitives:bbox-null-p datalim)
      (return-from axes-autoscale-view))
    (let* ((x0 (mpl.primitives:bbox-x0 datalim))
           (y0 (mpl.primitives:bbox-y0 datalim))
           (x1 (mpl.primitives:bbox-x1 datalim))
           (y1 (mpl.primitives:bbox-y1 datalim))
           (margin (if tight 0.0d0 (axes-base-autoscale-margin ax)))
           (x-range (- x1 x0))
           (y-range (- y1 y0)))
      ;; Handle zero-range (single point)
      (when (zerop x-range)
        (if (zerop x0)
            (setf x0 -0.5d0 x1 0.5d0)
            (let ((delta (* (abs x0) 0.05d0)))
              (decf x0 delta)
              (incf x1 delta)))
        (setf x-range (- x1 x0)))
      (when (zerop y-range)
        (if (zerop y0)
            (setf y0 -0.5d0 y1 0.5d0)
            (let ((delta (* (abs y0) 0.05d0)))
              (decf y0 delta)
              (incf y1 delta)))
        (setf y-range (- y1 y0)))
      ;; Apply margin
      (let ((x-margin (* x-range margin))
            (y-margin (* y-range margin)))
        (when (axes-base-autoscale-x-p ax)
          (setf x0 (- x0 x-margin)
                x1 (+ x1 x-margin)))
        (when (axes-base-autoscale-y-p ax)
          (setf y0 (- y0 y-margin)
                y1 (+ y1 y-margin))))
      ;; Set view limits
      (setf (axes-base-view-lim ax)
            (mpl.primitives:make-bbox x0 y0 x1 y1))
      ;; Update transData to reflect new view limits
      (%update-trans-data ax)
      ;; Propagate to shared axes
      (%propagate-xlim ax)
      (%propagate-ylim ax))))

;;; ============================================================
;;; Set/get limits
;;; ============================================================

(defun axes-set-xlim (ax &key min max)
  "Set the x-axis view limits."
  (let ((view (axes-base-view-lim ax)))
    (setf (axes-base-view-lim ax)
          (mpl.primitives:make-bbox
           (or (when min (float min 1.0d0)) (mpl.primitives:bbox-x0 view))
           (mpl.primitives:bbox-y0 view)
           (or (when max (float max 1.0d0)) (mpl.primitives:bbox-x1 view))
           (mpl.primitives:bbox-y1 view)))
    (when min (setf (axes-base-autoscale-x-p ax) nil))
    (when max (setf (axes-base-autoscale-x-p ax) nil))
    (%update-trans-data ax)
    ;; Propagate to shared axes
    (%propagate-xlim ax)))

(defun axes-set-ylim (ax &key min max)
  "Set the y-axis view limits."
  (let ((view (axes-base-view-lim ax)))
    (setf (axes-base-view-lim ax)
          (mpl.primitives:make-bbox
           (mpl.primitives:bbox-x0 view)
           (or (when min (float min 1.0d0)) (mpl.primitives:bbox-y0 view))
           (mpl.primitives:bbox-x1 view)
           (or (when max (float max 1.0d0)) (mpl.primitives:bbox-y1 view))))
    (when min (setf (axes-base-autoscale-y-p ax) nil))
    (when max (setf (axes-base-autoscale-y-p ax) nil))
    (%update-trans-data ax)
    ;; Propagate to shared axes
    (%propagate-ylim ax)))

(defun axes-get-xlim (ax)
  "Return (values xmin xmax) for the axes."
  (let ((view (axes-base-view-lim ax)))
    (values (mpl.primitives:bbox-x0 view)
            (mpl.primitives:bbox-x1 view))))

(defun axes-get-ylim (ax)
  "Return (values ymin ymax) for the axes."
  (let ((view (axes-base-view-lim ax)))
    (values (mpl.primitives:bbox-y0 view)
            (mpl.primitives:bbox-y1 view))))

;;; ============================================================
;;; Artist management
;;; ============================================================

(defun axes-add-line (ax line)
  "Add a Line2D to the axes."
  (push line (axes-base-lines ax))
  (setf (mpl.rendering:artist-axes line) ax)
  (setf (mpl.rendering:artist-figure line) (axes-base-figure ax))
  (setf (mpl.rendering:artist-stale ax) t)
  line)

(defun axes-add-patch (ax patch)
  "Add a Patch to the axes."
  (push patch (axes-base-patches ax))
  (setf (mpl.rendering:artist-axes patch) ax)
  (setf (mpl.rendering:artist-figure patch) (axes-base-figure ax))
  (setf (mpl.rendering:artist-stale ax) t)
  patch)

(defun axes-add-artist (ax artist)
  "Add an arbitrary artist to the axes."
  (push artist (axes-base-artists ax))
  (setf (mpl.rendering:artist-axes artist) ax)
  (setf (mpl.rendering:artist-figure artist) (axes-base-figure ax))
  (setf (mpl.rendering:artist-stale ax) t)
  artist)

(defun axes-get-all-artists (ax)
  "Return all artists owned by the axes, sorted by z-order."
  (let ((all (append (when (axes-base-patch ax)
                       (list (axes-base-patch ax)))
                     (axes-base-patches ax)
                     (axes-base-lines ax)
                     (axes-base-artists ax)
                     (axes-base-texts ax)
                     (axes-base-images ax))))
    (sort (copy-list all) #'<
          :key (lambda (a)
                 (if (typep a 'mpl.rendering:artist)
                     (mpl.rendering:artist-zorder a)
                     0)))))

;;; ============================================================
;;; Axes draw method
;;; ============================================================

(defmethod mpl.rendering:draw ((ax axes-base) renderer)
  "Draw the axes: background, grid, artists, ticks, spines, labels."
  (unless (mpl.rendering:artist-visible ax)
    (return-from mpl.rendering:draw))
  ;; Ensure transforms are up to date
  (%setup-transforms ax)
  ;; Propagate current transData to child patches and lines that may hold
  ;; stale references from creation time (transData is re-created by
  ;; %update-trans-data, so stored references become stale after autoscaling)
  (let ((td (axes-base-trans-data ax)))
    (dolist (p (axes-base-patches ax))
      (setf (mpl.rendering:artist-transform p) td))
    (dolist (l (axes-base-lines ax))
      (setf (mpl.rendering:artist-transform l) td))
    (dolist (img (axes-base-images ax))
      (setf (mpl.rendering:artist-transform img) td)))
  ;; Draw background patch if frameon
  (when (and (axes-base-frameon-p ax) (axes-base-patch ax))
    (%draw-axes-background ax renderer))
  ;; Draw all artists in z-order
  (let ((artists (axes-get-all-artists ax)))
    ;; Skip the background patch (already drawn)
    (when (axes-base-patch ax)
      (setf artists (remove (axes-base-patch ax) artists)))
    (dolist (artist artists)
      (when (and (typep artist 'mpl.rendering:artist)
                 (mpl.rendering:artist-visible artist))
        (mpl.rendering:draw artist renderer))))
  ;; Draw xaxis and yaxis (tick marks, labels, grid)
  (when (axes-base-xaxis ax)
    (mpl.rendering:draw (axes-base-xaxis ax) renderer))
  (when (axes-base-yaxis ax)
    (mpl.rendering:draw (axes-base-yaxis ax) renderer))
  ;; Draw spines (axes border lines) — replaces old %draw-axes-frame
  (when (axes-base-spines ax)
    (spines-draw-all (axes-base-spines ax) renderer))
   ;; Fallback: draw axes frame if no spines
   (when (and (axes-base-frameon-p ax) (null (axes-base-spines ax)))
     (%draw-axes-frame ax renderer))
   ;; Draw legend (on top of everything)
   (when (axes-base-legend ax)
     (mpl.rendering:draw (axes-base-legend ax) renderer))
   (setf (mpl.rendering:artist-stale ax) nil))

(defun %draw-axes-background (ax renderer)
  "Draw the axes background fill."
  (when (typep renderer 'mpl.backends:renderer-base)
    (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
      (let* ((fc (axes-base-facecolor ax))
             (rgba-face (if (stringp fc)
                             (let ((rgba (mpl.colors:to-rgba fc)))
                               (list (elt rgba 0) (elt rgba 1) (elt rgba 2) (elt rgba 3)))
                             (list 1.0 1.0 1.0 1.0)))
             (path (mpl.primitives:path-unit-rectangle))
             (transform (mpl.primitives:make-affine-2d
                         :scale (list dw dh)
                         :translate (list dx dy)))
             (gc (mpl.backends:make-graphics-context
                  :facecolor rgba-face
                  :edgecolor nil
                  :linewidth 0.0)))
        (mpl.backends:draw-path renderer gc path transform rgba-face)))))

(defun %draw-axes-frame (ax renderer)
  "Draw the axes border rectangle."
  (when (typep renderer 'mpl.backends:renderer-base)
    (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
      (let* ((rgba-edge (list 0.0 0.0 0.0 1.0))
             (path (mpl.primitives:path-unit-rectangle))
             (transform (mpl.primitives:make-affine-2d
                         :scale (list dw dh)
                         :translate (list dx dy)))
             (gc (mpl.backends:make-graphics-context
                  :facecolor nil
                  :edgecolor rgba-edge
                  :linewidth 1.0)))
        (mpl.backends:draw-path renderer gc path transform nil)))))

;;; ============================================================
;;; Scale control
;;; ============================================================

(defun axes-set-xscale (ax scale-name &rest args)
  "Set the X axis scale.
SCALE-NAME is a keyword: :linear, :log, :symlog, :logit, or :function.
Additional keyword arguments are passed to the scale constructor."
  (let ((scale (apply #'make-scale scale-name :axis (axes-base-xaxis ax) args)))
    (axis-set-scale (axes-base-xaxis ax) scale))
  (setf (mpl.rendering:artist-stale ax) t))

(defun axes-set-yscale (ax scale-name &rest args)
  "Set the Y axis scale.
SCALE-NAME is a keyword: :linear, :log, :symlog, :logit, or :function.
Additional keyword arguments are passed to the scale constructor."
  (let ((scale (apply #'make-scale scale-name :axis (axes-base-yaxis ax) args)))
    (axis-set-scale (axes-base-yaxis ax) scale))
  (setf (mpl.rendering:artist-stale ax) t))

;;; ============================================================
;;; Shared axes linking
;;; ============================================================

(defun axes-share-x (ax other)
  "Link AX's X limits to OTHER's X limits.
When either axes' X limits change, the other is updated."
  (unless (eq ax other)
    ;; Add each to the other's share group
    (pushnew other (axes-base-sharex-group ax))
    (pushnew ax (axes-base-sharex-group other))
    ;; Sync current limits: use other's limits
    (multiple-value-bind (xmin xmax) (axes-get-xlim other)
      (unless (axes-base-%propagating-p ax)
        (setf (axes-base-%propagating-p ax) t)
        (unwind-protect
             (progn
               (let ((view (axes-base-view-lim ax)))
                 (setf (axes-base-view-lim ax)
                       (mpl.primitives:make-bbox
                        xmin (mpl.primitives:bbox-y0 view)
                        xmax (mpl.primitives:bbox-y1 view))))
               (%update-trans-data ax))
          (setf (axes-base-%propagating-p ax) nil))))))

(defun axes-share-y (ax other)
  "Link AX's Y limits to OTHER's Y limits.
When either axes' Y limits change, the other is updated."
  (unless (eq ax other)
    (pushnew other (axes-base-sharey-group ax))
    (pushnew ax (axes-base-sharey-group other))
    ;; Sync current limits: use other's limits
    (multiple-value-bind (ymin ymax) (axes-get-ylim other)
      (unless (axes-base-%propagating-p ax)
        (setf (axes-base-%propagating-p ax) t)
        (unwind-protect
             (progn
               (let ((view (axes-base-view-lim ax)))
                 (setf (axes-base-view-lim ax)
                       (mpl.primitives:make-bbox
                        (mpl.primitives:bbox-x0 view) ymin
                        (mpl.primitives:bbox-x1 view) ymax)))
               (%update-trans-data ax))
          (setf (axes-base-%propagating-p ax) nil))))))

(defun %propagate-xlim (ax)
  "Propagate X limits from AX to all shared axes. Guards against circular updates."
  (when (and (axes-base-sharex-group ax)
             (not (axes-base-%propagating-p ax)))
    (setf (axes-base-%propagating-p ax) t)
    (unwind-protect
         (multiple-value-bind (xmin xmax) (axes-get-xlim ax)
           (dolist (other (axes-base-sharex-group ax))
             (unless (axes-base-%propagating-p other)
               (let ((view (axes-base-view-lim other)))
                 (setf (axes-base-view-lim other)
                       (mpl.primitives:make-bbox
                        xmin (mpl.primitives:bbox-y0 view)
                        xmax (mpl.primitives:bbox-y1 view))))
               (%update-trans-data other))))
      (setf (axes-base-%propagating-p ax) nil))))

(defun %propagate-ylim (ax)
  "Propagate Y limits from AX to all shared axes. Guards against circular updates."
  (when (and (axes-base-sharey-group ax)
             (not (axes-base-%propagating-p ax)))
    (setf (axes-base-%propagating-p ax) t)
    (unwind-protect
         (multiple-value-bind (ymin ymax) (axes-get-ylim ax)
           (dolist (other (axes-base-sharey-group ax))
             (unless (axes-base-%propagating-p other)
               (let ((view (axes-base-view-lim other)))
                 (setf (axes-base-view-lim other)
                       (mpl.primitives:make-bbox
                        (mpl.primitives:bbox-x0 view) ymin
                        (mpl.primitives:bbox-x1 view) ymax)))
               (%update-trans-data other))))
      (setf (axes-base-%propagating-p ax) nil))))

;;; ============================================================
;;; Print representation
;;; ============================================================

(defmethod print-object ((ax axes-base) stream)
  "Print a readable representation of the axes."
  (print-unreadable-object (ax stream :type t)
    (let ((view (axes-base-view-lim ax)))
      (format stream "xlim=(~,2F, ~,2F) ylim=(~,2F, ~,2F) ~D artists"
              (mpl.primitives:bbox-x0 view)
              (mpl.primitives:bbox-x1 view)
              (mpl.primitives:bbox-y0 view)
              (mpl.primitives:bbox-y1 view)
              (+ (length (axes-base-lines ax))
                 (length (axes-base-patches ax))
                 (length (axes-base-artists ax)))))))
