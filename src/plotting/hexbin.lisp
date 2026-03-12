;;;; hexbin.lisp — Hexagonal binning plot
;;;; Ported from matplotlib's axes/_axes.py Axes.hexbin
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Hexagonal binning utilities
;;; ============================================================

(defun %hexbin-compute-grid (x y gridsize)
  "Compute hex grid bin counts using matplotlib's dual-grid algorithm.
Returns (values hex-entries sx sy xmin ymin xmax ymax)."
  (let* ((x-list (coerce x 'list))
         (y-list (coerce y 'list))
         (xmin (reduce #'min x-list))
         (xmax (reduce #'max x-list))
         (ymin (reduce #'min y-list))
         (ymax (reduce #'max y-list)))
    ;; Handle edge case: all values identical
    (when (= xmin xmax)
      (setf xmin (- xmin 0.5d0)
            xmax (+ xmax 0.5d0)))
    (when (= ymin ymax)
      (setf ymin (- ymin 0.5d0)
            ymax (+ ymax 0.5d0)))
    (let* ((xmin (float xmin 1.0d0))
           (xmax (float xmax 1.0d0))
           (ymin (float ymin 1.0d0))
           (ymax (float ymax 1.0d0))
           ;; Grid dimensions (matplotlib: nx=gridsize, ny=floor(nx/sqrt(3)))
           (nx (max 1 gridsize))
           (ny (max 1 (floor nx (sqrt 3.0d0))))
           ;; Two lattice sizes
           (nx1 (1+ nx)) (ny1 (1+ ny))
           (nx2 nx)       (ny2 ny))
      ;; Padding on x only (matches matplotlib exactly)
      (let ((padding (* 1.0d-9 (- xmax xmin))))
        (decf xmin padding)
        (incf xmax padding))
      (let* ((sx (/ (- xmax xmin) nx))
             (sy (/ (- ymax ymin) ny))
             ;; Count tables for both grids
             (counts1 (make-hash-table :test #'equal))
             (counts2 (make-hash-table :test #'equal)))
        ;; Bin each point using dual-grid distance comparison
        (loop for xi in x-list
              for yi in y-list
              do (let* ((xf (float xi 1.0d0))
                        (yf (float yi 1.0d0))
                        ;; Fractional grid indices
                        (ix (/ (- xf xmin) sx))
                        (iy (/ (- yf ymin) sy))
                        ;; Grid 1: round to nearest
                        (ix1 (round ix))
                        (iy1 (round iy))
                        ;; Grid 2: floor
                        (ix2 (floor ix))
                        (iy2 (floor iy))
                        ;; Distance to nearest grid center
                        (d1 (+ (* (- ix ix1) (- ix ix1))
                               (* 3.0d0 (* (- iy iy1) (- iy iy1)))))
                        (d2 (+ (* (- ix ix2 0.5d0) (- ix ix2 0.5d0))
                               (* 3.0d0 (* (- iy iy2 0.5d0) (- iy iy2 0.5d0))))))
                   (if (< d1 d2)
                       ;; Assign to grid 1 (with bounds check)
                       (when (and (<= 0 ix1) (< ix1 nx1)
                                  (<= 0 iy1) (< iy1 ny1))
                         (incf (gethash (cons ix1 iy1) counts1 0)))
                       ;; Assign to grid 2 (with bounds check)
                       (when (and (<= 0 ix2) (< ix2 nx2)
                                  (<= 0 iy2) (< iy2 ny2))
                         (incf (gethash (cons ix2 iy2) counts2 0))))))
        ;; Collect results as (cx cy count) entries
        (let ((hex-entries nil))
          ;; Grid 1 centers: (ix * sx + xmin, iy * sy + ymin)
          (maphash (lambda (key count)
                     (let ((cx (+ (* (car key) sx) xmin))
                           (cy (+ (* (cdr key) sy) ymin)))
                       (push (list cx cy count) hex-entries)))
                   counts1)
          ;; Grid 2 centers: ((ix + 0.5) * sx + xmin, (iy + 0.5) * sy + ymin)
          (maphash (lambda (key count)
                     (let ((cx (+ (* (+ (car key) 0.5d0) sx) xmin))
                           (cy (+ (* (+ (cdr key) 0.5d0) sy) ymin)))
                       (push (list cx cy count) hex-entries)))
                   counts2)
          (values hex-entries sx sy xmin ymin xmax ymax))))))

(defun %hexbin-hex-vertices (cx cy sx sy)
  "Return 6 (x y) vertices for a flat-top hexagon centered at (CX, CY).
Matches matplotlib: [sx, sy/3] * [[.5,-.5],[.5,.5],[0,1],[-.5,.5],[-.5,-.5],[0,-1]]."
  (let ((sy3 (/ sy 3.0d0)))
    (list (list (+ cx (* sx 0.5d0))  (- cy (* sy3 0.5d0)))
          (list (+ cx (* sx 0.5d0))  (+ cy (* sy3 0.5d0)))
          (list cx                    (+ cy sy3))
          (list (- cx (* sx 0.5d0))  (+ cy (* sy3 0.5d0)))
          (list (- cx (* sx 0.5d0))  (- cy (* sy3 0.5d0)))
          (list cx                    (- cy sy3)))))

;;; ============================================================
;;; hexbin — hexagonal binning plot
;;; ============================================================

(defun hexbin-plot (ax x y &key (gridsize 100) (cmap :inferno) (mincnt 1)
                                (vmin nil) (vmax nil) (alpha nil) (zorder 1)
                                (edgecolors "none") (linewidths 0.5))
  "Create a hexagonal binning plot.

AX — an axes-base instance.
X, Y — sequences of data values (same length).
GRIDSIZE — number of hex columns (default 100).
CMAP — colormap name (keyword or string) or nil for inferno.
MINCNT — minimum count to display a hex (default 1).
VMIN, VMAX — data range for colormap normalization.
ALPHA — transparency.
ZORDER — drawing order (default 1).
EDGECOLORS — edge color for hexagons (default \"none\").
LINEWIDTHS — edge line width (default 0.5).

Returns a scalar-mappable (for use with colorbar)."
  (multiple-value-bind (hex-entries sx sy data-xmin data-ymin data-xmax data-ymax)
      (%hexbin-compute-grid x y gridsize)
    (let* (;; Resolve colormap
           (effective-cmap (if cmap
                               (if (or (keywordp cmap) (stringp cmap))
                                   (mpl.primitives:get-colormap cmap)
                                   cmap)
                               (mpl.primitives:get-colormap :inferno)))
           ;; Filter by mincnt threshold
           (hex-data (remove-if (lambda (entry) (< (third entry) mincnt))
                                hex-entries)))
      (when (null hex-data)
        ;; No data to plot — return empty scalar-mappable
        (let* ((norm (mpl.primitives:make-normalize :vmin 0.0d0 :vmax 1.0d0))
               (sm (mpl.primitives:make-scalar-mappable :norm norm :cmap effective-cmap)))
          (return-from hexbin-plot sm)))
      ;; Compute count range for colormap normalization
      (let* ((count-min (reduce #'min hex-data :key #'third))
             (count-max (reduce #'max hex-data :key #'third))
             (eff-vmin (float (or vmin count-min) 1.0d0))
             (eff-vmax (float (or vmax count-max) 1.0d0))
             (range (- eff-vmax eff-vmin))
             ;; Build polygon vertices and colors
             (all-verts nil)
             (all-facecolors nil))
        ;; Process each hexagon
        (dolist (entry hex-data)
          (let* ((cx (first entry))
                 (cy (second entry))
                 (count (third entry))
                 ;; Create hexagon vertices
                 (verts (%hexbin-hex-vertices cx cy sx sy)))
            (push verts all-verts)
            ;; Map count to color
            (let* ((norm-v (if (zerop range) 0.5d0
                               (max 0.0d0 (min 1.0d0
                                                (/ (- (float count 1.0d0) eff-vmin) range)))))
                   (rgba (mpl.primitives:colormap-call effective-cmap norm-v))
                   (hex-color (format nil "#~2,'0x~2,'0x~2,'0x"
                                      (round (* (aref rgba 0) 255))
                                      (round (* (aref rgba 1) 255))
                                      (round (* (aref rgba 2) 255)))))
              (push hex-color all-facecolors))))
        ;; Reverse to maintain order
        (setf all-verts (nreverse all-verts))
        (setf all-facecolors (nreverse all-facecolors))
        ;; Create PolyCollection
        (let ((pc (make-instance 'mpl.rendering:poly-collection
                                 :verts all-verts
                                 :facecolors all-facecolors
                                 :edgecolors (list edgecolors)
                                 :linewidths (list linewidths)
                                 :zorder zorder)))
          (when alpha
            (setf (mpl.rendering:artist-alpha pc) (float alpha 1.0d0)))
          ;; Set transform
          (setf (mpl.rendering:artist-transform pc)
                (axes-base-trans-data ax))
          ;; Add to axes
          (axes-add-artist ax pc)
          ;; Update data limits — use padded data bounds (matches matplotlib)
          (axes-update-datalim ax (list data-xmin data-xmax) (list data-ymin data-ymax))
          (axes-autoscale-view ax)
          ;; Create scalar-mappable for colorbar integration
          (let* ((norm (mpl.primitives:make-normalize :vmin eff-vmin :vmax eff-vmax))
                 (sm (mpl.primitives:make-scalar-mappable :norm norm :cmap effective-cmap)))
            sm))))))
