;;;; tri.lisp — triangulation plot types: triplot, tripcolor,
;;;; tricontour, tricontourf (matplotlib tri* family). Triangulations
;;;; come from src/algorithms/delaunay.lisp or explicit index triples.

(in-package #:cl-matplotlib.containers)

(defun %tri-edges (triangles)
  "Distinct undirected edges of TRIANGLES."
  (let ((seen (make-hash-table :test #'equal))
        (edges '()))
    (dolist (tri triangles edges)
      (destructuring-bind (i j k) tri
        (dolist (e (list (if (< i j) (list i j) (list j i))
                         (if (< j k) (list j k) (list k j))
                         (if (< i k) (list i k) (list k i))))
          (unless (gethash e seen)
            (setf (gethash e seen) t)
            (push e edges)))))))

(defun triplot (ax x y &key triangles (color "C0") (linewidth 1.0)
                            (marker :none) (zorder 2))
  "Draw the edges of a triangulation (matplotlib triplot). TRIANGLES is
an optional sequence of (i j k) index triples; Delaunay when omitted.

Returns the created line artists."
  (declare (ignore marker))
  (let* ((tri (ensure-triangulation x y triangles))
         (tx (triangulation-x tri))
         (ty (triangulation-y tri))
         (lines '()))
    (dolist (e (%tri-edges (triangulation-triangles tri)))
      (destructuring-bind (i j) e
        (let ((line (make-instance 'mpl.rendering:line-2d
                                   :xdata (list (aref tx i) (aref tx j))
                                   :ydata (list (aref ty i) (aref ty j))
                                   :color color
                                   :linewidth linewidth
                                   :zorder zorder)))
          (setf (mpl.rendering:artist-transform line)
                (axes-base-trans-data ax))
          (axes-add-line ax line)
          (push line lines))))
    (axes-update-datalim ax (coerce tx 'list) (coerce ty 'list))
    (axes-autoscale-view ax)
    (setf (mpl.rendering:artist-stale ax) t)
    (nreverse lines)))

(defun tripcolor (ax x y c &key triangles (cmap nil) (vmin nil) (vmax nil)
                                (alpha nil) (zorder 1))
  "Flat-shaded triangulation fill: each triangle colored by the mean of
its vertices' C values (matplotlib tripcolor with point data).

Returns the list of polygon patches."
  (let* ((tri (ensure-triangulation x y triangles))
         (tx (triangulation-x tri))
         (ty (triangulation-y tri))
         (cv (map 'vector (lambda (v) (float v 1.0d0)) c))
         (cmap (or (and cmap (if (typep cmap 'mpl.primitives:colormap)
                                 cmap
                                 (mpl.primitives:get-colormap cmap)))
                   (mpl.primitives:get-colormap "viridis")))
         (tri-vals (mapcar (lambda (tr)
                             (destructuring-bind (i j k) tr
                               (/ (+ (aref cv i) (aref cv j) (aref cv k))
                                  3.0d0)))
                           (triangulation-triangles tri)))
         (lo (or vmin (reduce #'min tri-vals)))
         (hi (or vmax (reduce #'max tri-vals)))
         (span (max (- hi lo) 1d-12))
         (patches '()))
    (loop for tr in (triangulation-triangles tri)
          for v in tri-vals
          do (destructuring-bind (i j k) tr
               (let* ((rgba (mpl.primitives:colormap-call
                             cmap (/ (- v lo) span)))
                      (color (format nil "#~2,'0X~2,'0X~2,'0X"
                                     (round (* 255 (aref rgba 0)))
                                     (round (* 255 (aref rgba 1)))
                                     (round (* 255 (aref rgba 2)))))
                      (poly (make-instance
                             'mpl.rendering:polygon
                             :xy (list (list (aref tx i) (aref ty i))
                                       (list (aref tx j) (aref ty j))
                                       (list (aref tx k) (aref ty k)))
                             :closed t
                             :facecolor color
                             :edgecolor color
                             :linewidth 0.8d0
                             :zorder zorder)))
                 (when alpha
                   (setf (mpl.rendering:artist-alpha poly)
                         (float alpha 1.0d0)))
                 (setf (mpl.rendering:artist-transform poly)
                       (axes-base-trans-data ax))
                 (axes-add-patch ax poly)
                 (push poly patches))))
    (axes-update-datalim ax (coerce tx 'list) (coerce ty 'list))
    ;; tripcolor keeps standard autoscale margins (unlike tricontour[f])
    (axes-autoscale-view ax)
    (setf (mpl.rendering:artist-stale ax) t)
    (nreverse patches)))

(defun %tri-levels (zv n-levels levels)
  "Contour levels: explicit LEVELS, or matplotlib's rule of
MaxNLocator(n+1) ticks over the data range (levels may extend past the
data; the norm spans them)."
  (or (and levels (coerce levels 'list))
      (let ((lo (reduce #'min zv))
            (hi (reduce #'max zv)))
        (coerce (locator-tick-values
                 (make-instance 'max-n-locator :nbins (1+ n-levels))
                 lo hi)
                'list))))

(defun %edge-crossing (x0 y0 z0 x1 y1 z1 level)
  "Interpolated crossing point of LEVEL on the edge (assumes it crosses)."
  (let ((f (/ (- level z0) (- z1 z0))))
    (list (+ x0 (* f (- x1 x0)))
          (+ y0 (* f (- y1 y0))))))

(defun tricontour (ax x y z &key triangles (levels nil) (n-levels 7)
                                 (cmap nil) (colors nil) (linewidth 1.5)
                                 (zorder 2))
  "Contour lines over a triangulation: per triangle, each level crossing
contributes one linearly interpolated segment.

Returns an alist of (level . lines)."
  (let* ((tri (ensure-triangulation x y triangles))
         (tx (triangulation-x tri))
         (ty (triangulation-y tri))
         (zv (map 'vector (lambda (v) (float v 1.0d0)) z))
         (level-list (%tri-levels zv n-levels levels))
         (cmap (or (and cmap (if (typep cmap 'mpl.primitives:colormap)
                                 cmap
                                 (mpl.primitives:get-colormap cmap)))
                   (mpl.primitives:get-colormap "viridis")))
         (lo (reduce #'min level-list))
         (hi (reduce #'max level-list))
         (span (max (- hi lo) 1d-12))
         (result '()))
    (loop for level in level-list
          for level-color
            = (or colors
                  (let ((rgba (mpl.primitives:colormap-call
                               cmap (/ (- level lo) span))))
                    (format nil "#~2,'0X~2,'0X~2,'0X"
                            (round (* 255 (aref rgba 0)))
                            (round (* 255 (aref rgba 1)))
                            (round (* 255 (aref rgba 2))))))
          for lines = '()
          do (dolist (tr (triangulation-triangles tri))
               (destructuring-bind (i j k) tr
                 (let ((pts '()))
                   (loop for (a b) in (list (list i j) (list j k) (list k i))
                         do (let ((za (aref zv a)) (zb (aref zv b)))
                              (when (or (and (< za level) (>= zb level))
                                        (and (>= za level) (< zb level)))
                                (push (%edge-crossing
                                       (aref tx a) (aref ty a) za
                                       (aref tx b) (aref ty b) zb
                                       level)
                                      pts))))
                   (when (= (length pts) 2)
                     (let ((line (make-instance
                                  'mpl.rendering:line-2d
                                  :xdata (mapcar #'first pts)
                                  :ydata (mapcar #'second pts)
                                  :color level-color
                                  :linewidth linewidth
                                  :zorder zorder)))
                       (setf (mpl.rendering:artist-transform line)
                             (axes-base-trans-data ax))
                       (axes-add-line ax line)
                       (push line lines))))))
             (push (cons level lines) result))
    (axes-update-datalim ax (coerce tx 'list) (coerce ty 'list))
    (axes-set-xlim ax :min (reduce #'min tx) :max (reduce #'max tx))
    (axes-set-ylim ax :min (reduce #'min ty) :max (reduce #'max ty))
    (setf (mpl.rendering:artist-stale ax) t)
    (nreverse result)))

(defun %clip-poly-below (points values level)
  "Sutherland-Hodgman clip of the polygon POINTS to VALUES <= LEVEL.
VALUES are the (linear) z at each point. Returns (values points values)."
  (let ((out-p '()) (out-v '()))
    (loop for idx from 0 below (length points)
          for p0 = (elt points idx)
          for v0 = (elt values idx)
          for nidx = (mod (1+ idx) (length points))
          for p1 = (elt points nidx)
          for v1 = (elt values nidx)
          do (when (<= v0 level)
               (push p0 out-p) (push v0 out-v))
             (when (or (and (<= v0 level) (> v1 level))
                       (and (> v0 level) (<= v1 level)))
               (let ((f (/ (- level v0) (- v1 v0))))
                 (push (list (+ (first p0) (* f (- (first p1) (first p0))))
                             (+ (second p0) (* f (- (second p1) (second p0)))))
                       out-p)
                 (push level out-v))))
    (values (nreverse out-p) (nreverse out-v))))

(defun tricontourf (ax x y z &key triangles (levels nil) (n-levels 7)
                                  (cmap nil) (alpha nil) (zorder 1))
  "Filled contour bands over a triangulation: each triangle clipped to
each band [l0, l1) contributes at most one polygon.

Returns an alist of (band-low . patches)."
  (let* ((tri (ensure-triangulation x y triangles))
         (tx (triangulation-x tri))
         (ty (triangulation-y tri))
         (zv (map 'vector (lambda (v) (float v 1.0d0)) z))
         (level-list (%tri-levels zv n-levels levels))
         ;; bands are consecutive level pairs; the color norm spans the
         ;; full level range (matplotlib: cmap(norm(band midpoint)))
         (bands (loop for (l0 l1) on level-list
                      while l1 collect (list l0 l1)))
         (norm-lo (first level-list))
         (norm-hi (car (last level-list)))
         (norm-span (max (- norm-hi norm-lo) 1d-12))
         (cmap (or (and cmap (if (typep cmap 'mpl.primitives:colormap)
                                 cmap
                                 (mpl.primitives:get-colormap cmap)))
                   (mpl.primitives:get-colormap "viridis")))
         (result '()))
    (loop for (l0 l1) in bands
          for rgba = (mpl.primitives:colormap-call
                      cmap (/ (- (/ (+ l0 l1) 2.0d0) norm-lo) norm-span))
          for color = (format nil "#~2,'0X~2,'0X~2,'0X"
                              (round (* 255 (aref rgba 0)))
                              (round (* 255 (aref rgba 1)))
                              (round (* 255 (aref rgba 2))))
          for patches = '()
          do (dolist (tr (triangulation-triangles tri))
               (destructuring-bind (i j k) tr
                 (let ((pts (list (list (aref tx i) (aref ty i))
                                  (list (aref tx j) (aref ty j))
                                  (list (aref tx k) (aref ty k))))
                       (vals (list (aref zv i) (aref zv j) (aref zv k))))
                   ;; clip to z <= l1, then to z >= l0 (negate)
                   (multiple-value-bind (p1 v1)
                       (%clip-poly-below pts vals l1)
                     (when (>= (length p1) 3)
                       (multiple-value-bind (p2 v2)
                           (%clip-poly-below
                            p1 (mapcar #'- v1) (- l0))
                         (declare (ignore v2))
                         (when (>= (length p2) 3)
                           (let ((poly (make-instance
                                        'mpl.rendering:polygon
                                        :xy p2
                                        :closed t
                                        :facecolor color
                                        :edgecolor color
                                        :linewidth 0.8d0
                                        :zorder zorder)))
                             (when alpha
                               (setf (mpl.rendering:artist-alpha poly)
                                     (float alpha 1.0d0)))
                             (setf (mpl.rendering:artist-transform poly)
                                   (axes-base-trans-data ax))
                             (axes-add-patch ax poly)
                             (push poly patches)))))))))
             (push (cons l0 patches) result))
    (axes-update-datalim ax (coerce tx 'list) (coerce ty 'list))
    (axes-set-xlim ax :min (reduce #'min tx) :max (reduce #'max tx))
    (axes-set-ylim ax :min (reduce #'min ty) :max (reduce #'max ty))
    (setf (mpl.rendering:artist-stale ax) t)
    (nreverse result)))
