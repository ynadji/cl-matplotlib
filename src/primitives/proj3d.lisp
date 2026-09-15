;;;; proj3d.lisp — 3D projection math for axes-3d.
;;;;
;;;; A port of mpl_toolkits/mplot3d/proj3d.py (matplotlib 3.8.4). Nothing
;;;; here is a `transform' node: the 2D transform protocol is fixed at two
;;;; dimensions, and mplot3d does not push 3D data through transData
;;;; either. A 4x4 projection matrix M maps world (x y z) to a normalized
;;;; view box; the axes' ordinary 2D transData then maps that box to
;;;; pixels (see axes3d.lisp, "top view").
;;;;
;;;; Conventions: mat4 is a row-major (simple-array double-float (16));
;;;; (mat4-mul a b) is numpy's np.dot(a, b), i.e. b is applied first.
;;;; Vectors are (simple-array double-float (3)).

(in-package #:cl-matplotlib.primitives)

;;; ============================================================
;;; Vectors
;;; ============================================================

(deftype vec3 () '(simple-array double-float (3)))

(declaim (inline vec3))
(defun vec3 (x y z)
  "A fresh 3-vector of doubles."
  (let ((v (make-array 3 :element-type 'double-float)))
    (setf (aref v 0) (float x 1.0d0)
          (aref v 1) (float y 1.0d0)
          (aref v 2) (float z 1.0d0))
    v))

(defun vec3-add (a b)
  (vec3 (+ (aref a 0) (aref b 0)) (+ (aref a 1) (aref b 1)) (+ (aref a 2) (aref b 2))))

(defun vec3-sub (a b)
  (vec3 (- (aref a 0) (aref b 0)) (- (aref a 1) (aref b 1)) (- (aref a 2) (aref b 2))))

(defun vec3-scale (a s)
  (let ((s (float s 1.0d0)))
    (vec3 (* s (aref a 0)) (* s (aref a 1)) (* s (aref a 2)))))

(defun vec3-dot (a b)
  (+ (* (aref a 0) (aref b 0)) (* (aref a 1) (aref b 1)) (* (aref a 2) (aref b 2))))

(defun vec3-cross (a b)
  (vec3 (- (* (aref a 1) (aref b 2)) (* (aref a 2) (aref b 1)))
        (- (* (aref a 2) (aref b 0)) (* (aref a 0) (aref b 2)))
        (- (* (aref a 0) (aref b 1)) (* (aref a 1) (aref b 0)))))

(defun vec3-norm (a)
  (sqrt (vec3-dot a a)))

(defun vec3-normalize (a)
  "A / |A|; A unchanged (zero vector) when |A| = 0."
  (let ((n (vec3-norm a)))
    (if (zerop n) (vec3 (aref a 0) (aref a 1) (aref a 2)) (vec3-scale a (/ n)))))

;;; ============================================================
;;; 4x4 matrices
;;; ============================================================

(deftype mat4 () '(simple-array double-float (16)))

(defun make-mat4 (&rest elements)
  "A row-major 4x4 matrix from 16 numbers (row by row)."
  (assert (= (length elements) 16) () "make-mat4 needs 16 elements, got ~D" (length elements))
  (let ((m (make-array 16 :element-type 'double-float)))
    (loop for e in elements for i from 0 do (setf (aref m i) (float e 1.0d0)))
    m))

(defun mat4-identity ()
  (make-mat4 1 0 0 0  0 1 0 0  0 0 1 0  0 0 0 1))

(declaim (inline mat4-ref))
(defun mat4-ref (m i j)
  (aref m (+ (* 4 i) j)))

(defun (setf mat4-ref) (value m i j)
  (setf (aref m (+ (* 4 i) j)) (float value 1.0d0)))

(defun mat4-mul (a b)
  "A·B (numpy dot): the transform that applies B, then A."
  (let ((m (make-array 16 :element-type 'double-float :initial-element 0.0d0)))
    (dotimes (i 4)
      (dotimes (j 4)
        (setf (aref m (+ (* 4 i) j))
              (loop for k below 4 sum (* (mat4-ref a i k) (mat4-ref b k j))))))
    m))

(defun mat4-invert (m)
  "The inverse of M by Gauss-Jordan elimination with partial pivoting.
Signals an error for a singular matrix."
  (let ((a (make-array '(4 8) :element-type 'double-float :initial-element 0.0d0)))
    (dotimes (i 4)
      (dotimes (j 4) (setf (aref a i j) (mat4-ref m i j)))
      (setf (aref a i (+ 4 i)) 1.0d0))
    (dotimes (col 4)
      ;; pivot
      (let ((piv col))
        (loop for r from (1+ col) below 4
              when (> (abs (aref a r col)) (abs (aref a piv col))) do (setf piv r))
        (when (< (abs (aref a piv col)) 1.0d-300)
          (error "mat4-invert: singular matrix"))
        (unless (= piv col)
          (dotimes (j 8) (rotatef (aref a col j) (aref a piv j)))))
      (let ((p (aref a col col)))
        (dotimes (j 8) (setf (aref a col j) (/ (aref a col j) p))))
      (dotimes (r 4)
        (unless (= r col)
          (let ((f (aref a r col)))
            (unless (zerop f)
              (dotimes (j 8)
                (decf (aref a r j) (* f (aref a col j)))))))))
    (let ((inv (make-array 16 :element-type 'double-float)))
      (dotimes (i 4)
        (dotimes (j 4) (setf (aref inv (+ (* 4 i) j)) (aref a i (+ 4 j)))))
      inv)))

;;; ============================================================
;;; The proj3d pipeline
;;; ============================================================

(defun world-transformation (xmin xmax ymin ymax zmin zmax &key pb-aspect)
  "Scale homogeneous coordinates in the given ranges to [0, 1], or to
[0, pb-aspect_i] when the plot-box aspect (a 3-vector) is given.
Port of proj3d.world_transformation."
  (let ((dx (float (- xmax xmin) 1.0d0))
        (dy (float (- ymax ymin) 1.0d0))
        (dz (float (- zmax zmin) 1.0d0)))
    (when pb-aspect
      (setf dx (/ dx (aref pb-aspect 0))
            dy (/ dy (aref pb-aspect 1))
            dz (/ dz (aref pb-aspect 2))))
    (make-mat4 (/ dx) 0 0 (- (/ xmin dx))
               0 (/ dy) 0 (- (/ ymin dy))
               0 0 (/ dz) (- (/ zmin dz))
               0 0 0 1)))

(defun rotation-about-vector (v angle)
  "3x3 rotation (as a list of three vec3 rows) by ANGLE radians about V.
Port of proj3d._rotation_about_vector."
  (let* ((u (vec3-normalize v))
         (vx (aref u 0)) (vy (aref u 1)) (vz (aref u 2))
         (s (sin angle))
         (c (cos angle))
         (tt (* 2 (expt (sin (/ angle 2)) 2))))   ; 1 - c, but stable
    (list (vec3 (+ (* tt vx vx) c)        (- (* tt vx vy) (* vz s)) (+ (* tt vx vz) (* vy s)))
          (vec3 (+ (* tt vy vx) (* vz s)) (+ (* tt vy vy) c)        (- (* tt vy vz) (* vx s)))
          (vec3 (- (* tt vz vx) (* vy s)) (+ (* tt vz vy) (* vx s)) (+ (* tt vz vz) c)))))

(defun %mat3-apply (rows v)
  (vec3 (vec3-dot (first rows) v) (vec3-dot (second rows) v) (vec3-dot (third rows) v)))

(defun view-axes (eye r v roll)
  "The unit viewing axes in data coordinates: (values u v w) pointing to
the right of the screen, the top of the screen, and out of the screen,
for camera EYE looking at R with vertical direction V and ROLL radians.
Port of proj3d._view_axes."
  (let* ((w (vec3-normalize (vec3-sub eye r)))
         (u (vec3-normalize (vec3-cross v w)))
         (vv (vec3-cross w u)))
    (if (zerop roll)
        (values u vv w)
        (let ((rot (rotation-about-vector w (- roll))))
          (values (%mat3-apply rot u) (%mat3-apply rot vv) w)))))

(defun view-transformation-uvw (u v w eye)
  "The view matrix for the viewing axes U V W and camera EYE.
Port of proj3d._view_transformation_uvw: Mr (rows u v w) · Mt (translate by -eye)."
  (let ((mr (mat4-identity))
        (mt (mat4-identity)))
    (dotimes (j 3)
      (setf (mat4-ref mr 0 j) (aref u j)
            (mat4-ref mr 1 j) (aref v j)
            (mat4-ref mr 2 j) (aref w j)
            (mat4-ref mt j 3) (- (aref eye j))))
    (mat4-mul mr mt)))

(defun persp-transformation (zfront zback focal-length)
  "Perspective projection matrix. Port of proj3d._persp_transformation."
  (let* ((e (float focal-length 1.0d0))
         (b (/ (+ zfront zback) (- zfront zback)))
         (c (/ (* -2 zfront zback) (- zfront zback))))
    (make-mat4 e 0 0 0
               0 e 0 0
               0 0 b c
               0 0 -1 0)))

(defun ortho-transformation (zfront zback)
  "Orthographic projection matrix. Port of proj3d._ortho_transformation."
  (let ((a (- (+ zfront zback)))
        (b (- (- zfront zback))))
    (make-mat4 2 0 0 0
               0 2 0 0
               0 0 -2 0
               0 0 a b)))

(declaim (inline proj-transform-vec))
(defun proj-transform-vec (m x y z)
  "Project one point through M: (values tx ty tz), after the homogeneous
divide. Larger TZ is farther from the eye."
  (let* ((x (float x 1.0d0)) (y (float y 1.0d0)) (z (float z 1.0d0))
         (w (+ (* (aref m 12) x) (* (aref m 13) y) (* (aref m 14) z) (aref m 15))))
    (values (/ (+ (* (aref m 0) x) (* (aref m 1) y) (* (aref m 2) z) (aref m 3)) w)
            (/ (+ (* (aref m 4) x) (* (aref m 5) y) (* (aref m 6) z) (aref m 7)) w)
            (/ (+ (* (aref m 8) x) (* (aref m 9) y) (* (aref m 10) z) (aref m 11)) w))))

(defun proj-transform (m xs ys zs)
  "Project the points XS YS ZS (sequences) through M.
Returns (values txs tys tzs) as (simple-array double-float (*))."
  (let* ((n (min (length xs) (length ys) (length zs)))
         (txs (make-array n :element-type 'double-float))
         (tys (make-array n :element-type 'double-float))
         (tzs (make-array n :element-type 'double-float))
         (xv (coerce xs 'simple-vector))
         (yv (coerce ys 'simple-vector))
         (zv (coerce zs 'simple-vector)))
    (dotimes (i n)
      (multiple-value-bind (tx ty tz) (proj-transform-vec m (svref xv i) (svref yv i) (svref zv i))
        (setf (aref txs i) tx (aref tys i) ty (aref tzs i) tz)))
    (values txs tys tzs)))

(defun inv-transform (invm x y z)
  "Map a projected point back to world coordinates through INVM, the
inverse projection matrix. Port of proj3d.inv_transform."
  (multiple-value-bind (tx ty tz) (proj-transform-vec invm x y z)
    (values tx ty tz)))

;;; ============================================================
;;; Axes3D.get_proj — the whole pipeline for a view
;;; ============================================================

(defun norm-angle (a)
  "ANGLE (degrees) normalized to -180 < a <= 180. Port of art3d._norm_angle."
  (let ((a (mod (+ a 360) 360)))
    (if (> a 180) (- a 360) a)))

(defun default-box-aspect (&key (aspect (vec3 4 4 3)) (zoom 1.0d0))
  "The plot-box aspect used by Axes3D.set_box_aspect: ASPECT scaled so that
|aspect| = 1.8294640721620434 * ZOOM (matplotlib 3.8)."
  (vec3-scale aspect (/ (* 1.8294640721620434d0 zoom) (vec3-norm aspect))))

(defun projection-matrix (elev azim roll xmin xmax ymin ymax zmin zmax
                          &key (box-aspect (default-box-aspect)) (dist 10.0d0)
                            (focal-length 1.0d0))
  "The 4x4 world→view projection matrix of Axes3D.get_proj for the view
angles ELEV AZIM ROLL (degrees) and the 3D limits. FOCAL-LENGTH NIL means
an orthographic projection ('ortho'); the default 1 is 'persp'.
Returns (values m eye u v w) — the extra values are the camera position
and the screen right/up/out unit vectors, which the axes uses for
gestures."
  (let* ((box-aspect (if (typep box-aspect 'vec3) box-aspect
                         (vec3 (elt box-aspect 0) (elt box-aspect 1) (elt box-aspect 2))))
         (world-m (world-transformation xmin xmax ymin ymax zmin zmax :pb-aspect box-aspect))
         (r (vec3-scale box-aspect 0.5d0))
         (elev-rad (* (/ pi 180) (float elev 1.0d0)))
         (azim-rad (* (/ pi 180) (float azim 1.0d0)))
         (ps (vec3 (* (cos elev-rad) (cos azim-rad))
                   (* (cos elev-rad) (sin azim-rad))
                   (sin elev-rad)))
         (dist (float dist 1.0d0))
         (eye (vec3-add r (vec3-scale ps dist)))
         ;; _calc_view_axes: vertical axis flips when the camera is upside down
         (elev-norm-rad (* (/ pi 180) (norm-angle elev)))
         (roll-norm-rad (* (/ pi 180) (norm-angle roll)))
         (v (vec3 0 0 (if (> (abs elev-norm-rad) (/ pi 2)) -1 1))))
    (multiple-value-bind (u vv w) (view-axes eye r v roll-norm-rad)
      (let* ((view-m (if focal-length
                         (view-transformation-uvw
                          u vv w (vec3-add r (vec3-scale ps (* dist focal-length))))
                         (view-transformation-uvw u vv w eye)))
             (proj-m (if focal-length
                         (persp-transformation (- dist) dist focal-length)
                         (ortho-transformation (- dist) dist)))
             (m (mat4-mul proj-m (mat4-mul view-m world-m))))
        (values m eye u vv w)))))
