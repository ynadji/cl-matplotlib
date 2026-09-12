;;;; art3d.lisp — 3D artists: lines, scatter markers and polygon meshes
;;;; that carry (x y z) data and project themselves onto the 2D artist
;;;; they inherit from. Port of mpl_toolkits/mplot3d/art3d.py.
;;;;
;;;; Protocol: the owning axes-3d computes its projection matrix M once
;;;; per draw and calls DO-3D-PROJECTION on every 3D artist. Each artist
;;;; writes its projected (x y) into the inherited 2D slots — the ordinary
;;;; 2D draw then runs unchanged through the axes' transData — and returns
;;;; a depth (the smallest projected z; larger z is farther from the eye)
;;;; that the axes uses to order artists back to front.

(in-package #:cl-matplotlib.rendering)

(defgeneric do-3d-projection (artist m)
  (:documentation "Project ARTIST's 3D data through the mat4 M into its 2D
slots. Returns the artist's depth (minimum projected z), or NIL when it
has no points."))

;;; ============================================================
;;; Color helpers
;;; ============================================================

(defun %rgba-list (color)
  "COLOR (name, \"Cn\", or rgb/rgba sequence) as a list of four doubles."
  (let ((v (mpl.colors:to-rgba color)))
    (list (float (elt v 0) 1.0d0) (float (elt v 1) 1.0d0)
          (float (elt v 2) 1.0d0) (float (elt v 3) 1.0d0))))

(defun %rgba-lists (colors)
  "COLORS — a single color spec or a sequence of them — as a list of rgba lists.
A bare color name or one rgb(a) sequence of numbers counts as a single color."
  (cond ((null colors) nil)
        ((stringp colors) (list (%rgba-list colors)))
        ((and (typep colors 'sequence)
              (plusp (length colors))
              (numberp (elt colors 0)))
         (list (%rgba-list colors)))
        (t (map 'list #'%rgba-list colors))))

(defun %nth-cyclic (list n i)
  (nth (mod i n) list))

;;; ============================================================
;;; Depth shading (art3d._zalpha)
;;; ============================================================

(defun zalpha (colors zs)
  "Scale each color's alpha by 1 - norm(z)*0.7 so that farther points
(larger z) are fainter. COLORS is a list of rgba lists (cycled to the
length of ZS); ZS a sequence of projected depths."
  (let* ((n (length zs))
         (nc (length colors)))
    (if (or (zerop n) (zerop nc))
        nil
        (let* ((zmin (reduce #'min zs))
               (zmax (reduce #'max zs))
               (range (- zmax zmin)))
          (loop for i below n
                for z = (elt zs i)
                for c = (%nth-cyclic colors nc i)
                collect (let ((sat (- 1.0d0 (* 0.7d0 (if (zerop range) 0.0d0 (/ (- z zmin) range))))))
                          (list (first c) (second c) (third c) (* (fourth c) sat))))))))

;;; ============================================================
;;; Normals and lighting (art3d._generate_normals / _shade_colors)
;;; ============================================================

(defun generate-normals (polygons)
  "One normal (vec3) per polygon, from three vertices spaced around it
(indices 0, n/3, 2n/3), as matplotlib does. POLYGONS is a list of lists of
(x y z)."
  (loop for ps in polygons
        collect (let* ((n (length ps))
                       (p1 (elt ps 0))
                       (p2 (elt ps (floor n 3)))
                       (p3 (elt ps (floor (* 2 n) 3)))
                       (v1 (mpl.primitives:vec3-sub (apply #'mpl.primitives:vec3 (subseq p1 0 3))
                                                    (apply #'mpl.primitives:vec3 (subseq p2 0 3))))
                       (v2 (mpl.primitives:vec3-sub (apply #'mpl.primitives:vec3 (subseq p2 0 3))
                                                    (apply #'mpl.primitives:vec3 (subseq p3 0 3)))))
                  (mpl.primitives:vec3-cross v1 v2))))

(defun light-direction (&key (azdeg 225.0d0) (altdeg 19.4712d0))
  "Unit vector toward the light, as matplotlib.colors.LightSource.direction."
  (let ((az (* (/ pi 180) (- 90.0d0 azdeg)))
        (alt (* (/ pi 180) altdeg)))
    (mpl.primitives:vec3 (* (cos az) (cos alt)) (* (sin az) (cos alt)) (sin alt))))

(defun shade-colors (colors normals &key (light (light-direction)))
  "Shade COLORS (list of rgba lists, cycled over NORMALS) by the angle
between each normal and LIGHT: matplotlib maps the cosine from [-1, 1] to
a brightness in [0.3, 1]. A zero normal shades as cosine 0. Alpha is kept."
  (let ((nc (length colors)))
    (loop for nrm in normals
          for i from 0
          collect (let* ((c (%nth-cyclic colors nc i))
                         (len (mpl.primitives:vec3-norm nrm))
                         (cosang (if (zerop len) 0.0d0
                                     (/ (mpl.primitives:vec3-dot nrm light) len)))
                         ;; Normalize(-1,1) then Normalize(0.3,1).inverse
                         (brightness (+ 0.3d0 (* 0.7d0 (/ (+ cosang 1.0d0) 2.0d0)))))
                    (list (* brightness (first c)) (* brightness (second c))
                          (* brightness (third c)) (fourth c))))))

;;; ============================================================
;;; Line3D
;;; ============================================================

(defclass line-3d (line-2d)
  ((xs3d :initarg :xs3d :initform nil :accessor line-3d-xs)
   (ys3d :initarg :ys3d :initform nil :accessor line-3d-ys)
   (zs3d :initarg :zs3d :initform nil :accessor line-3d-zs))
  (:documentation "A Line2D whose data lives in 3D; the 2D xdata/ydata are
the projection of the last DO-3D-PROJECTION. Port of art3d.Line3D."))

(defun make-line-3d (xs ys zs &rest line-initargs)
  "A line-3d through the points XS YS ZS. LINE-INITARGS are line-2d
initargs (:color :linewidth :linestyle :marker :label ...)."
  (let ((xs (map 'list (lambda (v) (float v 1.0d0)) xs))
        (ys (map 'list (lambda (v) (float v 1.0d0)) ys))
        (zs (map 'list (lambda (v) (float v 1.0d0)) zs)))
    (apply #'make-instance 'line-3d
           :xs3d xs :ys3d ys :zs3d zs
           :xdata xs :ydata ys
           line-initargs)))

(defmethod do-3d-projection ((line line-3d) m)
  (multiple-value-bind (txs tys tzs)
      (mpl.primitives:proj-transform m (line-3d-xs line) (line-3d-ys line) (line-3d-zs line))
    (line-2d-set-data line (coerce txs 'list) (coerce tys 'list))
    (if (plusp (length tzs)) (reduce #'min tzs) nil)))

;;; ============================================================
;;; Path3DCollection — scatter markers
;;; ============================================================

(defclass path-3d-collection (path-collection)
  ((offsets3d :initarg :offsets3d :initform nil :accessor path-3d-collection-offsets3d
              :documentation "List of (x y z) marker positions.")
   (depthshade :initarg :depthshade :initform t :accessor path-3d-collection-depthshade)
   (sizes3d :initform nil :accessor %path-3d-sizes3d)
   (facecolors3d :initform nil :accessor %path-3d-facecolors3d)
   (edgecolors3d :initform nil :accessor %path-3d-edgecolors3d)
   (vzs :initform nil :accessor path-3d-collection-vzs
        :documentation "Projected depths in original point order, after the last projection."))
  (:documentation "A PathCollection of markers at 3D positions, drawn back
to front and optionally depth-shaded. Port of art3d.Path3DCollection."))

(defmethod initialize-instance :after ((pc path-3d-collection) &key)
  ;; Keep the caller's per-point properties; the 2D slots get the
  ;; depth-sorted versions on every projection.
  (setf (%path-3d-sizes3d pc) (path-collection-sizes pc)
        (%path-3d-facecolors3d pc) (%rgba-lists (collection-facecolors pc))
        (%path-3d-edgecolors3d pc) (%rgba-lists (collection-edgecolors pc)))
  (unless (collection-offsets pc)
    (setf (collection-offsets pc)
          (mapcar (lambda (p) (list (first p) (second p))) (path-3d-collection-offsets3d pc)))))

(defmethod do-3d-projection ((pc path-3d-collection) m)
  (let* ((pts (path-3d-collection-offsets3d pc))
         (n (length pts)))
    (when (zerop n)
      (setf (collection-offsets pc) nil)
      (return-from do-3d-projection nil))
    (multiple-value-bind (txs tys tzs)
        (mpl.primitives:proj-transform m (mapcar #'first pts) (mapcar #'second pts) (mapcar #'third pts))
      (setf (path-3d-collection-vzs pc) tzs)
      ;; back to front: descending projected z
      (let* ((order (sort (loop for i below n collect i) #'> :key (lambda (i) (aref tzs i))))
             (reorder (lambda (list)
                        (if (and list (> (length list) 1))
                            (loop for i in order collect (%nth-cyclic list (length list) i))
                            list)))
             (facecolors (%path-3d-facecolors3d pc))
             (edgecolors (%path-3d-edgecolors3d pc)))
        (when (path-3d-collection-depthshade pc)
          (setf facecolors (zalpha facecolors tzs)
                edgecolors (zalpha edgecolors tzs)))
        (setf (collection-offsets pc)
              (loop for i in order collect (list (aref txs i) (aref tys i)))
              (path-collection-sizes pc) (funcall reorder (%path-3d-sizes3d pc))
              (collection-facecolors pc) (funcall reorder facecolors)
              (collection-edgecolors pc) (funcall reorder edgecolors))
        (reduce #'min tzs)))))

;;; ============================================================
;;; Poly3DCollection — surfaces, bars, triangulations
;;; ============================================================

(defclass poly-3d-collection (poly-collection mpl.primitives:scalar-mappable)
  ((verts3d :initarg :verts3d :initform nil :accessor poly-3d-collection-verts3d
            :documentation "List of polygons, each a list of (x y z).")
   (zsort :initarg :zsort :initform :average :accessor poly-3d-collection-zsort
          :documentation ":average, :min or :max of a polygon's projected z decides its order.")
   (facecolors3d :initform nil :accessor %poly-3d-facecolors3d)
   (edgecolors3d :initform nil :accessor %poly-3d-edgecolors3d)
   (sort-zpos :initarg :sort-zpos :initform nil :accessor poly-3d-collection-sort-zpos
              :documentation "When set, the whole collection sorts at this world z instead of its own depth."))
  (:documentation "A PolyCollection of 3D polygons drawn with the painter's
algorithm. Colors may be given directly (:facecolors/:edgecolors), shaded
by a light (:shade t), or mapped from per-polygon values through the
inherited scalar-mappable (set SM-ARRAY, SM-CMAP, SM-NORM).
Port of art3d.Poly3DCollection."))

(defmethod initialize-instance :after ((pc poly-3d-collection) &key shade light)
  (let ((faces (%rgba-lists (collection-facecolors pc)))
        (edges (%rgba-lists (collection-edgecolors pc))))
    (when shade
      (let ((normals (generate-normals (poly-3d-collection-verts3d pc))))
        (when faces (setf faces (shade-colors faces normals :light (or light (light-direction)))))
        (when edges (setf edges (shade-colors edges normals :light (or light (light-direction)))))))
    (setf (%poly-3d-facecolors3d pc) faces
          (%poly-3d-edgecolors3d pc) edges)
    ;; a first 2D projection is only meaningful after do-3d-projection;
    ;; leave the 2D verts empty until then
    (setf (poly-collection-verts pc) nil)))

(defun %zsort-key (zsort zs)
  (ecase zsort
    (:average (/ (reduce #'+ zs) (length zs)))
    (:min (reduce #'min zs))
    (:max (reduce #'max zs))))

(defmethod do-3d-projection ((pc poly-3d-collection) m)
  (let* ((polys (poly-3d-collection-verts3d pc))
         (n (length polys)))
    (when (zerop n)
      (setf (poly-collection-verts pc) nil)
      (return-from do-3d-projection nil))
    ;; colormapped faces: recompute from the scalar array each time so
    ;; clim/cmap changes (e.g. from a colorbar) are honored
    (let ((values (mpl.primitives:sm-array pc)))
      (when (and values (mpl.primitives:sm-cmap pc))
        (setf (%poly-3d-facecolors3d pc)
              (map 'list (lambda (v)
                           (let ((rgba (mpl.primitives:scalar-mappable-to-rgba pc v)))
                             (list (float (elt rgba 0) 1.0d0) (float (elt rgba 1) 1.0d0)
                                   (float (elt rgba 2) 1.0d0) (float (elt rgba 3) 1.0d0))))
                   values))))
    (let* ((faces (%poly-3d-facecolors3d pc))
           (edges (%poly-3d-edgecolors3d pc))
           (nf (length faces))
           (ne (length edges))
           (projected
             (loop for poly in polys
                   for i from 0
                   collect (multiple-value-bind (txs tys tzs)
                               (mpl.primitives:proj-transform
                                m (mapcar #'first poly) (mapcar #'second poly) (mapcar #'third poly))
                             (list (%zsort-key (poly-3d-collection-zsort pc) tzs)
                                   (loop for k below (length txs) collect (list (aref txs k) (aref tys k)))
                                   (when (plusp nf) (%nth-cyclic faces nf i))
                                   (when (plusp ne) (%nth-cyclic edges ne i))
                                   (reduce #'min tzs)))))
           (sorted (sort projected #'> :key #'first)))
      ;; fresh lists: collection-get-paths memoizes on EQ of the verts list
      (setf (poly-collection-verts pc) (mapcar #'second sorted))
      (when (plusp nf) (setf (collection-facecolors pc) (mapcar #'third sorted)))
      (when (plusp ne) (setf (collection-edgecolors pc) (mapcar #'fourth sorted)))
      (if (poly-3d-collection-sort-zpos pc)
          (nth-value 2 (mpl.primitives:proj-transform-vec m 0 0 (poly-3d-collection-sort-zpos pc)))
          (reduce #'min (mapcar #'fifth sorted))))))
