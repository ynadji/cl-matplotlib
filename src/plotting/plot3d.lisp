;;;; plot3d.lisp — 3D plotting functions on an axes-3d: plot3d, scatter3d,
;;;; plot-surface, plot-trisurf, bar3d.
;;;; Port of the corresponding Axes3D methods (matplotlib 3.8.4).

(in-package #:cl-matplotlib.containers)

(defun %next-color (ax)
  (prog1 (format nil "C~D" (mod (axes-base-color-cycle-index ax) 10))
    (incf (axes-base-color-cycle-index ax))))

(defun %check-axes-3d (ax who)
  (unless (typep ax 'axes-3d)
    (error "~A needs an axes-3d (add-subplot ... :projection :3d), got ~S" who ax)))

(defun %broadcast-to (value n)
  "VALUE as a list of N items: a number repeats, a sequence is used as is."
  (if (numberp value)
      (make-list n :initial-element (float value 1.0d0))
      (map 'list (lambda (v) (float v 1.0d0)) value)))

;;; ============================================================
;;; plot3d
;;; ============================================================

(defun plot3d (ax xs ys zs &key color (linewidth 1.5) (linestyle :solid) (marker :none)
                                (markersize nil) (label "") (zorder 2) alpha)
  "Plot the 3D polyline through XS YS ZS on the axes-3d AX (Axes3D.plot).
Returns a list containing the created line-3d."
  (%check-axes-3d ax 'plot3d)
  (let* ((n (min (length xs) (length ys) (length zs)))
         (line (apply #'mpl.rendering:make-line-3d
                      (subseq (coerce xs 'list) 0 n)
                      (subseq (coerce ys 'list) 0 n)
                      (subseq (coerce zs 'list) 0 n)
                      (append (list :color (or color (%next-color ax))
                                    :linewidth linewidth :linestyle linestyle
                                    :marker marker :label label :zorder zorder)
                              (when markersize (list :markersize markersize))
                              (when alpha (list :alpha alpha))))))
    (setf (mpl.rendering:artist-transform line) (axes-base-trans-data ax))
    (axes-add-line ax line)
    (axes-3d-auto-scale-xyz ax xs ys zs)
    (list line)))

;;; ============================================================
;;; scatter3d
;;; ============================================================

(defun %resolve-cmap (cmap)
  (cond ((null cmap) (mpl.primitives:get-colormap (mpl.rc:rc "image.cmap")))
        ((or (keywordp cmap) (stringp cmap)) (mpl.primitives:get-colormap cmap))
        (t cmap)))

(defun %mapped-colors (values cmap norm vmin vmax)
  "Per-point rgba lists for numeric VALUES through NORM (or a Normalize
over VMIN/VMAX, defaulting to the data range) and CMAP.
Returns (values colors scalar-mappable)."
  (let* ((vals (map 'list (lambda (v) (float v 1.0d0)) values))
         (lo (or vmin (reduce #'min vals)))
         (hi (or vmax (reduce #'max vals)))
         (norm (or norm (mpl.primitives:make-normalize :vmin lo :vmax hi)))
         (sm (mpl.primitives:make-scalar-mappable :norm norm :cmap cmap)))
    (values (mapcar (lambda (v)
                      (let ((rgba (mpl.primitives:scalar-mappable-to-rgba sm v)))
                        (list (float (elt rgba 0) 1.0d0) (float (elt rgba 1) 1.0d0)
                              (float (elt rgba 2) 1.0d0) (float (elt rgba 3) 1.0d0))))
                    vals)
            sm)))

(defun scatter3d (ax xs ys zs &key (s 20.0) c color (marker :circle) cmap norm vmin vmax
                                   (depthshade t) (label "") (zorder 1) alpha)
  "Scatter markers at XS YS ZS on the axes-3d AX (Axes3D.scatter).
S is the marker area in points² (a number or one per point). C is a color,
a sequence of colors, or a sequence of numbers mapped through CMAP/NORM.
Markers are drawn back to front and, with DEPTHSHADE, faded with depth.
Returns the path-3d-collection; when C was numeric it carries the
scalar-mappable state for a colorbar."
  (%check-axes-3d ax 'scatter3d)
  (let* ((n (min (length xs) (length ys) (length zs)))
         (xs (subseq (coerce xs 'list) 0 n))
         (ys (subseq (coerce ys 'list) 0 n))
         (zs (subseq (coerce zs 'list) 0 n))
         (spec (or c color))
         (numeric-p (and spec (typep spec 'sequence) (not (stringp spec))
                         (plusp (length spec)) (numberp (elt spec 0))
                         (= (length spec) n)))
         (facecolors (cond (numeric-p (%mapped-colors spec (%resolve-cmap cmap) norm vmin vmax))
                           (spec spec)
                           (t (%next-color ax))))
         (sizes (%broadcast-to s (if (numberp s) 1 n)))
         (edge (mpl.rc:rc "scatter.edgecolors"))
         (fig (axes-base-figure ax))
         (pc (make-instance 'mpl.rendering:path-3d-collection
                            :paths (list (mpl.rendering:make-marker-path (if (eq marker :circle) :o marker)))
                            :offsets3d (mapcar (lambda (x y z) (list (float x 1.0d0) (float y 1.0d0) (float z 1.0d0)))
                                               xs ys zs)
                            :sizes sizes
                            :facecolors facecolors
                            :edgecolors (if (equal edge "face") nil edge)
                            :linewidths (list 0.0)
                            :alpha alpha
                            :zorder zorder
                            :label label
                            :depthshade depthshade
                            :dpi (if fig (figure-dpi fig) 100.0))))
    (axes-add-artist ax pc)
    ;; Axes3D.scatter: markers need headroom — raise the z margin to 0.05
    (when (and (plusp n) (< (axes-3d-zmargin ax) 0.05d0))
      (setf (axes-3d-zmargin ax) 0.05d0))
    (axes-3d-auto-scale-xyz ax xs ys zs)
    pc))

;;; ============================================================
;;; Surfaces
;;; ============================================================

(defun %grid-ref (a i j)
  "Element (I, J) of a 2D array or a list of rows."
  (if (arrayp a) (aref a i j) (elt (elt a i) j)))

(defun %grid-dims (a)
  (if (arrayp a)
      (values (array-dimension a 0) (array-dimension a 1))
      (values (length a) (length (elt a 0)))))

(defun %block-perimeter (x y z r0 r1 c0 c1)
  "The boundary of the sub-grid rows R0..R1, cols C0..C1 as a list of
(x y z), clockwise from the top-left as cbook._array_perimeter does."
  (let ((pts '()))
    (flet ((p (i j) (push (list (float (%grid-ref x i j) 1.0d0)
                                (float (%grid-ref y i j) 1.0d0)
                                (float (%grid-ref z i j) 1.0d0))
                          pts)))
      (loop for j from c0 to c1 do (p r0 j))                   ; top row →
      (loop for i from (1+ r0) to r1 do (p i c1))              ; right column ↓
      (loop for j from (1- c1) downto c0 do (p r1 j))          ; bottom row ←
      (loop for i from (1- r1) downto (1+ r0) do (p i c0)))    ; left column ↑
    (nreverse pts)))

(defun plot-surface (ax x y z &key (rcount 50) (ccount 50) rstride cstride
                                   color cmap norm vmin vmax (shade nil shade-p)
                                   facecolors linewidth edgecolor alpha (zorder 1))
  "Plot the surface Z over the grid X Y (all rows×cols 2D arrays or lists
of rows) on the axes-3d AX (Axes3D.plot_surface). The grid is downsampled
to at most RCOUNT×CCOUNT facets (or by RSTRIDE/CSTRIDE). Faces are a
single COLOR shaded by a light (SHADE, default T), or colormapped by
their mean z through CMAP/NORM/VMIN/VMAX, or given per facet by FACECOLORS.
Returns the poly-3d-collection."
  (%check-axes-3d ax 'plot-surface)
  (multiple-value-bind (rows cols) (%grid-dims z)
    (let* ((rstride (or rstride (max 1 (ceiling rows rcount))))
           (cstride (or cstride (max 1 (ceiling cols ccount))))
           (row-inds (append (loop for r from 0 below (1- rows) by rstride collect r) (list (1- rows))))
           (col-inds (append (loop for c from 0 below (1- cols) by cstride collect c) (list (1- cols))))
           (polys '())
           (colset '())
           (avg-z '()))
      (loop for (r0 r1) on row-inds while r1
            do (loop for (c0 c1) on col-inds while c1
                     for i from 0
                     do (let ((poly (%block-perimeter x y z r0 r1 c0 c1)))
                          (push poly polys)
                          (push (/ (reduce #'+ poly :key #'third) (length poly)) avg-z)
                          (when facecolors
                            (push (%grid-ref facecolors r0 c0) colset)))))
      (setf polys (nreverse polys) avg-z (nreverse avg-z) colset (nreverse colset))
      (let* ((shade (if shade-p shade (null cmap)))
             (fill-color (or color (%next-color ax)))
             (pc (cond
                   (facecolors
                    (make-instance 'mpl.rendering:poly-3d-collection
                                   :verts3d polys :facecolors colset :edgecolors (or edgecolor colset)
                                   :shade shade :linewidths (list (float (or linewidth 0.0) 1.0)) :alpha alpha :zorder zorder))
                   (cmap
                    (let* ((cm (%resolve-cmap cmap))
                           (lo (or vmin (reduce #'min avg-z)))
                           (hi (or vmax (reduce #'max avg-z)))
                           (pc (make-instance 'mpl.rendering:poly-3d-collection
                                              :verts3d polys :edgecolors edgecolor
                                              :linewidths (list (float (or linewidth 0.0) 1.0)) :alpha alpha :zorder zorder
                                              :cmap cm
                                              :norm (or norm (mpl.primitives:make-normalize :vmin lo :vmax hi)))))
                      (setf (mpl.primitives:sm-array pc) (coerce avg-z 'vector))
                      pc))
                   (t
                    (make-instance 'mpl.rendering:poly-3d-collection
                                   :verts3d polys :facecolors fill-color :edgecolors edgecolor
                                   :shade shade :linewidths (list (float (or linewidth 0.0) 1.0)) :alpha alpha :zorder zorder)))))
        (axes-add-artist ax pc)
        (axes-3d-auto-scale-xyz ax x y z)
        pc))))

(defun plot-trisurf (ax x y z &key triangles color cmap norm vmin vmax (shade nil shade-p)
                                    linewidth edgecolor alpha (zorder 1))
  "Plot the triangulated surface of the points X Y Z (Axes3D.plot_trisurf).
TRIANGLES (index triples) may be given; otherwise a Delaunay
triangulation is computed. Coloring as in PLOT-SURFACE. Returns the
poly-3d-collection."
  (%check-axes-3d ax 'plot-trisurf)
  (let* ((tri (ensure-triangulation x y triangles))
         (tx (triangulation-x tri)) (ty (triangulation-y tri))
         (zv (map 'vector (lambda (v) (float v 1.0d0)) z))
         (polys (map 'list (lambda (t3)
                             (mapcar (lambda (i) (list (aref tx i) (aref ty i) (aref zv i)))
                                     (coerce t3 'list)))
                     (triangulation-triangles tri)))
         (avg-z (mapcar (lambda (poly) (/ (reduce #'+ poly :key #'third) 3.0d0)) polys))
         (shade (if shade-p shade (null cmap)))
         (pc (if cmap
                 (let* ((cm (%resolve-cmap cmap))
                        (lo (or vmin (reduce #'min avg-z)))
                        (hi (or vmax (reduce #'max avg-z)))
                        (pc (make-instance 'mpl.rendering:poly-3d-collection
                                           :verts3d polys :edgecolors edgecolor
                                           :linewidths (list (float (or linewidth 0.0) 1.0)) :alpha alpha :zorder zorder
                                           :cmap cm
                                           :norm (or norm (mpl.primitives:make-normalize :vmin lo :vmax hi)))))
                   (setf (mpl.primitives:sm-array pc) (coerce avg-z 'vector))
                   pc)
                 (make-instance 'mpl.rendering:poly-3d-collection
                                :verts3d polys :facecolors (or color (%next-color ax))
                                :edgecolors edgecolor :shade shade
                                :linewidths (list (float (or linewidth 0.0) 1.0)) :alpha alpha :zorder zorder))))
    (axes-add-artist ax pc)
    (axes-3d-auto-scale-xyz ax tx ty zv)
    pc))

;;; ============================================================
;;; bar3d
;;; ============================================================

(defparameter *bar3d-cuboid*
  '(((0 0 0) (0 1 0) (1 1 0) (1 0 0))    ; -z
    ((0 0 1) (1 0 1) (1 1 1) (0 1 1))    ; +z
    ((0 0 0) (1 0 0) (1 0 1) (0 0 1))    ; -y
    ((0 1 0) (0 1 1) (1 1 1) (1 1 0))    ; +y
    ((0 0 0) (0 0 1) (0 1 1) (0 1 0))    ; -x
    ((1 0 0) (1 1 0) (1 1 1) (1 0 1)))   ; +x
  "Unit cuboid faces in Axes3D.bar3d order.")

(defun bar3d (ax x y z dx dy dz &key color (zsort :average) (shade t) alpha edgecolor
                                     linewidth (zorder 1))
  "3D bars with corner X Y Z and size DX DY DZ (each a number or one per
bar) on the axes-3d AX (Axes3D.bar3d). COLOR is one color, one per bar, or
one per face (6 or 6×N). Returns the poly-3d-collection."
  (%check-axes-3d ax 'bar3d)
  (let* ((n (length x))
         (xs (%broadcast-to x n)) (ys (%broadcast-to y n)) (zs (%broadcast-to z n))
         (dxs (%broadcast-to dx n)) (dys (%broadcast-to dy n)) (dzs (%broadcast-to dz n))
         (polys (loop for x0 in xs for y0 in ys for z0 in zs
                      for w in dxs for d in dys for h in dzs
                      append (mapcar (lambda (face)
                                       (mapcar (lambda (c)
                                                 (list (+ x0 (* w (first c)))
                                                       (+ y0 (* d (second c)))
                                                       (+ z0 (* h (third c)))))
                                               face))
                                     *bar3d-cuboid*)))
         (colors (cond ((null color) (list (%next-color ax)))
                       ((or (stringp color) (numberp (elt color 0))) (list color))
                       (t (coerce color 'list))))
         (facecolors (cond ((= (length colors) n)          ; one per bar → six per bar
                            (loop for c in colors append (make-list 6 :initial-element c)))
                           (t colors)))                     ; 1, 6 or 6N: cycled
         (pc (make-instance 'mpl.rendering:poly-3d-collection
                            :verts3d polys :facecolors facecolors :edgecolors edgecolor
                            :shade shade :zsort zsort
                            :linewidths (list (float (or linewidth 0.0) 1.0)) :alpha alpha :zorder zorder)))
    (axes-add-artist ax pc)
    (axes-3d-auto-scale-xyz ax (append xs (mapcar #'+ xs dxs))
                            (append ys (mapcar #'+ ys dys))
                            (append zs (mapcar #'+ zs dzs)))
    pc))
