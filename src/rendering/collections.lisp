;;;; collections.lisp — Collection classes for efficient batch rendering
;;;; Ported from matplotlib's collections.py
;;;; Pure CL implementation — no CFFI.
;;;;
;;;; Collections render many similar artists efficiently.
;;;; Instead of N individual draw calls, a collection issues one batch.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Generic functions for collection protocol
;;; ============================================================

(defgeneric collection-get-paths (collection)
  (:documentation "Return the list of paths to draw for this collection."))

(defgeneric collection-get-transforms (collection)
  (:documentation "Return the list of transforms for this collection's paths.
Each transform is applied to the corresponding path before the offset."))

;;; ============================================================
;;; Collection base class
;;; ============================================================

(defclass collection (artist)
  ((offsets :initarg :offsets
            :initform nil
            :accessor collection-offsets
            :documentation "List of (x y) offset positions for each item.
Each offset is a list of two floats.")
   (trans-offset :initarg :trans-offset
                 :initform nil
                 :accessor collection-trans-offset
                 :documentation "Transform applied to offsets before drawing.")
   (facecolors :initarg :facecolors
               :initform nil
               :accessor collection-facecolors
               :documentation "Face colors: single color string, or list of color specs.
If shorter than paths, cycles modulo length.")
   (edgecolors :initarg :edgecolors
               :initform nil
               :accessor collection-edgecolors
               :documentation "Edge colors: single color string, or list of color specs.")
   (linewidths :initarg :linewidths
               :initform '(1.0)
               :accessor collection-linewidths
               :documentation "Line widths: single number or list of numbers.")
   (linestyles :initarg :linestyles
               :initform '(:solid)
               :accessor collection-linestyles
               :documentation "Line styles: single keyword or list of keywords.")
   (antialiaseds :initarg :antialiaseds
                 :initform '(t)
                 :accessor collection-antialiaseds
                 :documentation "Antialiasing flags: single boolean or list of booleans.")
   (hatch :initarg :hatch
          :initform nil
          :accessor collection-hatch
          :documentation "Hatch pattern string (applies to all items).")
   (pickradius :initarg :pickradius
               :initform 5.0
               :accessor collection-pickradius
               :type real
               :documentation "Pick radius for hit testing.")
   (capstyle :initarg :capstyle
             :initform :butt
             :accessor collection-capstyle
             :documentation "Cap style for all items.")
   (joinstyle :initarg :joinstyle
              :initform :round
              :accessor collection-joinstyle
              :documentation "Join style for all items."))
  (:default-initargs :zorder 1)
  (:documentation "Base class for collections of similar artists.
Ported from matplotlib.collections.Collection.
Collections efficiently render many similar items (paths, lines, polygons)
with per-item colors, linewidths, and transforms."))

;;; ============================================================
;;; Collection property setters
;;; ============================================================

(defun collection-set-offsets (collection offsets)
  "Set the offsets (positions) for the collection items.
OFFSETS is a list of (x y) pairs."
  (setf (collection-offsets collection) offsets)
  (setf (artist-stale collection) t))

(defun collection-set-facecolor (collection colors)
  "Set face colors for the collection.
COLORS can be a single color string or a list of color specs."
  (setf (collection-facecolors collection)
        (if (stringp colors) (list colors) colors))
  (setf (artist-stale collection) t))

(defun collection-set-edgecolor (collection colors)
  "Set edge colors for the collection.
COLORS can be a single color string or a list of color specs."
  (setf (collection-edgecolors collection)
        (if (stringp colors) (list colors) colors))
  (setf (artist-stale collection) t))

(defun collection-set-linewidth (collection widths)
  "Set line widths for the collection.
WIDTHS can be a single number or a list of numbers."
  (setf (collection-linewidths collection)
        (if (numberp widths) (list widths) widths))
  (setf (artist-stale collection) t))

(defun collection-set-color (collection color)
  "Set a uniform color for all items (both face and edge)."
  (collection-set-facecolor collection color)
  (collection-set-edgecolor collection color))

;;; ============================================================
;;; Collection helper: cyclic access
;;; ============================================================

(defun %coll-nth (list index)
  "Access LIST cyclically at INDEX. Returns nil if LIST is nil/empty."
  (when (and list (plusp (length list)))
    (elt list (mod index (length list)))))

;;; ============================================================
;;; Collection default method implementations
;;; ============================================================

(defmethod collection-get-transforms ((c collection))
  "Default: no per-path transforms."
  nil)

(defmethod draw ((c collection) renderer)
  "Draw all items in the collection.
For each item: get path, apply per-item transform, apply offset, draw."
  (unless (artist-visible c)
    (return-from draw))
  (let* ((paths (collection-get-paths c))
         (offsets (collection-offsets c))
         (transforms (collection-get-transforms c))
         (facecolors (collection-facecolors c))
         (edgecolors (collection-edgecolors c))
         (linewidths (collection-linewidths c))
         (linestyles (collection-linestyles c))
         (antialiaseds (collection-antialiaseds c))
         (trans-offset (or (collection-trans-offset c)
                           (get-artist-transform c)))
         (n-items (if offsets (length offsets)
                      (if paths (length paths) 0)))
         (n-paths (if paths (length paths) 0))
         (alpha (or (artist-alpha c) 1.0d0)))
    (when (zerop n-items)
      (return-from draw))
    ;; Draw each item
    (dotimes (i n-items)
      (let* ((path-idx (if (zerop n-paths) 0 (mod i n-paths)))
             (path (when (plusp n-paths) (elt paths path-idx)))
             (offset (when offsets (%coll-nth offsets i)))
             (facecolor (%coll-nth facecolors i))
             (edgecolor (%coll-nth edgecolors i))
             (linewidth (or (%coll-nth linewidths i) 1.0))
             (linestyle (or (%coll-nth linestyles i) :solid))
             (antialiased (let ((aa (%coll-nth antialiaseds i)))
                            (if (null antialiaseds) t aa))))
        (when path
          ;; Build graphics context for this item
          (let ((gc (make-gc :foreground edgecolor
                             :background facecolor
                             :linewidth linewidth
                             :linestyle linestyle
                             :alpha (float alpha 1.0)
                             :antialiased antialiased
                             :capstyle (collection-capstyle c)
                             :joinstyle (collection-joinstyle c))))
            ;; Compute transform: per-item transform (if any) composed with offset
            (let ((item-transform (%coll-nth transforms i))
                  (final-transform nil))
              ;; Start with the item's own transform
              (if item-transform
                  (setf final-transform item-transform)
                  (setf final-transform nil))
              ;; Apply offset via translation
              (when offset
                (let* ((ox (float (first offset) 1.0d0))
                       (oy (float (second offset) 1.0d0))
                       ;; Transform the offset through trans-offset
                       (transformed-offset
                         (if trans-offset
                             (mpl.primitives:transform-point
                              trans-offset (list ox oy))
                             (vector ox oy)))
                       (tx (aref transformed-offset 0))
                       (ty (aref transformed-offset 1))
                       (offset-tr (mpl.primitives:make-affine-2d
                                   :translate (list tx ty))))
                  (if final-transform
                      (setf final-transform
                            (mpl.primitives:compose final-transform offset-tr))
                      (setf final-transform offset-tr))))
              ;; Draw the path
              (renderer-draw-path renderer gc path final-transform
                                  :fill facecolor
                                  :stroke edgecolor)))))))
  (setf (artist-stale c) nil))

;;; ============================================================
;;; LineCollection — efficient rendering of many line segments
;;; ============================================================

(defclass line-collection (collection)
  ((segments :initarg :segments
             :initform nil
             :accessor line-collection-segments
             :documentation "List of line segments. Each segment is a list of (x y) points."))
  (:default-initargs :facecolors nil)
  (:documentation "A collection of line segments.
Ported from matplotlib.collections.LineCollection.
Each segment is rendered as a polyline with per-segment colors/widths."))

(defun collection-set-segments (collection segments)
  "Set the line segments for a LineCollection.
SEGMENTS is a list of segments, where each segment is a list of (x y) points."
  (setf (line-collection-segments collection) segments)
  (setf (artist-stale collection) t))

(defmethod collection-get-paths ((lc line-collection))
  "Convert line segments to paths."
  (let ((segments (line-collection-segments lc)))
    (mapcar (lambda (seg)
              (let* ((n (length seg))
                     (verts (make-array (list n 2) :element-type 'double-float))
                     (codes (make-array n :element-type '(unsigned-byte 8))))
                (dotimes (i n)
                  (let ((pt (elt seg i)))
                    (setf (aref verts i 0) (float (first pt) 1.0d0)
                          (aref verts i 1) (float (second pt) 1.0d0))
                    (setf (aref codes i)
                          (if (zerop i) mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
                (mpl.primitives:%make-mpl-path :vertices verts :codes codes)))
            segments)))

;;; Override draw for LineCollection to use segments as implicit paths+offsets
(defmethod draw ((lc line-collection) renderer)
  "Draw all line segments. Each segment is its own path."
  (unless (artist-visible lc)
    (return-from draw))
  (let* ((paths (collection-get-paths lc))
         (facecolors (collection-facecolors lc))
         (edgecolors (collection-edgecolors lc))
         (linewidths (collection-linewidths lc))
         (linestyles (collection-linestyles lc))
         (antialiaseds (collection-antialiaseds lc))
         (transform (get-artist-transform lc))
         (alpha (or (artist-alpha lc) 1.0d0))
         (n (length paths)))
    (when (zerop n)
      (return-from draw))
    (dotimes (i n)
      (let* ((path (elt paths i))
             (edgecolor (or (%coll-nth edgecolors i) "black"))
             (facecolor (%coll-nth facecolors i))
             (linewidth (or (%coll-nth linewidths i) 1.0))
             (linestyle (or (%coll-nth linestyles i) :solid))
             (antialiased (let ((aa (%coll-nth antialiaseds i)))
                            (if (null antialiaseds) t aa))))
        (let ((gc (make-gc :foreground edgecolor
                           :linewidth linewidth
                           :linestyle linestyle
                           :alpha (float alpha 1.0)
                           :antialiased antialiased
                           :capstyle (collection-capstyle lc)
                           :joinstyle (collection-joinstyle lc))))
          (renderer-draw-path renderer gc path transform
                              :fill facecolor
                              :stroke edgecolor)))))
  (setf (artist-stale lc) nil))

;;; ============================================================
;;; PathCollection — efficient rendering of many paths (scatter)
;;; ============================================================

(defclass path-collection (collection)
  ((paths :initarg :paths
          :initform nil
          :accessor path-collection-paths
          :documentation "List of paths to draw (repeated cyclically at each offset).")
   (sizes :initarg :sizes
          :initform nil
          :accessor path-collection-sizes
          :documentation "Marker sizes in points^2 for each item.
Each size controls the scaling of the path at that offset."))
  (:documentation "A collection of paths drawn at offsets with per-item sizes.
Ported from matplotlib.collections.PathCollection.
Used by scatter() for efficient rendering of many markers."))

(defun collection-set-paths (collection paths)
  "Set the paths to draw for a PathCollection."
  (setf (path-collection-paths collection) paths)
  (setf (artist-stale collection) t))

(defun collection-set-sizes (collection sizes)
  "Set marker sizes for a PathCollection.
SIZES is a list of numbers (area in points^2)."
  (setf (path-collection-sizes collection)
        (if (numberp sizes) (list sizes) sizes))
  (setf (artist-stale collection) t))

(defmethod collection-get-paths ((pc path-collection))
  "Return the paths for this PathCollection."
  (path-collection-paths pc))

(defmethod collection-get-transforms ((pc path-collection))
  "Return per-item scale transforms based on sizes.
Each size (in points^2) is converted to a scale factor."
  (let ((sizes (path-collection-sizes pc))
        (offsets (collection-offsets pc)))
    (when (and sizes offsets)
      (let ((n (length offsets)))
        (loop for i from 0 below n
              for size = (or (%coll-nth sizes i) 36.0)
              for scale = (sqrt (float size 1.0d0))
              collect (mpl.primitives:make-affine-2d
                       :scale (list scale scale)))))))

;;; ============================================================
;;; PatchCollection — efficient rendering of many patches
;;; ============================================================

(defclass patch-collection (collection)
  ((patches :initarg :patches
            :initform nil
            :accessor patch-collection-patches
            :documentation "List of patch objects to render."))
  (:documentation "A collection of patches drawn efficiently as a batch.
Ported from matplotlib.collections.PatchCollection."))

(defun collection-set-patches (collection patches)
  "Set the patches for a PatchCollection."
  (setf (patch-collection-patches collection) patches)
  (setf (artist-stale collection) t))

(defmethod collection-get-paths ((pc patch-collection))
  "Extract paths from the stored patches."
  (mapcar #'get-path (patch-collection-patches pc)))

;;; ============================================================
;;; PolyCollection — efficient rendering of many polygons
;;; ============================================================

(defclass poly-collection (collection)
  ((verts :initarg :verts
          :initform nil
          :accessor poly-collection-verts
          :documentation "List of polygon vertex lists.
Each element is a list of (x y) pairs defining one polygon."))
  (:documentation "A collection of polygons drawn efficiently as a batch.
Ported from matplotlib.collections.PolyCollection."))

(defun collection-set-verts (collection verts)
  "Set polygon vertices for a PolyCollection.
VERTS is a list of vertex lists, each vertex list is a list of (x y) pairs."
  (setf (poly-collection-verts collection) verts)
  (setf (artist-stale collection) t))

(defmethod collection-get-paths ((pc poly-collection))
  "Convert polygon vertices to closed paths."
  (mapcar (lambda (vert-list)
            (let* ((n (length vert-list))
                   ;; +1 for closepoly
                   (total (1+ n))
                   (verts (make-array (list total 2) :element-type 'double-float))
                   (codes (make-array total :element-type '(unsigned-byte 8))))
              (dotimes (i n)
                (let ((pt (elt vert-list i)))
                  (setf (aref verts i 0) (float (first pt) 1.0d0)
                        (aref verts i 1) (float (second pt) 1.0d0))
                  (setf (aref codes i)
                        (if (zerop i) mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
              ;; Close the polygon
              (setf (aref verts n 0) (aref verts 0 0)
                    (aref verts n 1) (aref verts 0 1)
                    (aref codes n) mpl.primitives:+closepoly+)
              (mpl.primitives:%make-mpl-path :vertices verts :codes codes)))
          (poly-collection-verts pc)))

;;; Override draw for PolyCollection — polygons use paths directly, no offsets
(defmethod draw ((pc poly-collection) renderer)
  "Draw all polygons in the PolyCollection."
  (unless (artist-visible pc)
    (return-from draw))
  (let* ((paths (collection-get-paths pc))
         (facecolors (collection-facecolors pc))
         (edgecolors (collection-edgecolors pc))
         (linewidths (collection-linewidths pc))
         (linestyles (collection-linestyles pc))
         (transform (get-artist-transform pc))
         (alpha (or (artist-alpha pc) 1.0d0))
         (n (length paths)))
    (when (zerop n)
      (return-from draw))
    (dotimes (i n)
      (let* ((path (elt paths i))
             (facecolor (or (%coll-nth facecolors i) "C0"))
             (edgecolor (%coll-nth edgecolors i))
             (linewidth (or (%coll-nth linewidths i) 1.0))
             (linestyle (or (%coll-nth linestyles i) :solid)))
        (let ((gc (make-gc :foreground edgecolor
                           :background facecolor
                           :linewidth linewidth
                           :linestyle linestyle
                           :alpha (float alpha 1.0)
                           :antialiased t
                           :capstyle (collection-capstyle pc)
                           :joinstyle (collection-joinstyle pc))))
          (renderer-draw-path renderer gc path transform
                              :fill facecolor
                              :stroke edgecolor)))))
  (setf (artist-stale pc) nil))

;;; ============================================================
;;; QuadMesh — efficient rendering of quadrilateral meshes
;;; ============================================================

(defclass quad-mesh (collection)
  ((mesh-width :initarg :mesh-width
               :initform 0
               :accessor quad-mesh-width
               :type fixnum
               :documentation "Number of columns in the quad mesh.")
   (mesh-height :initarg :mesh-height
                :initform 0
                :accessor quad-mesh-height
                :type fixnum
                :documentation "Number of rows in the quad mesh.")
   (coordinates :initarg :coordinates
                :initform nil
                :accessor quad-mesh-coordinates
                :documentation "3D array of shape (H+1, W+1, 2) with quad corner coordinates.
coordinates[i][j] = (x, y) for corner at row i, col j."))
  (:documentation "A collection of quadrilateral cells forming a mesh.
Ported from matplotlib.collections.QuadMesh.
Used by pcolormesh for efficient rendering of rectangular grids."))

(defmethod collection-get-paths ((qm quad-mesh))
  "Convert quad mesh to individual quadrilateral paths.
Each quad is defined by 4 corners: (i,j), (i,j+1), (i+1,j+1), (i+1,j)."
  (let* ((w (quad-mesh-width qm))
         (h (quad-mesh-height qm))
         (coords (quad-mesh-coordinates qm))
         (paths nil))
    (when (and coords (plusp w) (plusp h))
      (dotimes (row h)
        (dotimes (col w)
          (let* ((verts (make-array '(5 2) :element-type 'double-float))
                 (codes (make-array 5 :element-type '(unsigned-byte 8))))
            ;; Four corners of quad
            (setf (aref verts 0 0) (float (aref coords row col 0) 1.0d0)
                  (aref verts 0 1) (float (aref coords row col 1) 1.0d0)
                  (aref verts 1 0) (float (aref coords row (1+ col) 0) 1.0d0)
                  (aref verts 1 1) (float (aref coords row (1+ col) 1) 1.0d0)
                  (aref verts 2 0) (float (aref coords (1+ row) (1+ col) 0) 1.0d0)
                  (aref verts 2 1) (float (aref coords (1+ row) (1+ col) 1) 1.0d0)
                  (aref verts 3 0) (float (aref coords (1+ row) col 0) 1.0d0)
                  (aref verts 3 1) (float (aref coords (1+ row) col 1) 1.0d0))
            ;; Close the quad
            (setf (aref verts 4 0) (aref verts 0 0)
                  (aref verts 4 1) (aref verts 0 1))
            ;; Codes
            (setf (aref codes 0) mpl.primitives:+moveto+
                  (aref codes 1) mpl.primitives:+lineto+
                  (aref codes 2) mpl.primitives:+lineto+
                  (aref codes 3) mpl.primitives:+lineto+
                  (aref codes 4) mpl.primitives:+closepoly+)
            (push (mpl.primitives:%make-mpl-path :vertices verts :codes codes) paths)))))
    (nreverse paths)))

;;; Override draw for QuadMesh — each quad gets its own facecolor
(defmethod draw ((qm quad-mesh) renderer)
  "Draw the quad mesh. Each quad is drawn as a filled path."
  (unless (artist-visible qm)
    (return-from draw))
  (let* ((paths (collection-get-paths qm))
         (facecolors (collection-facecolors qm))
         (edgecolors (collection-edgecolors qm))
         (linewidths (collection-linewidths qm))
         (transform (get-artist-transform qm))
         (alpha (or (artist-alpha qm) 1.0d0))
         (n (length paths)))
    (when (zerop n)
      (return-from draw))
    (dotimes (i n)
      (let* ((path (elt paths i))
             (facecolor (or (%coll-nth facecolors i) "C0"))
             (edgecolor (%coll-nth edgecolors i))
             (linewidth (or (%coll-nth linewidths i) 0.0)))
        (let ((gc (make-gc :foreground edgecolor
                           :background facecolor
                           :linewidth linewidth
                           :linestyle :solid
                           :alpha (float alpha 1.0)
                           :antialiased nil
                           :capstyle (collection-capstyle qm)
                           :joinstyle (collection-joinstyle qm))))
          (renderer-draw-path renderer gc path transform
                              :fill facecolor
                              :stroke (when (and edgecolor (plusp linewidth))
                                        edgecolor))))))
  (setf (artist-stale qm) nil))

;;; ============================================================
;;; Convenience constructors
;;; ============================================================

(defun make-path-collection (&key paths offsets sizes facecolors edgecolors
                                  linewidths linestyles alpha transform
                                  trans-offset zorder label)
  "Create a PathCollection for scatter-like plots.
PATHS — list of mpl-paths (marker shapes).
OFFSETS — list of (x y) positions.
SIZES — list of marker sizes in points^2.
FACECOLORS — single color or list of colors.
EDGECOLORS — single color or list of colors."
  (let ((pc (make-instance 'path-collection
                           :paths paths
                           :offsets offsets
                           :sizes sizes
                           :facecolors (when facecolors
                                         (if (stringp facecolors)
                                             (list facecolors)
                                             facecolors))
                           :edgecolors (when edgecolors
                                         (if (stringp edgecolors)
                                             (list edgecolors)
                                             edgecolors))
                           :linewidths (if linewidths
                                           (if (numberp linewidths)
                                               (list linewidths)
                                               linewidths)
                                           '(0.5))
                           :linestyles (or linestyles '(:solid))
                           :zorder (or zorder 1)
                           :label (or label ""))))
    (when alpha
      (setf (artist-alpha pc) (float alpha 1.0d0)))
    (when transform
      (setf (artist-transform pc) transform))
    (when trans-offset
      (setf (collection-trans-offset pc) trans-offset))
    pc))

(defun make-line-collection (&key segments edgecolors linewidths linestyles
                                   alpha transform zorder label)
  "Create a LineCollection.
SEGMENTS — list of segments (each segment is a list of (x y) points)."
  (let ((lc (make-instance 'line-collection
                           :segments segments
                           :edgecolors (when edgecolors
                                         (if (stringp edgecolors)
                                             (list edgecolors)
                                             edgecolors))
                           :linewidths (if linewidths
                                           (if (numberp linewidths)
                                               (list linewidths)
                                               linewidths)
                                           '(1.0))
                           :linestyles (or linestyles '(:solid))
                           :zorder (or zorder 1)
                           :label (or label ""))))
    (when alpha
      (setf (artist-alpha lc) (float alpha 1.0d0)))
    (when transform
      (setf (artist-transform lc) transform))
    lc))
