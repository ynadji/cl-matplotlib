;;;; streamplot.lisp — Streamline plot for vector fields
;;;; Ported from matplotlib's streamplot module
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; StreamMask — occupancy grid to prevent overlapping streamlines
;;; ============================================================

(defstruct stream-mask
  (grid nil)
  (nx 30 :type fixnum)
  (ny 30 :type fixnum))

(defun make-stream-mask-grid (density)
  "Create a stream mask with grid size proportional to DENSITY."
  (let* ((n (max 1 (round (* density 30))))
         (grid (make-array (list n n) :element-type 'bit :initial-element 0)))
    (make-stream-mask :grid grid :nx n :ny n)))

(defun stream-mask-occupied-p (mask xi yi)
  "Check if grid cell (XI, YI) is occupied."
  (let ((nx (stream-mask-nx mask))
        (ny (stream-mask-ny mask)))
    (when (and (>= xi 0) (< xi nx) (>= yi 0) (< yi ny))
      (= 1 (aref (stream-mask-grid mask) yi xi)))))

(defun stream-mask-occupy (mask xi yi)
  "Mark grid cell (XI, YI) and its neighbors as occupied."
  (let ((nx (stream-mask-nx mask))
        (ny (stream-mask-ny mask))
        (grid (stream-mask-grid mask)))
    (loop for dy from -1 to 1 do
      (loop for dx from -1 to 1 do
        (let ((x (+ xi dx)) (y (+ yi dy)))
          (when (and (>= x 0) (< x nx) (>= y 0) (< y ny))
            (setf (aref grid y x) 1)))))))

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
;;; RK12 adaptive integrator
;;; ============================================================

(defun %rk12-step (dm u-2d v-2d xi yi dt)
  "Single RK12 step. Returns (values new-xi new-yi error)."
  (multiple-value-bind (u1 v1) (domain-interp-velocity dm xi yi u-2d v-2d)
    (let* ((k1x (* dt u1))
           (k1y (* dt v1))
           (xi-mid (+ xi (* 0.5d0 k1x)))
           (yi-mid (+ yi (* 0.5d0 k1y))))
      (multiple-value-bind (u2 v2) (domain-interp-velocity dm xi-mid yi-mid u-2d v-2d)
        (let* ((k2x (* dt u2))
               (k2y (* dt v2))
               (new-xi (+ xi k2x))
               (new-yi (+ yi k2y))
               (err (sqrt (+ (expt (- k2x k1x) 2) (expt (- k2y k1y) 2)))))
          (values new-xi new-yi err))))))

(defun integrate-streamline (dm mask u-2d v-2d xi0 yi0 direction
                             &key (max-length 4.0d0) (tolerance 0.1d0))
  "Integrate streamline from (XI0, YI0) in DIRECTION (+1 or -1).
Returns list of (x y) data-space points."
  (let* ((nx (domain-map-nx dm))
         (ny (domain-map-ny dm))
         (points nil)
         (xi (float xi0 1.0d0))
         (yi (float yi0 1.0d0))
         (total-length 0.0d0))
    (declare (ignorable nx ny))
    (multiple-value-bind (x y) (domain-grid2data dm xi yi)
      (push (list x y) points))
    (dotimes (_ 1000)
      (when (>= total-length max-length) (return))
      (when (or (< xi 0.0d0) (>= xi (float nx 1.0d0))
                (< yi 0.0d0) (>= yi (float ny 1.0d0)))
        (return))
      (let ((ixi (round xi)) (iyi (round yi)))
        (when (stream-mask-occupied-p mask ixi iyi) (return))
        (multiple-value-bind (u v) (domain-interp-velocity dm xi yi u-2d v-2d)
          (let ((speed (sqrt (+ (* u u) (* v v)))))
            (when (< speed 1.0d-8) (return))
            ;; Normalize step by speed
            (let* ((step-size (/ 0.1d0 speed))
                   (dt-new (* (float direction 1.0d0) step-size)))
              (multiple-value-bind (new-xi new-yi err)
                  (%rk12-step dm u-2d v-2d xi yi dt-new)
                (cond
                  ((> err tolerance)
                   ;; Error too large — skip this step (effectively halve it next time)
                   nil)
                  (t
                   (stream-mask-occupy mask ixi iyi)
                   (setf xi new-xi yi new-yi)
                   (incf total-length step-size)
                   (multiple-value-bind (x y) (domain-grid2data dm xi yi)
                     (push (list x y) points))))))))))
    (if (= direction 1)
        (nreverse points)
        points)))

;;; ============================================================
;;; Seed point generation
;;; ============================================================

(defun %gen-starting-points (nx ny density)
  "Generate seed points on a regular grid, sorted by distance from center."
  (let* ((n-seeds (max 2 (round (* density 30))))
         (seeds nil))
    (dotimes (i n-seeds)
      (dotimes (j n-seeds)
        (let ((xi (* (float i 1.0d0)
                     (/ (float (1- nx) 1.0d0) (float (max 1 (1- n-seeds)) 1.0d0))))
              (yi (* (float j 1.0d0)
                     (/ (float (1- ny) 1.0d0) (float (max 1 (1- n-seeds)) 1.0d0)))))
          (push (list xi yi) seeds))))
    (let ((cx (* 0.5d0 (float (1- nx) 1.0d0)))
          (cy (* 0.5d0 (float (1- ny) 1.0d0))))
      (sort seeds (lambda (a b)
                    (< (+ (expt (- (first a) cx) 2) (expt (- (second a) cy) 2))
                       (+ (expt (- (first b) cx) 2) (expt (- (second b) cy) 2))))))))

;;; ============================================================
;;; streamplot — main entry point
;;; ============================================================

(defun streamplot (ax x-arr y-arr u-2d v-2d
                   &key (density 1.0d0) (color "C0") (linewidth 1.0d0)
                        (arrowsize 1.0d0) (arrowstyle :->))
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

Returns NIL."
  (let* ((x-vec (coerce (mapcar (lambda (v) (float v 1.0d0))
                                (coerce x-arr 'list))
                        'vector))
         (y-vec (coerce (mapcar (lambda (v) (float v 1.0d0))
                                (coerce y-arr 'list))
                        'vector))
         (dm (make-domain-map-from-arrays x-vec y-vec))
         (mask (make-stream-mask-grid density))
         (seeds (%gen-starting-points (domain-map-nx dm) (domain-map-ny dm) density))
         (all-trajectories nil))
    ;; Integrate streamlines from each seed point
    (dolist (seed seeds)
      (let* ((xi0 (first seed))
             (yi0 (second seed))
             (ixi (round xi0))
             (iyi (round yi0)))
        (unless (stream-mask-occupied-p mask ixi iyi)
          (let* ((fwd (integrate-streamline dm mask u-2d v-2d xi0 yi0 1))
                 (bwd (integrate-streamline dm mask u-2d v-2d xi0 yi0 -1))
                 (trajectory (append (reverse bwd)
                                     (when (> (length fwd) 1) (rest fwd)))))
            (when (>= (length trajectory) 2)
              (push trajectory all-trajectories))))))
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
