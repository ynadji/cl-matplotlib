;;;; hexbin.lisp — Hexagonal binning plot
;;;; Ported from matplotlib's axes/_axes.py Axes.hexbin
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Hexagonal binning utilities
;;; ============================================================

(defun %hexbin-compute-grid (x y gridsize)
  "Compute hex grid bin counts for points X, Y with GRIDSIZE columns.
Returns (values counts dx dy xmin ymin) where counts is a hash-table
mapping (col . row) keys to integer counts."
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
           ;; Match matplotlib dual-grid: 2*gridsize columns, floor(gridsize/sqrt(3)) rows
           (nx (* 2 (max 1 gridsize)))
           (ny (max 1 (floor (max 1 gridsize) (sqrt 3.0d0))))
           (dx (/ (- xmax xmin) nx))
           (dy (/ (- ymax ymin) ny))
           (counts (make-hash-table :test #'equal)))
      (loop for xi in x-list
            for yi in y-list
            do (let* ((xf (float xi 1.0d0))
                      (yf (float yi 1.0d0))
                      (col (round (/ (- xf xmin) dx)))
                      (row-offset (if (evenp col) 0.0d0 (* 0.5d0 dy)))
                      (row (round (/ (- yf ymin row-offset) dy)))
                      (key (cons col row)))
                 (incf (gethash key counts 0))))
      (values counts dx dy xmin ymin))))

(defun %hexbin-hex-vertices (cx cy dx dy)
  "Return a list of 6 (x y) vertices for a hexagon centered at (CX, CY)
matching grid spacing DX (column) and DY (row). Pointy-top orientation."
  (let ((dy6 (/ dy 6.0d0))
        (dy3 (/ dy 3.0d0)))
    (list (list (+ cx dx) (- cy dy6))
          (list (+ cx dx) (+ cy dy6))
          (list cx (+ cy dy3))
          (list (- cx dx) (+ cy dy6))
          (list (- cx dx) (- cy dy6))
          (list cx (- cy dy3)))))

(defun %hexbin-center (col row dx dy xmin ymin)
  "Compute the center (cx, cy) of hexagon at grid position (COL, ROW)."
  (let* ((cx (+ xmin (* col dx)))
         (row-offset (if (evenp col) 0.0d0 (* 0.5d0 dy)))
         (cy (+ ymin (* row dy) row-offset)))
    (values cx cy)))

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
  (multiple-value-bind (counts dx dy xmin ymin)
      (%hexbin-compute-grid x y gridsize)
    (let* (;; Resolve colormap
           (effective-cmap (if cmap
                               (if (or (keywordp cmap) (stringp cmap))
                                   (mpl.primitives:get-colormap cmap)
                                   cmap)
                               (mpl.primitives:get-colormap :inferno)))
           ;; Collect non-empty hexagons
           (hex-data nil))
      ;; Gather hexagons that meet mincnt threshold
      (maphash (lambda (key count)
                 (when (>= count mincnt)
                   (push (list key count) hex-data)))
               counts)
      (when (null hex-data)
        ;; No data to plot — return empty scalar-mappable
        (let* ((norm (mpl.primitives:make-normalize :vmin 0.0d0 :vmax 1.0d0))
               (sm (mpl.primitives:make-scalar-mappable :norm norm :cmap effective-cmap)))
          (return-from hexbin-plot sm)))
      ;; Compute count range for colormap normalization
      (let* ((count-min (reduce #'min hex-data :key #'second))
             (count-max (reduce #'max hex-data :key #'second))
             (eff-vmin (float (or vmin count-min) 1.0d0))
             (eff-vmax (float (or vmax count-max) 1.0d0))
             (range (- eff-vmax eff-vmin))
             ;; Build polygon vertices and colors
             (all-verts nil)
             (all-facecolors nil)
             ;; Track data limits
             (plot-xmin most-positive-double-float)
             (plot-xmax most-negative-double-float)
             (plot-ymin most-positive-double-float)
             (plot-ymax most-negative-double-float))
        ;; Process each hexagon
        (dolist (entry hex-data)
          (let* ((key (first entry))
                 (count (second entry))
                 (col (car key))
                 (row (cdr key)))
            (multiple-value-bind (cx cy)
                (%hexbin-center col row dx dy xmin ymin)
              ;; Create hexagon vertices
              (let ((verts (%hexbin-hex-vertices cx cy dx dy)))
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
                  (push hex-color all-facecolors))
                ;; Update data limits from vertices
                (dolist (v verts)
                  (let ((vx (first v))
                        (vy (second v)))
                    (when (< vx plot-xmin) (setf plot-xmin vx))
                    (when (> vx plot-xmax) (setf plot-xmax vx))
                    (when (< vy plot-ymin) (setf plot-ymin vy))
                    (when (> vy plot-ymax) (setf plot-ymax vy))))))))
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
          ;; Update data limits
          (axes-update-datalim ax (list plot-xmin plot-xmax) (list plot-ymin plot-ymax))
          (axes-autoscale-view ax :tight t)
          ;; Create scalar-mappable for colorbar integration
          (let* ((norm (mpl.primitives:make-normalize :vmin eff-vmin :vmax eff-vmax))
                 (sm (mpl.primitives:make-scalar-mappable :norm norm :cmap effective-cmap)))
            sm))))))
