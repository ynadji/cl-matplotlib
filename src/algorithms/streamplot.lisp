;;;; streamplot.lisp — Streamline plot for vector fields
;;;; Ported from matplotlib's streamplot module
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; StreamMask — occupancy grid to prevent overlapping streamlines
;;; ============================================================
;;; The mask is a fixed (density*30)² grid laid over the whole domain,
;;; independent of the data grid resolution. Trajectories mark single
;;; cells as they cross them; cells marked by an in-progress trajectory
;;; are recorded so a too-short trajectory can be undone.

(defstruct stream-mask
  (grid nil)
  (nx 30 :type fixnum)
  (ny 30 :type fixnum)
  (current-x -1 :type fixnum)
  (current-y -1 :type fixnum)
  (traj nil))

(defun make-stream-mask-grid (density)
  "Create a stream mask with grid size proportional to DENSITY."
  (let* ((n (max 2 (round (* density 30))))
         (grid (make-array (list n n) :element-type 'bit :initial-element 0)))
    (make-stream-mask :grid grid :nx n :ny n)))

(defun stream-mask-occupied-p (mask xm ym)
  "Check if mask cell (XM, YM) is occupied."
  (let ((nx (stream-mask-nx mask))
        (ny (stream-mask-ny mask)))
    (when (and (>= xm 0) (< xm nx) (>= ym 0) (< ym ny))
      (= 1 (aref (stream-mask-grid mask) ym xm)))))

(defun stream-mask-update-trajectory (mask xm ym)
  "Mark mask cell (XM, YM) for the in-progress trajectory.
Returns T on success (or if still in the current cell), NIL when the cell
is out of bounds or already occupied by another trajectory (collision)."
  (if (and (= xm (stream-mask-current-x mask))
           (= ym (stream-mask-current-y mask)))
      t
      (when (and (>= xm 0) (< xm (stream-mask-nx mask))
                 (>= ym 0) (< ym (stream-mask-ny mask))
                 (zerop (aref (stream-mask-grid mask) ym xm)))
        (push (cons ym xm) (stream-mask-traj mask))
        (setf (aref (stream-mask-grid mask) ym xm) 1
              (stream-mask-current-x mask) xm
              (stream-mask-current-y mask) ym)
        t)))

(defun stream-mask-start-trajectory (mask xm ym)
  "Begin a new trajectory at mask cell (XM, YM).
Returns NIL if the cell is already occupied."
  (setf (stream-mask-traj mask) nil
        (stream-mask-current-x mask) -1
        (stream-mask-current-y mask) -1)
  (stream-mask-update-trajectory mask xm ym))

(defun stream-mask-undo-trajectory (mask)
  "Unmark every cell recorded for the in-progress trajectory."
  (dolist (cell (stream-mask-traj mask))
    (setf (aref (stream-mask-grid mask) (car cell) (cdr cell)) 0))
  (setf (stream-mask-traj mask) nil))

;;; ============================================================
;;; DomainMap — coordinate mapping + bilinear interpolation
;;; ============================================================

(defstruct domain-map
  (x-arr nil)
  (y-arr nil)
  (nx 0 :type fixnum)
  (ny 0 :type fixnum)
  (x0 0.0d0 :type double-float)
  (x1 0.0d0 :type double-float)
  (y0 0.0d0 :type double-float)
  (y1 0.0d0 :type double-float))

(defun make-domain-map-from-arrays (x-arr y-arr)
  "Create a DomainMap from 1D coordinate arrays."
  (let* ((nx (length x-arr))
         (ny (length y-arr))
         (x0 (float (elt x-arr 0) 1.0d0))
         (x1 (float (elt x-arr (1- nx)) 1.0d0))
         (y0 (float (elt y-arr 0) 1.0d0))
         (y1 (float (elt y-arr (1- ny)) 1.0d0)))
    (make-domain-map :x-arr x-arr :y-arr y-arr :nx nx :ny ny
                     :x0 x0 :x1 x1 :y0 y0 :y1 y1)))

(defun domain-data2grid (dm x y)
  "Convert data coordinates (X, Y) to fractional grid indices.
Returns (values xi yi)."
  (let* ((nx (domain-map-nx dm))
         (ny (domain-map-ny dm))
         (x0 (domain-map-x0 dm))
         (x1 (domain-map-x1 dm))
         (y0 (domain-map-y0 dm))
         (y1 (domain-map-y1 dm))
         (xi (if (= x0 x1) 0.0d0
                 (* (- x x0) (/ (float (1- nx) 1.0d0) (- x1 x0)))))
         (yi (if (= y0 y1) 0.0d0
                 (* (- y y0) (/ (float (1- ny) 1.0d0) (- y1 y0))))))
    (values xi yi)))

(defun domain-grid2data (dm xi yi)
  "Convert fractional grid indices (XI, YI) to data coordinates.
Returns (values x y)."
  (let* ((nx (domain-map-nx dm))
         (ny (domain-map-ny dm))
         (x0 (domain-map-x0 dm))
         (x1 (domain-map-x1 dm))
         (y0 (domain-map-y0 dm))
         (y1 (domain-map-y1 dm))
         (x (if (<= nx 1) x0
                (+ x0 (* xi (/ (- x1 x0) (float (1- nx) 1.0d0))))))
         (y (if (<= ny 1) y0
                (+ y0 (* yi (/ (- y1 y0) (float (1- ny) 1.0d0)))))))
    (values x y)))

(defun %grid2mask (dm mask xi yi)
  "Convert fractional grid indices (XI, YI) to integer mask cell indices.
The mask grid covers the same domain at its own (density-dependent)
resolution — indexing it directly with data-grid indices, as earlier
versions did, made density control a no-op for grids larger than the mask."
  (values (round (* xi (/ (float (1- (stream-mask-nx mask)) 1.0d0)
                          (float (max 1 (1- (domain-map-nx dm))) 1.0d0))))
          (round (* yi (/ (float (1- (stream-mask-ny mask)) 1.0d0)
                          (float (max 1 (1- (domain-map-ny dm))) 1.0d0))))))

(defun %mask2grid (dm mask xm ym)
  "Convert mask cell indices (XM, YM) to fractional grid indices."
  (values (* (float xm 1.0d0)
             (/ (float (max 1 (1- (domain-map-nx dm))) 1.0d0)
                (float (1- (stream-mask-nx mask)) 1.0d0)))
          (* (float ym 1.0d0)
             (/ (float (max 1 (1- (domain-map-ny dm))) 1.0d0)
                (float (1- (stream-mask-ny mask)) 1.0d0)))))

(defun domain-interp-velocity (dm xi yi u-2d v-2d)
  "Bilinear interpolation of velocity at grid position (XI, YI).
U-2D and V-2D are indexed as (row=y, col=x).
Returns (values u v)."
  (let* ((nx (domain-map-nx dm))
         (ny (domain-map-ny dm))
         (xi (max 0.0d0 (min (float (1- nx) 1.0d0) xi)))
         (yi (max 0.0d0 (min (float (1- ny) 1.0d0) yi)))
         (x0 (min (floor xi) (- nx 2)))
         (y0 (min (floor yi) (- ny 2)))
         (x1 (1+ x0))
         (y1 (1+ y0))
         (fx (- xi (float x0 1.0d0)))
         (fy (- yi (float y0 1.0d0)))
         (u (+ (* (float (aref u-2d y0 x0) 1.0d0) (- 1.0d0 fx) (- 1.0d0 fy))
               (* (float (aref u-2d y0 x1) 1.0d0) fx (- 1.0d0 fy))
               (* (float (aref u-2d y1 x0) 1.0d0) (- 1.0d0 fx) fy)
               (* (float (aref u-2d y1 x1) 1.0d0) fx fy)))
         (v (+ (* (float (aref v-2d y0 x0) 1.0d0) (- 1.0d0 fx) (- 1.0d0 fy))
               (* (float (aref v-2d y0 x1) 1.0d0) fx (- 1.0d0 fy))
               (* (float (aref v-2d y1 x0) 1.0d0) (- 1.0d0 fx) fy)
               (* (float (aref v-2d y1 x1) 1.0d0) fx fy))))
    (values u v)))

;;; ============================================================
;;; RK12 adaptive integrator (port of matplotlib's _integrate_rk12)
;;; ============================================================

(defun %make-field-fn (dm u-2d v-2d direction)
  "Return a closure (XI YI) → (values dxi/ds dyi/ds ok-p).
The derivative is in grid coordinates per unit of arc length measured in
axes coordinates (matplotlib's convention), so MAX-LENGTH and step sizes
are resolution-independent."
  (let* ((nx (domain-map-nx dm))
         (ny (domain-map-ny dm))
         (x0 (domain-map-x0 dm))
         (x1 (domain-map-x1 dm))
         (y0 (domain-map-y0 dm))
         (y1 (domain-map-y1 dm))
         ;; data-velocity → grid-velocity scale factors
         (su (if (= x1 x0) 0.0d0 (/ (float (1- nx) 1.0d0) (- x1 x0))))
         (sv (if (= y1 y0) 0.0d0 (/ (float (1- ny) 1.0d0) (- y1 y0))))
         (dir (float direction 1.0d0)))
    (lambda (xi yi)
      (multiple-value-bind (u v) (domain-interp-velocity dm xi yi u-2d v-2d)
        (let* ((ug (* u su))
               (vg (* v sv))
               ;; speed in axes coordinates
               (u-ax (/ ug (float (max 1 (1- nx)) 1.0d0)))
               (v-ax (/ vg (float (max 1 (1- ny)) 1.0d0)))
               (ds-dt (sqrt (+ (* u-ax u-ax) (* v-ax v-ax)))))
          (if (< ds-dt 1.0d-12)
              (values 0.0d0 0.0d0 nil)
              (let ((dt-ds (/ 1.0d0 ds-dt)))
                (values (* dir ug dt-ds) (* dir vg dt-ds) t))))))))

(defun integrate-streamline (dm mask u-2d v-2d xi0 yi0 direction
                             &key (max-length 4.0d0))
  "Integrate a streamline from grid position (XI0, YI0) in DIRECTION (±1)
using an adaptive RK12 scheme: on excess error the step is shrunk and
retried; on success it grows back toward the cap. Marks mask cells as the
trajectory crosses them and stops on collision, boundary exit, zero
velocity, or MAX-LENGTH of axes-coordinate arc length.
Returns (values arc-length points), points in data coordinates in
integration order (seed first)."
  (let* ((maxerror 0.003d0)
         (maxds (min (/ 1.0d0 (stream-mask-nx mask))
                     (/ 1.0d0 (stream-mask-ny mask))
                     0.1d0))
         (ds maxds)
         (stotal 0.0d0)
         (nx (domain-map-nx dm))
         (ny (domain-map-ny dm))
         (f (%make-field-fn dm u-2d v-2d direction))
         (xi (float xi0 1.0d0))
         (yi (float yi0 1.0d0))
         (points nil))
    (loop repeat 10000 do
      ;; Record the current point while it is inside the grid
      (if (and (<= 0.0d0 xi) (<= xi (float (1- nx) 1.0d0))
               (<= 0.0d0 yi) (<= yi (float (1- ny) 1.0d0)))
          (multiple-value-bind (x y) (domain-grid2data dm xi yi)
            (push (list x y) points))
          (return))
      (multiple-value-bind (k1x k1y ok1) (funcall f xi yi)
        (unless ok1 (return))
        (multiple-value-bind (k2x k2y ok2)
            (funcall f (+ xi (* ds k1x)) (+ yi (* ds k1y)))
          (unless ok2 (return))
          (let* ((dx1 (* ds k1x))
                 (dy1 (* ds k1y))
                 (dx2 (* ds 0.5d0 (+ k1x k2x)))
                 (dy2 (* ds 0.5d0 (+ k1y k2y)))
                 ;; Error estimate in axes coordinates
                 (err (sqrt (+ (expt (/ (- dx2 dx1)
                                        (float (max 1 (1- nx)) 1.0d0)) 2)
                               (expt (/ (- dy2 dy1)
                                        (float (max 1 (1- ny)) 1.0d0)) 2)))))
            (when (< err maxerror)
              ;; Accept the (higher-order) step
              (incf xi dx2)
              (incf yi dy2)
              (multiple-value-bind (xm ym) (%grid2mask dm mask xi yi)
                (unless (stream-mask-update-trajectory mask xm ym)
                  (return)))
              (when (> (+ stotal ds) max-length)
                (return))
              (incf stotal ds))
            ;; Adapt the step: shrink on failure, grow (capped) on success
            (setf ds (if (zerop err)
                         maxds
                         (min maxds (* 0.85d0 ds (sqrt (/ maxerror err))))))))))
    (values stotal (nreverse points))))

;;; ============================================================
;;; Seed point generation (port of matplotlib's _gen_starting_points)
;;; ============================================================

(defun %gen-starting-points (mask)
  "Generate seed cells on the MASK grid, spiraling clockwise from the
boundary inward (matplotlib seeds the domain edge first so streamlines
enter from the outside)."
  (let* ((nx (stream-mask-nx mask))
         (ny (stream-mask-ny mask))
         (xfirst 0) (yfirst 1)
         (xlast (1- nx)) (ylast (1- ny))
         (x 0) (y 0)
         (direction :right)
         (seeds nil))
    (dotimes (_ (* nx ny))
      (push (list x y) seeds)
      (ecase direction
        (:right
         (incf x)
         (when (>= x xlast) (decf xlast) (setf direction :up)))
        (:up
         (incf y)
         (when (>= y ylast) (decf ylast) (setf direction :left)))
        (:left
         (decf x)
         (when (<= x xfirst) (incf xfirst) (setf direction :down)))
        (:down
         (decf y)
         (when (<= y yfirst) (incf yfirst) (setf direction :right)))))
    (nreverse seeds)))

;;; ============================================================
;;; streamplot — main entry point
;;; ============================================================

(defun streamplot (ax x-arr y-arr u-2d v-2d
                   &key (density 1.0d0) (color "C0") (linewidth 1.0d0)
                        (arrowsize 1.0d0) (arrowstyle :-\|>)
                        (minlength 0.1d0) (maxlength 4.0d0))
  "Draw streamlines of a vector field on AX.

AX — an axes-base instance.
X-ARR — 1D sequence of X coordinates.
Y-ARR — 1D sequence of Y coordinates.
U-2D — 2D array of horizontal velocity components (row=y, col=x).
V-2D — 2D array of vertical velocity components (row=y, col=x).
DENSITY — streamline density (default 1.0).
COLOR — streamline color (default \"C0\").
LINEWIDTH — line width in points (default 1.0).
ARROWSIZE — arrow size multiplier (default 1.0).
ARROWSTYLE — arrow style (default :->).
MINLENGTH — minimum streamline arc length in axes coords (default 0.1).
MAXLENGTH — maximum streamline arc length in axes coords (default 4.0).

Returns NIL."
  (let* ((x-vec (coerce (mapcar (lambda (v) (float v 1.0d0))
                                (coerce x-arr 'list))
                        'vector))
         (y-vec (coerce (mapcar (lambda (v) (float v 1.0d0))
                                (coerce y-arr 'list))
                        'vector))
         (dm (make-domain-map-from-arrays x-vec y-vec))
         (mask (make-stream-mask-grid density))
         (all-trajectories nil))
    ;; Integrate a streamline from each free mask cell, boundary first
    (dolist (seed (%gen-starting-points mask))
      (let ((xm (first seed))
            (ym (second seed)))
        (unless (stream-mask-occupied-p mask xm ym)
          (multiple-value-bind (xi0 yi0) (%mask2grid dm mask xm ym)
            (when (stream-mask-start-trajectory mask xm ym)
              ;; Integrate both directions; the backward pass shares the
              ;; trajectory's mask cells, and the whole trajectory is
              ;; undone if it comes out too short.
              (multiple-value-bind (s-b pts-b)
                  (integrate-streamline dm mask u-2d v-2d xi0 yi0 -1
                                        :max-length maxlength)
                ;; Reset the current cell to the seed for the forward pass
                (setf (stream-mask-current-x mask) xm
                      (stream-mask-current-y mask) ym)
                (multiple-value-bind (s-f pts-f)
                    (integrate-streamline dm mask u-2d v-2d xi0 yi0 1
                                          :max-length maxlength)
                  (let ((stotal (+ s-b s-f))
                        ;; backward points reversed (tail → seed), then the
                        ;; forward points minus the duplicated seed
                        (trajectory (append (reverse pts-b) (rest pts-f))))
                    (if (and (> stotal minlength)
                             (>= (length trajectory) 2))
                        (push trajectory all-trajectories)
                        (stream-mask-undo-trajectory mask))))))))))
    (setf all-trajectories (nreverse all-trajectories))
    ;; Draw streamlines as a LineCollection + direction arrows
    (when all-trajectories
      (let* ((segments (mapcar (lambda (traj)
                                 (mapcar (lambda (pt) (list (first pt) (second pt)))
                                         traj))
                               all-trajectories))
             (lc (make-instance 'mpl.rendering:line-collection
                                :segments segments
                                :edgecolors (list color)
                                :linewidths (list linewidth)
                                :zorder 2)))
        (setf (mpl.rendering:artist-transform lc) (axes-base-trans-data ax))
        (axes-add-artist ax lc)
        ;; Update data limits from all trajectory points
        (let ((all-x (mapcar #'first (apply #'append all-trajectories)))
              (all-y (mapcar #'second (apply #'append all-trajectories))))
          (axes-update-datalim ax all-x all-y))
        ;; Add direction arrows at trajectory midpoints
        (dolist (traj all-trajectories)
          (let* ((n (length traj))
                 (mid-idx (floor n 2))
                 (mid-pt (elt traj mid-idx))
                 (next-idx (min (1+ mid-idx) (1- n)))
                 (next-pt (elt traj next-idx)))
            (when (and mid-pt next-pt (not (equal mid-pt next-pt)))
              (let ((arrow (make-instance 'mpl.rendering:fancy-arrow-patch
                                          :posA (list (float (first mid-pt) 1.0d0)
                                                      (float (second mid-pt) 1.0d0))
                                          :posB (list (float (first next-pt) 1.0d0)
                                                      (float (second next-pt) 1.0d0))
                                          :arrowstyle arrowstyle
                                          :mutation-scale (* arrowsize 10.0d0)
                                          :facecolor color
                                          :edgecolor color
                                          :linewidth 0.5d0
                                          :shrinkA 0.0d0
                                          :shrinkB 0.0d0
                                          :zorder 3)))
                (setf (mpl.rendering:artist-transform arrow) (axes-base-trans-data ax))
                (axes-add-artist ax arrow)))))
        (axes-autoscale-view ax)))
    (values)))
