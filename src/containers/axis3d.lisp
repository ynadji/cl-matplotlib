;;;; axis3d.lisp — the three axes of an axes-3d: pane, grid, axis line,
;;;; ticks and label, all placed in the projected view box.
;;;; Port of mpl_toolkits/mplot3d/axis3d.py (matplotlib 3.8.4).
;;;;
;;;; An axis-3d reuses the whole locator/formatter stack of x-axis
;;;; (%axis-compute-major-ticks); only the drawing is new. Every element
;;;; is computed in world coordinates, projected through the axes'
;;;; matrix M into the view box, and drawn through the axes' transData
;;;; (lines) or at the transformed display point (text).

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Constants (axis3d._AXINFO, _PLANES, rc-derived styles)
;;; ============================================================

(defparameter *axis3d-planes*
  #((0 3 7 4) (1 2 6 5)    ; yz planes
    (0 1 5 4) (3 2 6 7)    ; xz planes
    (0 1 2 3) (4 5 6 7))   ; xy planes
  "Indices into the projected unit cube for the two planes normal to each axis.")

(defparameter *axis3d-info*
  '((0 :tickdir 1 :juggled (1 0 2) :pane-color (0.95d0 0.95d0 0.95d0 0.5d0))
    (1 :tickdir 0 :juggled (0 1 2) :pane-color (0.9d0 0.9d0 0.9d0 0.5d0))
    (2 :tickdir 0 :juggled (0 2 1) :pane-color (0.925d0 0.925d0 0.925d0 0.5d0)))
  "Per-axis table: default tick direction axis, the juggled index order used
to pick the axis line's edge, and the rc default pane color.")

(defconstant +axis3d-tick-inward+ 0.2d0)
(defconstant +axis3d-tick-outward+ 0.1d0)
(defconstant +axis3d-label-offset+ 21.0d0 "default_offset in axis3d.Axis.draw")
(defconstant +axis3d-tick-label-offset+ 8.0d0 "default_label_offset in _draw_ticks")

(defun %axis3d-info (index key)
  (getf (cdr (assoc index *axis3d-info*)) key))

;;; ============================================================
;;; Class
;;; ============================================================

