;;;; contour.lisp — ContourSet and QuadContourSet classes
;;;; Ported from matplotlib's contour.py
;;;; Pure CL implementation — no CFFI.
;;;;
;;;; ContourSet manages contour lines or filled contours for a 2D scalar field.
;;;; Uses marching squares algorithm (from algorithms/marching-squares.lisp)
;;;; and LineCollection/PolyCollection for rendering.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; ContourSet — base class for contour plotting
;;; ============================================================

(defclass contour-set (mpl.rendering:artist)
  ((cs-levels :initarg :levels
              :initform nil
              :accessor contourset-levels
              :documentation "List of contour level values.")
   (cs-collections :initarg :collections
                   :initform nil
                   :accessor contourset-collections
                   :documentation "List of collections (LineCollection or PolyCollection), one per level.")
   (cs-cmap :initarg :cmap
             :initform nil
             :accessor contourset-cmap
             :documentation "Colormap for mapping levels to colors.")
   (cs-norm :initarg :norm
             :initform nil
             :accessor contourset-norm
             :documentation "Normalization for mapping level values to [0,1].")
   (cs-filled-p :initarg :filled
                 :initform nil
                 :accessor contourset-filled-p
                 :type boolean
                 :documentation "T if this is a filled contour set (contourf).")
   (cs-linewidths :initarg :linewidths
                   :initform '(1.0)
                   :accessor contourset-linewidths
                   :documentation "Line widths for contour lines.")
   (cs-linestyles :initarg :linestyles
                   :initform '(:solid)
                   :accessor contourset-linestyles
                   :documentation "Line styles for contour lines.")
   (cs-colors :initarg :colors
               :initform nil
               :accessor contourset-colors
               :documentation "Explicit colors for contour lines/fills.")
   (cs-label-texts :initform nil
                    :accessor contourset-label-texts
                    :documentation "List of Text artists for contour labels.")
   (cs-label-levels :initform nil
                     :accessor contourset-label-levels
                     :documentation "Levels that have labels."))
  (:default-initargs :zorder 2)
  (:documentation "A set of contour lines or filled regions.
Ported from matplotlib.contour.ContourSet.
Contains one collection (LineCollection or PolyCollection) per level."))

;;; ============================================================
;;; ContourSet — draw method
;;; ============================================================

(defmethod mpl.rendering:draw ((cs contour-set) renderer)
  "Draw all contour collections and labels."
  (unless (mpl.rendering:artist-visible cs)
    (return-from mpl.rendering:draw))
  ;; Propagate our own (up-to-date) transform to all child collections.
  ;; The axes draw loop updates the contour-set's transform via artist-transform,
  ;; but the child collections still hold the stale transform from creation time.
  (let ((tr (mpl.rendering:get-artist-transform cs)))
    (when tr
      (dolist (coll (contourset-collections cs))
        (when coll
          (setf (mpl.rendering:artist-transform coll) tr)))))
  ;; Draw each collection
  (dolist (coll (contourset-collections cs))
    (when coll
      (mpl.rendering:draw coll renderer)))
  ;; Draw labels
  (dolist (txt (contourset-label-texts cs))
    (when txt
      (mpl.rendering:draw txt renderer)))
  (setf (mpl.rendering:artist-stale cs) nil))

;;; ============================================================
;;; ContourSet — accessors
;;; ============================================================

(defun contourset-get-paths (cs)
  "Return all contour paths from all collections."
  (loop for coll in (contourset-collections cs)
        when coll
        append (mpl.rendering:collection-get-paths coll)))

;;; ============================================================
;;; QuadContourSet — contours on regular grids
;;; ============================================================

(defclass quad-contour-set (contour-set)
  ((qcs-x :initarg :x
           :initform nil
           :accessor qcs-x
           :documentation "1D sequence of X coordinates.")
   (qcs-y :initarg :y
           :initform nil
           :accessor qcs-y
           :documentation "1D sequence of Y coordinates.")
   (qcs-z :initarg :z
           :initform nil
           :accessor qcs-z
           :documentation "2D array (NY x NX) of scalar values."))
  (:documentation "ContourSet for regular quadrilateral grids.
Ported from matplotlib.contour.QuadContourSet."))

;;; ============================================================
;;; Helper: resolve colors from levels
;;; ============================================================

(defun %contour-level-colors (cs levels filled-p)
  "Compute colors for each level from cmap/norm or explicit colors.
Returns a list of color specs (one per level for lines, one per band for filled)."
  (let ((colors (contourset-colors cs))
        (cmap (contourset-cmap cs))
        (norm (contourset-norm cs)))
    (cond
      ;; Explicit colors provided
      (colors
       (let ((n (if filled-p (1- (length levels)) (length levels))))
         (loop for i from 0 below n
               collect (if (listp colors)
                           (elt colors (mod i (length colors)))
                           colors))))
      ;; Use cmap + norm
      ((and cmap norm)
       (let* ((n (if filled-p (1- (length levels)) (length levels)))
              (result nil))
         (dotimes (i n)
           (let* ((val (if filled-p
                           ;; For filled: use midpoint of band
                           (* 0.5d0 (+ (float (elt levels i) 1.0d0)
                                       (float (elt levels (1+ i)) 1.0d0)))
                           ;; For lines: use level value
                           (float (elt levels i) 1.0d0)))
                  (normalized (mpl.primitives:normalize-call norm val))
                  (rgba (mpl.primitives:colormap-call cmap normalized)))
             (push rgba result)))
         (nreverse result)))
      ;; Default: use a simple color cycle
      (t
       (let ((n (if filled-p (1- (length levels)) (length levels)))
             (default-colors '("C0" "C1" "C2" "C3" "C4" "C5" "C6" "C7" "C8" "C9")))
         (loop for i from 0 below n
               collect (elt default-colors (mod i 10))))))))

;;; ============================================================
;;; Build contour line collections (for contour)
;;; ============================================================

(defun %build-contour-line-collections (cs x y z levels)
  "Build LineCollection per level for contour lines.
Returns list of LineCollection instances."
  (let* ((colors (%contour-level-colors cs levels nil))
         (linewidths (contourset-linewidths cs))
         (linestyles (contourset-linestyles cs))
         (collections nil))
    (loop for level in levels
          for i from 0
          for color = (elt colors i)
          for lw = (if (numberp linewidths)
                       linewidths
                       (elt linewidths (mod i (length linewidths))))
          for ls = (if (keywordp linestyles)
                       linestyles
                       (elt linestyles (mod i (length linestyles))))
          do
             (let* ((paths (marching-squares-single-level x y z (float level 1.0d0)))
                    (segments (mapcar (lambda (path)
                                       ;; Each path is already a list of (x y) points
                                       path)
                                     paths))
                    (lc (when segments
                          (mpl.rendering:make-line-collection
                           :segments segments
                           :edgecolors (if (vectorp color)
                                           ;; RGBA vector — convert to list for cycling
                                           (list color)
                                           (list color))
                           :linewidths (list lw)
                           :linestyles (list ls)
                           :zorder (mpl.rendering:artist-zorder cs)))))
               (push lc collections)))
    (nreverse collections)))

;;; ============================================================
;;; Build filled contour collections (for contourf)
;;; ============================================================

(defun %build-contourf-collections (cs x y z levels)
  "Build PolyCollection per level pair for filled contours.
Returns list of PolyCollection instances."
  (let* ((colors (%contour-level-colors cs levels t))
         (collections nil))
    (loop for i from 0 below (1- (length levels))
          for lo = (float (elt levels i) 1.0d0)
          for hi = (float (elt levels (1+ i)) 1.0d0)
          for color = (elt colors i)
          do
             (let* ((polygons (marching-squares-filled x y z lo hi))
                    (pc (when polygons
                          (let ((coll (make-instance 'mpl.rendering:poly-collection
                                                     :verts polygons
                                                     :facecolors (if (vectorp color)
                                                                     (list color)
                                                                     (list color))
                                                     :edgecolors nil
                                                     :linewidths '(0.0)
                                                     :zorder (mpl.rendering:artist-zorder cs))))
                            coll))))
               (push pc collections)))
    (nreverse collections)))

;;; ============================================================
;;; QuadContourSet initialization
;;; ============================================================

(defmethod initialize-instance :after ((qcs quad-contour-set) &key x y z levels
                                                                    colors cmap norm
                                                                    filled
                                                                    linewidths linestyles
                                                                    alpha)
  "After initialization: run marching squares and create collections."
  (declare (ignore colors cmap norm linewidths linestyles))
  ;; Compute Z range for auto-level selection
  (let* ((ny (array-dimension z 0))
         (nx (array-dimension z 1))
         (zmin most-positive-double-float)
         (zmax most-negative-double-float))
    ;; Find Z range
    (dotimes (j ny)
      (dotimes (i nx)
        (let ((val (float (aref z j i) 1.0d0)))
          (when (< val zmin) (setf zmin val))
          (when (> val zmax) (setf zmax val)))))
    ;; Auto-select levels if not provided, or if an integer (= number of levels)
    (cond
      ((null levels)
       (setf levels (if filled
                        (auto-select-levels-filled zmin zmax 7)
                        (auto-select-levels zmin zmax 7))))
      ((integerp levels)
       (let ((n levels))
         (setf levels (if filled
                         (auto-select-levels-filled zmin zmax n)
                         (auto-select-levels zmin zmax n))))))
    (setf (contourset-levels qcs) levels)
    ;; Set up normalization if cmap provided but no norm
    (when (and (contourset-cmap qcs) (null (contourset-norm qcs)))
      (setf (contourset-norm qcs)
            (mpl.primitives:make-normalize :vmin zmin :vmax zmax)))
    ;; Build collections
    (if filled
        (setf (contourset-collections qcs)
              (%build-contourf-collections qcs x y z levels))
        (setf (contourset-collections qcs)
              (%build-contour-line-collections qcs x y z levels)))
    ;; Apply alpha to all collections
    (when alpha
      (dolist (coll (contourset-collections qcs))
        (when coll
          (setf (mpl.rendering:artist-alpha coll) (float alpha 1.0d0)))))))

;;; ============================================================
;;; contour — draw contour lines on axes
;;; ============================================================

(defun contour (ax x y z &key levels colors linewidths linestyles
                              cmap norm alpha (zorder 2))
  "Draw contour lines on axes AX.

AX — an axes-base instance.
X — 1D sequence of X coordinates (length NX).
Y — 1D sequence of Y coordinates (length NY).
Z — 2D array (NY x NX) of scalar values.
LEVELS — list of level values (auto-selected if nil).
COLORS — explicit colors for lines.
LINEWIDTHS — line width(s).
LINESTYLES — line style(s).
CMAP — colormap for level coloring.
NORM — normalization instance.
ALPHA — transparency.
ZORDER — drawing order (default 2).

Returns a QuadContourSet."
  (let* ((effective-cmap (if (and (null colors) (null cmap))
                             (mpl.primitives:get-colormap :viridis)
                             (when cmap
                               (if (keywordp cmap)
                                   (mpl.primitives:get-colormap cmap)
                                   cmap))))
         (cs (make-instance 'quad-contour-set
                            :x x :y y :z z
                            :levels levels
                            :colors colors
                            :cmap effective-cmap
                            :norm norm
                            :filled nil
                            :linewidths (or linewidths '(1.5))
                            :linestyles (or linestyles '(:solid))
                            :alpha alpha
                            :zorder zorder)))
    ;; Set transforms on each collection
    (dolist (coll (contourset-collections cs))
      (when coll
        (setf (mpl.rendering:artist-transform coll)
              (axes-base-trans-data ax))))
    ;; Add to axes as artist
    (axes-add-artist ax cs)
    ;; Update data limits from X/Y range
    (axes-update-datalim ax x y)
    (axes-autoscale-view ax)
    cs))

;;; ============================================================
;;; contourf — draw filled contours on axes
;;; ============================================================

(defun contourf (ax x y z &key levels cmap norm alpha colors (zorder 1))
  "Draw filled contours on axes AX.

AX — an axes-base instance.
X — 1D sequence of X coordinates (length NX).
Y — 1D sequence of Y coordinates (length NY).
Z — 2D array (NY x NX) of scalar values.
LEVELS — list of boundary level values (auto-selected if nil).
CMAP — colormap for fill coloring.
NORM — normalization instance.
ALPHA — transparency.
COLORS — explicit colors for fills.
ZORDER — drawing order (default 1).

Returns a QuadContourSet."
  (let* ((effective-cmap (if (and (null colors) (null cmap))
                             (mpl.primitives:get-colormap :viridis)
                             (when cmap
                               (if (keywordp cmap)
                                   (mpl.primitives:get-colormap cmap)
                                   cmap))))
         (cs (make-instance 'quad-contour-set
                            :x x :y y :z z
                            :levels levels
                            :colors colors
                            :cmap effective-cmap
                            :norm norm
                            :filled t
                            :linewidths '(0.0)
                            :linestyles '(:solid)
                            :alpha alpha
                            :zorder zorder)))
    ;; Set transforms on each collection
    (dolist (coll (contourset-collections cs))
      (when coll
        (setf (mpl.rendering:artist-transform coll)
              (axes-base-trans-data ax))))
    ;; Add to axes as artist
    (axes-add-artist ax cs)
    ;; Update data limits from X/Y range
    (axes-update-datalim ax x y)
    (axes-autoscale-view ax)
    cs))

;;; ============================================================
;;; clabel — add labels to contour lines
;;; ============================================================

(defun clabel (cs &key (fontsize 10) (inline nil) (fmt nil))
  "Add labels to contour lines in CS.

CS — a contour-set instance (from contour).
FONTSIZE — label font size in points (default 10).
INLINE — if T, break contour line at label (not implemented, placeholder).
FMT — format string for levels (default \"~,2F\").

Returns a list of Text artists."
  (declare (ignore inline))
  (let* ((levels (contourset-levels cs))
         (collections (contourset-collections cs))
         (format-str (or fmt "~,2F"))
         (labels nil))
    (loop for level in levels
          for coll in collections
          when coll
          do
             ;; Find a suitable label position: midpoint of longest path
             (let* ((paths (when (typep coll 'mpl.rendering:line-collection)
                             (mpl.rendering:line-collection-segments coll)))
                    (best-path nil)
                    (best-len 0))
               ;; Find longest path
               (dolist (path paths)
                 (when (> (length path) best-len)
                   (setf best-path path
                         best-len (length path))))
               ;; Place label at midpoint of best path
               (when (and best-path (>= best-len 2))
                 (let* ((mid-idx (floor best-len 2))
                        (pt (elt best-path mid-idx))
                        (label-text (format nil format-str level))
                        (text (make-instance 'mpl.rendering:text-artist
                                             :x (float (first pt) 1.0d0)
                                             :y (float (second pt) 1.0d0)
                                             :text label-text
                                             :fontsize (float fontsize 1.0d0)
                                             :horizontalalignment :center
                                             :verticalalignment :center
                                             :color "black"
                                             :zorder (+ 2 (mpl.rendering:artist-zorder cs)))))
                   (push text labels)))))
    ;; Store labels
    (setf (contourset-label-texts cs) (nreverse labels))
    (contourset-label-texts cs)))
