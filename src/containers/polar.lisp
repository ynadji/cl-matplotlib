;;;; polar.lisp — PolarAxes class with circular grid and polar transforms
;;;; Subclasses axes-base directly for polar coordinate plotting.
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; PolarAxes — polar coordinate axes with circular grid
;;; ============================================================

(defclass polar-axes (axes-base)
  ((r-max :initform 1.0d0 :accessor polar-axes-r-max
          :documentation "Maximum radius for this polar axes.")
   (theta-ticks :initform nil :accessor polar-axes-theta-ticks
                :documentation "List of theta tick positions in radians.")
   (theta-labels :initform nil :accessor polar-axes-theta-labels
                 :documentation "List of theta tick label strings.")
   (r-ticks :initform nil :accessor polar-axes-r-ticks
            :documentation "List of radial tick positions.")
   (polar-transform :initform nil :accessor polar-axes-polar-transform
                    :documentation "The polar-transform instance.")
   (polar-affine :initform nil :accessor polar-axes-polar-affine
                 :documentation "The polar-affine instance."))
  (:documentation "Polar coordinate axes with circular grid.
Subclasses axes-base directly (not mpl-axes)."))

;;; ============================================================
;;; Initialization
;;; ============================================================

(defmethod initialize-instance :after ((ax polar-axes) &key figure position)
  (declare (ignore figure position))
  ;; Set default theta ticks: 8 positions at 0, π/4, π/2, ..., 7π/4
  (setf (polar-axes-theta-ticks ax)
        (loop for i from 0 below 8
              collect (* i (/ pi 4.0d0))))
  (setf (polar-axes-theta-labels ax)
        '("0°" "45°" "90°" "135°" "180°" "225°" "270°" "315°"))
  ;; Create polar transform instances
  (setf (polar-axes-polar-transform ax)
        (make-instance 'mpl.primitives:polar-transform))
  (setf (polar-axes-polar-affine ax)
        (make-instance 'mpl.primitives:polar-affine :r-max 1.0d0))
  ;; Set up polar transform pipeline
  (%setup-polar-transforms ax)
  ;; Set view limits: theta 0→2π, r 0→1
  (setf (axes-base-view-lim ax)
        (mpl.primitives:make-bbox 0.0d0 0.0d0 (* 2.0d0 pi) 1.0d0)))

;;; ============================================================
;;; Polar transform pipeline
;;; ============================================================

(defun %setup-polar-transforms (ax)
  "Set up the polar transform pipeline for polar-axes.
trans-data = polar-transform ∘ polar-affine ∘ trans-axes"
  (let* ((trans-axes (axes-base-trans-axes ax))
         (pa (polar-axes-polar-affine ax))
         (pt (polar-axes-polar-transform ax)))
    ;; trans-data = polar-transform ∘ polar-affine ∘ trans-axes
    (setf (axes-base-trans-data ax)
          (mpl.primitives:compose pt
                                  (mpl.primitives:compose pa trans-axes)))))

;;; ============================================================
;;; Draw method override
;;; ============================================================

(defmethod mpl.rendering:draw ((ax polar-axes) renderer)
  "Draw polar axes: circular background, radial grid, theta grid, artists, labels."
  (unless (mpl.rendering:artist-visible ax)
    (return-from mpl.rendering:draw))
  ;; 1. Update r-max from data limits
  (%polar-update-rmax ax)
  ;; 2. Update polar-affine with new r-max
  (mpl.primitives:polar-affine-update (polar-axes-polar-affine ax)
                                       (polar-axes-r-max ax))
  ;; 3. Recompute trans-data
  (%setup-polar-transforms ax)
  ;; 4. Propagate trans-data to all artists
  (let ((td (axes-base-trans-data ax)))
    (dolist (p (axes-base-patches ax))
      (setf (mpl.rendering:artist-transform p) td))
    (dolist (l (axes-base-lines ax))
      (setf (mpl.rendering:artist-transform l) td))
    (dolist (a (axes-base-artists ax))
      (setf (mpl.rendering:artist-transform a) td)))
  ;; 5. Draw circular background
  (%polar-draw-background ax renderer)
  ;; 6. Draw radial grid circles
  (%polar-draw-radial-grid ax renderer)
  ;; 7. Draw theta grid lines (radial rays)
  (%polar-draw-theta-grid ax renderer)
  ;; 8. Draw all artists (lines, patches, etc.) in z-order
  (let ((artists (axes-get-all-artists ax)))
    (when (axes-base-patch ax)
      (setf artists (remove (axes-base-patch ax) artists)))
    (dolist (artist artists)
      (when (and (typep artist 'mpl.rendering:artist)
                 (mpl.rendering:artist-visible artist))
        (mpl.rendering:draw artist renderer))))
  ;; 9. Draw circular boundary spine
  (%polar-draw-boundary ax renderer)
  ;; 10. Draw theta tick labels
  (%polar-draw-theta-labels ax renderer)
  ;; 11. Draw radial tick labels
  (%polar-draw-r-labels ax renderer)
  (setf (mpl.rendering:artist-stale ax) nil))

;;; ============================================================
;;; Helper functions
;;; ============================================================

(defun %polar-update-rmax (ax)
  "Update r-max from data limits."
  (let ((datalim (axes-base-data-lim ax)))
    (unless (mpl.primitives:bbox-null-p datalim)
      ;; r is the Y coordinate in polar data space
      (let ((r-max (max (abs (mpl.primitives:bbox-y0 datalim))
                        (abs (mpl.primitives:bbox-y1 datalim)))))
        (when (> r-max 0.0d0)
          (setf (polar-axes-r-max ax) (* r-max 1.05d0))  ; 5% margin
          ;; Update view limits
          (setf (axes-base-view-lim ax)
                (mpl.primitives:make-bbox 0.0d0 0.0d0 (* 2.0d0 pi)
                                          (polar-axes-r-max ax)))))))
  ;; Compute r-ticks: 4 evenly spaced values from 0 to r-max
  (let* ((r-max (polar-axes-r-max ax))
         (step (/ r-max 4.0d0))
         (ticks (loop for i from 1 to 4
                      collect (* i step))))
    (setf (polar-axes-r-ticks ax) ticks)))

(defun %polar-draw-background (ax renderer)
  "Draw circular background for polar axes."
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (let* ((cx (+ dx (* 0.5d0 dw)))
           (cy (+ dy (* 0.5d0 dh)))
           (radius (* 0.5d0 (min dw dh)))
           ;; Create circle path using path-arc(0, 360)
           (arc-path (mpl.primitives:path-arc 0.0d0 360.0d0))
           ;; Scale to radius and translate to center
           (transform (mpl.primitives:make-affine-2d
                       :scale (list radius radius)
                       :translate (list cx cy)))
           (fc (axes-base-facecolor ax))
           (rgba-face (if (stringp fc)
                          (let ((rgba (mpl.colors:to-rgba fc)))
                            (list (elt rgba 0) (elt rgba 1) (elt rgba 2) (elt rgba 3)))
                          (list 1.0 1.0 1.0 1.0)))
           (gc (mpl.backends:make-graphics-context
                :facecolor rgba-face
                :edgecolor nil
                :linewidth 0.0)))
      (mpl.backends:draw-path renderer gc arc-path transform rgba-face))))

(defun %polar-draw-radial-grid (ax renderer)
  "Draw concentric radial grid circles."
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (let* ((cx (+ dx (* 0.5d0 dw)))
           (cy (+ dy (* 0.5d0 dh)))
           (max-radius (* 0.5d0 (min dw dh)))
           (r-max (polar-axes-r-max ax))
           (gc (mpl.backends:make-graphics-context
                :facecolor nil
                :edgecolor '(0.8 0.8 0.8 1.0)
                :linewidth 0.5)))
      (dolist (r-tick (polar-axes-r-ticks ax))
        (let* ((frac (/ r-tick r-max))
               (radius (* frac max-radius))
               (arc-path (mpl.primitives:path-arc 0.0d0 360.0d0))
               (transform (mpl.primitives:make-affine-2d
                           :scale (list radius radius)
                           :translate (list cx cy))))
          (mpl.backends:draw-path renderer gc arc-path transform nil))))))

(defun %polar-draw-theta-grid (ax renderer)
  "Draw radial theta grid lines."
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (let* ((cx (+ dx (* 0.5d0 dw)))
           (cy (+ dy (* 0.5d0 dh)))
           (radius (* 0.5d0 (min dw dh)))
           (gc (mpl.backends:make-graphics-context
                :facecolor nil
                :edgecolor '(0.8 0.8 0.8 1.0)
                :linewidth 0.5)))
      (dolist (theta (polar-axes-theta-ticks ax))
        (let* ((ex (+ cx (* radius (cos theta))))
               (ey (+ cy (* radius (sin theta))))
               ;; Simple 2-vertex line path
               (verts (make-array '(2 2) :element-type 'double-float
                                  :initial-contents (list (list cx cy) (list ex ey))))
               (codes (make-array 2 :element-type '(unsigned-byte 8)
                                  :initial-contents (list mpl.primitives:+moveto+
                                                          mpl.primitives:+lineto+)))
               (path (mpl.primitives:%make-mpl-path :vertices verts :codes codes))
               (identity-tr (mpl.primitives:make-identity-transform)))
          (mpl.backends:draw-path renderer gc path identity-tr nil))))))

(defun %polar-draw-boundary (ax renderer)
  "Draw circular boundary spine."
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (let* ((cx (+ dx (* 0.5d0 dw)))
           (cy (+ dy (* 0.5d0 dh)))
           (radius (* 0.5d0 (min dw dh)))
           (arc-path (mpl.primitives:path-arc 0.0d0 360.0d0))
           (transform (mpl.primitives:make-affine-2d
                       :scale (list radius radius)
                       :translate (list cx cy)))
           (gc (mpl.backends:make-graphics-context
                :facecolor nil
                :edgecolor '(0.0 0.0 0.0 1.0)
                :linewidth 1.0)))
      (mpl.backends:draw-path renderer gc arc-path transform nil))))

(defun %polar-draw-theta-labels (ax renderer)
  "Draw theta tick labels around the polar boundary."
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (let* ((cx (+ dx (* 0.5d0 dw)))
           (cy (+ dy (* 0.5d0 dh)))
           (radius (* 0.5d0 (min dw dh)))
           (label-radius (* 1.08d0 radius)))  ; 8% outside boundary
      (loop for theta in (polar-axes-theta-ticks ax)
            for label in (polar-axes-theta-labels ax)
            do (let* ((lx (+ cx (* label-radius (cos theta))))
                      (ly (+ cy (* label-radius (sin theta))))
                      (text-obj (make-instance 'mpl.rendering:text-artist
                                               :x lx :y ly
                                               :text label
                                               :fontsize 8.0
                                               :horizontalalignment :center
                                               :verticalalignment :center
                                               :color "black")))
                 (setf (mpl.rendering:artist-transform text-obj)
                       (mpl.primitives:make-identity-transform))
                 (mpl.rendering:draw text-obj renderer))))))

(defun %polar-draw-r-labels (ax renderer)
  "Draw radial tick labels along θ=0 ray."
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (let* ((cx (+ dx (* 0.5d0 dw)))
           (cy (+ dy (* 0.5d0 dh)))
           (radius (* 0.5d0 (min dw dh)))
           (r-max (polar-axes-r-max ax)))
      (dolist (r-tick (polar-axes-r-ticks ax))
        (let* ((frac (/ r-tick r-max))
               (lx (+ cx (* frac radius)))
               (ly (+ cy 5.0d0))  ; slightly above the θ=0 ray
               (label (format nil "~,2G" r-tick))
               (text-obj (make-instance 'mpl.rendering:text-artist
                                        :x lx :y ly
                                        :text label
                                        :fontsize 7.0
                                        :horizontalalignment :center
                                        :verticalalignment :bottom
                                        :color "black")))
          (setf (mpl.rendering:artist-transform text-obj)
                (mpl.primitives:make-identity-transform))
          (mpl.rendering:draw text-obj renderer))))))

;;; ============================================================
;;; Polar-specific autoscale (called from %polar-update-rmax)
;;; ============================================================
;;; Note: axes-autoscale-view is a defun, not generic, so we handle
;;; polar autoscaling in %polar-update-rmax and the 5% margin there.