(defclass axis-3d (x-axis)
  ((index :initarg :index :initform 0 :accessor axis-3d-index
          :documentation "0, 1 or 2 for the x, y or z axis.")
   (pane-color :initarg :pane-color :initform nil :accessor axis-3d-pane-color
               :documentation "RGBA list; NIL means the per-axis default.")
   (rotate-label :initarg :rotate-label :initform nil :accessor axis-3d-rotate-label
                 :documentation "T/NIL to force label rotation; NIL (default) rotates labels longer than 4 characters."))
  (:documentation "One axis of an axes-3d. Inherits x-axis for its locator,
formatter, tick styling and label slots; draws itself in 3D."))

(defmethod axis-get-view-interval ((axis axis-3d))
  (let ((ax (axis-axes axis)))
    (if ax
        (ecase (axis-3d-index axis)
          (0 (axes-get-xlim ax))
          (1 (axes-get-ylim ax))
          (2 (axes-get-zlim ax)))
        (values 0.0d0 1.0d0))))

(defmethod axis-get-data-interval ((axis axis-3d))
  (let ((ax (axis-axes axis)))
    (if ax
        (ecase (axis-3d-index axis)
          (0 (multiple-value-bind (lo hi) (axes-3d-xy-data-interval ax 0) (values lo hi)))
          (1 (multiple-value-bind (lo hi) (axes-3d-xy-data-interval ax 1) (values lo hi)))
          (2 (multiple-value-bind (lo hi) (axes-3d-z-data-interval ax) (values lo hi))))
        (values 0.0d0 1.0d0))))

(defun %axis3d-pane-rgba (axis)
  (or (axis-3d-pane-color axis) (%axis3d-info (axis-3d-index axis) :pane-color)))

(defmethod %axis-tick-space ((axis axis-3d))
  "matplotlib's XAxis.get_tick_space for every 3D axis (axis3d.Axis
inherits XAxis): floor(axes width in points / (3 × tick label size)),
measured on the squared 3D box."
  (let ((ax (axis-axes axis)))
    (when ax
      (let* ((fig (axes-base-figure ax))
             (dpi (if fig (float (figure-dpi fig) 1.0d0) 100.0d0)))
        (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
          (declare (ignore dx dy dh))
          (let ((length-pt (* (/ dw dpi) 72.0d0))
                (size (* 3.0d0 (float (axis-tick-label-fontsize axis) 1.0d0))))
            (max 1 (floor length-pt size))))))))

;;; ============================================================
;;; Geometry helpers
;;; ============================================================

(defun %v3 (a b c) (vector (float a 1.0d0) (float b 1.0d0) (float c 1.0d0)))

(defun %v3-copy (v) (vector (aref v 0) (aref v 1) (aref v 2)))

(defun %sorted-bound (lo hi)
  (if (<= lo hi) (values lo hi) (values hi lo)))

(defun %axes3d-unit-cube (bounds)
  "The 8 corners (mplot3d order) of the box BOUNDS = (minx maxx miny maxy minz maxz)."
  (destructuring-bind (minx maxx miny maxy minz maxz) bounds
    (list (%v3 minx miny minz) (%v3 maxx miny minz) (%v3 maxx maxy minz) (%v3 minx maxy minz)
          (%v3 minx miny maxz) (%v3 maxx miny maxz) (%v3 maxx maxy maxz) (%v3 minx maxy maxz))))

(defun %project-point (m p)
  "P (3-vector) projected through M → (vector tx ty tz)."
  (multiple-value-bind (tx ty tz) (mpl.primitives:proj-transform-vec m (aref p 0) (aref p 1) (aref p 2))
    (vector tx ty tz)))

(defun %axis3d-coord-info (ax)
  "Port of axis3d.Axis._get_coord_info.
Returns (values mins maxs centers deltas projected-corners highs), each of
the first four a 3-vector, PROJECTED-CORNERS the 8 projected cube corners
and HIGHS a 3-vector of booleans telling, per axis, whether the pane/axis
line sits at the high end."
  (let* ((m (axes-3d-proj-matrix ax))
         (mins (make-array 3)) (maxs (make-array 3))
         (centers (make-array 3)) (deltas (make-array 3)))
    (loop for i below 3
          for (lo hi) = (multiple-value-list
                         (ecase i
                           (0 (axes-get-xlim ax))
                           (1 (axes-get-ylim ax))
                           (2 (axes-get-zlim ax))))
          do (multiple-value-bind (lo hi) (%sorted-bound lo hi)
               (setf (aref centers i) (* 0.5d0 (+ hi lo))
                     (aref deltas i) (/ (- hi lo) 12.0d0)
                     (aref mins i) (- lo (* 0.25d0 (aref deltas i)))
                     (aref maxs i) (+ hi (* 0.25d0 (aref deltas i))))))
    (let* ((corners (mapcar (lambda (p) (%project-point m p))
                            (%axes3d-unit-cube (list (aref mins 0) (aref maxs 0)
                                                     (aref mins 1) (aref maxs 1)
                                                     (aref mins 2) (aref maxs 2)))))
           (cv (coerce corners 'vector))
           (highs (make-array 3))
           (means-z0 (make-array 3)) (means-z1 (make-array 3)))
      (flet ((mean-z (plane)
               (/ (loop for idx in plane sum (aref (aref cv idx) 2)) (length plane))))
        (dotimes (i 3)
          (setf (aref means-z0 i) (mean-z (aref *axis3d-planes* (* 2 i)))
                (aref means-z1 i) (mean-z (aref *axis3d-planes* (1+ (* 2 i))))
                (aref highs i) (< (aref means-z0 i) (aref means-z1 i)))))
      ;; Looking straight at a plane: two axes are degenerate; pick the
      ;; conventional sides (axis3d.py)
      (let* ((equals (loop for i below 3
                           collect (<= (abs (- (aref means-z0 i) (aref means-z1 i)))
                                       double-float-epsilon)))
             (n-equal (count t equals)))
        (when (= n-equal 2)
          (let ((vertical (position nil equals)))
            (case vertical
              (2 (setf (aref highs 0) t (aref highs 1) t))
              (1 (setf (aref highs 0) t (aref highs 2) nil))
              (0 (setf (aref highs 1) nil (aref highs 2) nil))))))
      (values mins maxs centers deltas corners highs))))

(defun %axis3d-edge-points (index minmax maxmin)
  "Port of _get_axis_line_edge_points for the default position and a
vertical z axis: the two world endpoints of the axis line."
  (let* ((juggled (%axis3d-info index :juggled))
         (p0 (%v3-copy minmax))
         (p1 nil))
    (setf (aref p0 (first juggled)) (aref maxmin (first juggled)))
    (setf p1 (%v3-copy p0))
    (setf (aref p1 (second juggled)) (aref maxmin (second juggled)))
    (values p0 p1)))

(defun %axis3d-tickdir (index)
  "Port of _get_tickdir for the default position and vertical z."
  (%axis3d-info index :tickdir))

(defun %move-from-center (coord centers deltas axmask)
  "Port of axis3d._move_from_center: push each masked coordinate away from
its center by delta."
  (let ((out (%v3-copy coord)))
    (dotimes (i 3)
      (when (aref axmask i)
        (let ((d (- (aref coord i) (aref centers i))))
          (incf (aref out i) (* (if (minusp d) -1.0d0 1.0d0) (aref deltas i))))))
    out))

(defun %axis3d-axmask (index)
  (let ((mask (vector t t t)))
    (setf (aref mask index) nil)
    mask))

;;; ============================================================
;;; Drawing primitives in view coordinates
;;; ============================================================

(defun %axis3d-rgba (color)
  "COLOR (name or rgb/rgba sequence) as an (r g b a) list of single-floats."
  (if (and (typep color 'sequence) (not (stringp color)) (= (length color) 4))
      (map 'list (lambda (v) (float v 1.0)) color)
      (map 'list (lambda (v) (float v 1.0)) (mpl.colors:to-rgba color))))

(defun %axis3d-draw-polyline (ax renderer points &key color linewidth (linestyle :solid) facecolor closed)
  "Stroke (and fill when FACECOLOR) the polyline POINTS (list of 2-vectors
in view coordinates) through the axes' transData."
  (when (>= (length points) 2)
    (let* ((n (length points))
           (verts (make-array (list (if closed (1+ n) n) 2) :element-type 'double-float))
           (codes (make-array (if closed (1+ n) n) :element-type '(unsigned-byte 8))))
      (loop for p in points for i from 0
            do (setf (aref verts i 0) (float (aref p 0) 1.0d0)
                     (aref verts i 1) (float (aref p 1) 1.0d0)
                     (aref codes i) (if (zerop i) mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
      (when closed
        (setf (aref verts n 0) (aref verts 0 0)
              (aref verts n 1) (aref verts 0 1)
              (aref codes n) mpl.primitives:+closepoly+))
      (let* ((path (mpl.primitives:make-path :vertices verts :codes codes))
             (rgba-face (when facecolor (%axis3d-rgba facecolor)))
             (gc (mpl.backends:make-graphics-context
                  :facecolor rgba-face
                  :edgecolor (when color (%axis3d-rgba color))
                  :linewidth (float (or linewidth 1.0) 1.0)
                  :linestyle linestyle)))
        (mpl.backends:draw-path renderer gc path (axes-base-trans-data ax) rgba-face)))))

(defun %axis3d-draw-text (ax renderer view-point text &key (fontsize 10.0) (color "black")
                                                           (ha :center) (va :center) (rotation 0.0))
  "Draw TEXT anchored at VIEW-POINT (2-vector in view coordinates)."
  (when (and text (plusp (length text)))
    (let* ((disp (mpl.primitives:transform-point (axes-base-trans-data ax)
                                                  (list (aref view-point 0) (aref view-point 1))))
           (txt (make-instance 'mpl.rendering:text-artist
                               :x (float (aref disp 0) 1.0d0) :y (float (aref disp 1) 1.0d0)
                               :text text
                               :fontsize fontsize
                               :color color
                               :horizontalalignment ha
                               :verticalalignment va
                               :rotation rotation
                               :rotation-mode :anchor)))
      (setf (mpl.rendering:artist-transform txt) (mpl.primitives:make-identity-transform))
      (mpl.rendering:draw txt renderer))))

;;; ============================================================
;;; Pane, grid, axis (axis3d.Axis.draw_pane / draw_grid / draw)
;;; ============================================================

(defun axis3d-draw-pane (axis ax renderer)
  "The translucent pane on the far side of AXIS's direction."
  (multiple-value-bind (mins maxs centers deltas corners highs) (%axis3d-coord-info ax)
    (declare (ignore mins maxs centers deltas))
    (let* ((index (axis-3d-index axis))
           (plane (aref *axis3d-planes* (if (aref highs index) (1+ (* 2 index)) (* 2 index))))
           (cv (coerce corners 'vector))
           (points (loop for idx in plane collect (aref cv idx)))
           (rgba (%axis3d-pane-rgba axis)))
      (%axis3d-draw-polyline ax renderer points :facecolor rgba :color rgba :linewidth 0.0 :closed t))))

(defun axis3d-draw-grid (axis ax renderer)
  "Grid lines for AXIS's major ticks across the two panes they cross."
  (when (axes-3d-grid-on ax)
    (multiple-value-bind (mins maxs centers deltas corners highs) (%axis3d-coord-info ax)
      (declare (ignore centers deltas corners))
      (let* ((index (axis-3d-index axis))
             (m (axes-3d-proj-matrix ax))
             (minmax (%v3 (if (aref highs 0) (aref maxs 0) (aref mins 0))
                          (if (aref highs 1) (aref maxs 1) (aref mins 1))
                          (if (aref highs 2) (aref maxs 2) (aref mins 2))))
             (maxmin (%v3 (if (aref highs 0) (aref mins 0) (aref maxs 0))
                          (if (aref highs 1) (aref mins 1) (aref maxs 1))
                          (if (aref highs 2) (aref mins 2) (aref maxs 2))))
             (i-2 (mod (- index 2) 3))
             (i-1 (mod (- index 1) 3))
             (color (mpl.rc:rc "grid.color"))
             (lw (mpl.rc:rc "grid.linewidth"))
             (ls (mpl.rc:rc "grid.linestyle")))
        (multiple-value-bind (vmin vmax) (axis-get-view-interval axis)
          (dolist (tk (%axis-compute-major-ticks axis vmin vmax))
            (let* ((xyz0 (%v3-copy minmax))
                   (p0 nil) (p2 nil))
              (setf (aref xyz0 index) (tick-loc tk))
              (setf p0 (%v3-copy xyz0)
                    p2 (%v3-copy xyz0))
              (setf (aref p0 i-2) (aref maxmin i-2)
                    (aref p2 i-1) (aref maxmin i-1))
              (%axis3d-draw-polyline ax renderer
                                     (list (%project-point m p0) (%project-point m xyz0) (%project-point m p2))
                                     :color color :linewidth lw :linestyle ls))))))))

(defun axis3d-draw (axis ax renderer)
  "Axis line, tick marks, tick labels and the axis label."
  (multiple-value-bind (mins maxs centers deltas corners highs) (%axis3d-coord-info ax)
    (declare (ignore corners))
    (let* ((index (axis-3d-index axis))
           (m (axes-3d-proj-matrix ax))
           (fig (axes-base-figure ax))
           (dpi (if fig (float (figure-dpi fig) 1.0d0) 100.0d0))
           (minmax (%v3 (if (aref highs 0) (aref maxs 0) (aref mins 0))
                        (if (aref highs 1) (aref maxs 1) (aref mins 1))
                        (if (aref highs 2) (aref maxs 2) (aref mins 2))))
           (maxmin (%v3 (if (aref highs 0) (aref mins 0) (aref maxs 0))
                        (if (aref highs 1) (aref mins 1) (aref maxs 1))
                        (if (aref highs 2) (aref mins 2) (aref maxs 2))))
           ;; axes size in points → how many data "deltas" one point is
           (deltas-per-point
             (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
               (declare (ignore dx dy))
               (/ 48.0d0 (* 72.0d0 (+ (/ dw dpi) (/ dh dpi))))))
           (labelpad (float (mpl.rc:rc "axes.labelpad") 1.0d0))
           (labeldeltas (let ((k (* (+ labelpad +axis3d-label-offset+) deltas-per-point)))
                          (%v3 (* k (aref deltas 0)) (* k (aref deltas 1)) (* k (aref deltas 2)))))
           (axmask (%axis3d-axmask index)))
      (multiple-value-bind (edgep1 edgep2) (%axis3d-edge-points index minmax maxmin)
        (let* ((pep1 (%project-point m edgep1))
               (pep2 (%project-point m edgep2))
               ;; direction of the axis line on screen (square box: view
               ;; space and display space have the same angle)
               (d1 (mpl.primitives:transform-point (axes-base-trans-data ax) (list (aref pep1 0) (aref pep1 1))))
               (d2 (mpl.primitives:transform-point (axes-base-trans-data ax) (list (aref pep2 0) (aref pep2 1))))
               (dx (- (aref d2 0) (aref d1 0)))
               (dy (- (aref d2 1) (aref d1 1))))
          ;; axis line
          (%axis3d-draw-polyline ax renderer (list pep1 pep2)
                                 :color (mpl.rc:rc "axes.edgecolor")
                                 :linewidth (mpl.rc:rc "axes.linewidth"))
          ;; ticks
          (let* ((tickdir (%axis3d-tickdir index))
                 (tickdelta (if (aref highs tickdir) (aref deltas tickdir) (- (aref deltas tickdir))))
                 (tick-out (* +axis3d-tick-outward+ tickdelta))
                 (tick-in (* +axis3d-tick-inward+ tickdelta))
                 (edgep1-tickdir (aref edgep1 tickdir))
                 (out-tickdir (+ edgep1-tickdir tick-out))
                 (in-tickdir (- edgep1-tickdir tick-in))
                 (tick-lw (float (mpl.rc:rc "xtick.major.width") 1.0))
                 (tick-color "black")
                 (tick-pad (float (axis-tick-pad axis) 1.0d0))
                 (label-fontsize (float (axis-tick-label-fontsize axis) 1.0))
                 (label-color (axis-tick-label-color axis)))
            (multiple-value-bind (vmin vmax) (axis-get-view-interval axis)
              (dolist (tk (%axis-compute-major-ticks axis vmin vmax))
                (let ((pos (%v3-copy edgep1)))
                  (setf (aref pos index) (tick-loc tk))
                  (setf (aref pos tickdir) out-tickdir)
                  (let ((p1 (%project-point m pos)))
                    (setf (aref pos tickdir) in-tickdir)
                    (let ((p2 (%project-point m pos)))
                      (%axis3d-draw-polyline ax renderer (list p1 p2)
                                             :color tick-color :linewidth tick-lw)))
                  ;; label: pushed away from the box center
                  (setf (aref pos tickdir) edgep1-tickdir)
                  (let* ((k (* (+ tick-pad +axis3d-tick-label-offset+) deltas-per-point))
                         (ld (%v3 (* k (aref deltas 0)) (* k (aref deltas 1)) (* k (aref deltas 2))))
                         (lp (%project-point m (%move-from-center pos centers ld axmask))))
                    (%axis3d-draw-text ax renderer lp (tick-label-text tk)
                                       :fontsize label-fontsize :color label-color
                                       :ha :center :va :top))))))
          ;; axis label
          (let ((text (axis-label-text axis)))
            (when (and text (plusp (length text)))
              (let* ((mid (%v3 (* 0.5d0 (+ (aref edgep1 0) (aref edgep2 0)))
                               (* 0.5d0 (+ (aref edgep1 1) (aref edgep2 1)))
                               (* 0.5d0 (+ (aref edgep1 2) (aref edgep2 2)))))
                     (lp (%project-point m (%move-from-center mid centers labeldeltas axmask)))
                     (rotate (let ((r (axis-3d-rotate-label axis)))
                               (if (null r) (> (length text) 4) (eq r t))))
                     (angle (if rotate
                                (%norm-text-angle (* (/ 180 pi) (atan dy dx)))
                                0.0d0)))
                (%axis3d-draw-text ax renderer lp text
                                   :fontsize 10.0 :color "black"
                                   :ha :center :va :center :rotation angle)))))))))

(defun %norm-text-angle (a)
  "ANGLE (degrees) normalized to -90 < a <= 90 (art3d._norm_text_angle)."
  (let ((a (mod (+ a 180) 180)))
    (if (> a 90) (- a 180) a)))
