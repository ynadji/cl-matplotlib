;;;; polar-transforms.lisp — Polar coordinate transforms
;;;; Converts between polar (theta, r) and Cartesian (x, y) coordinates.
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.primitives)

;;; ============================================================
;;; PolarTransform — polar (theta, r) → Cartesian (x, y)
;;; ============================================================

(defclass polar-transform (transform)
  ()
  (:documentation "Transform from polar (theta, r) to Cartesian (x, y).
Input: (theta, r) where theta is in RADIANS.
Output: (r*cos(theta), r*sin(theta))."))

(defmethod transform-point ((tr polar-transform) point)
  "Transform a polar point (theta, r) to Cartesian (x, y)."
  (let* ((theta (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (r     (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (result (make-array 2 :element-type 'double-float)))
    (setf (aref result 0) (* r (cos theta))
          (aref result 1) (* r (sin theta)))
    result))

(defmethod transform-path ((tr polar-transform) path)
  "Transform a polar path to Cartesian, replacing constant-r LINETO with Bézier arcs."
  (let* ((verts (mpl-path-vertices path))
         (codes (mpl-path-codes path))
         (n (array-dimension verts 0))
         (result-verts nil)
         (result-codes nil))
    (dotimes (i n)
      (let* ((theta (aref verts i 0))
             (r     (aref verts i 1))
             (code  (aref codes i)))
        (cond
          ;; MOVETO: just transform
          ((= code +moveto+)
           (push (list (* r (cos theta)) (* r (sin theta))) result-verts)
           (push +moveto+ result-codes))
          ;; LINETO: check if constant-r arc
          ((= code +lineto+)
           (let* ((prev-theta (aref verts (1- i) 0))
                  (prev-r     (aref verts (1- i) 1))
                  (r-eps (* 1.0d-6 (max (abs prev-r) (abs r) 1.0d0))))
             (if (< (abs (- r prev-r)) r-eps)
                 ;; Constant-r: generate arc
                 (let* ((t1-deg (* prev-theta (/ 180.0d0 pi)))
                        (t2-deg (* theta (/ 180.0d0 pi)))
                        (arc (path-arc t1-deg t2-deg))
                        (arc-verts (mpl-path-vertices arc))
                        (arc-codes (mpl-path-codes arc))
                        (arc-n (array-dimension arc-verts 0)))
                   ;; Scale arc by r and skip first vertex (already added as previous MOVETO)
                   (loop for j from 1 below arc-n do
                     (push (list (* r (aref arc-verts j 0))
                                 (* r (aref arc-verts j 1)))
                           result-verts)
                     (push (aref arc-codes j) result-codes)))
                 ;; Non-constant-r: just transform
                 (progn
                   (push (list (* r (cos theta)) (* r (sin theta))) result-verts)
                   (push +lineto+ result-codes)))))
          ;; CLOSEPOLY: pass through
          ((= code +closepoly+)
           (push (list 0.0d0 0.0d0) result-verts)
           (push +closepoly+ result-codes))
          ;; Other codes (CURVE3, CURVE4, etc.): transform vertex
          (t
           (push (list (* r (cos theta)) (* r (sin theta))) result-verts)
           (push code result-codes)))))
    ;; Build result path
    (let* ((m (length result-verts))
           (new-verts (make-array (list m 2) :element-type 'double-float))
           (new-codes (make-array m :element-type '(unsigned-byte 8))))
      (loop for v in (nreverse result-verts)
            for c in (nreverse result-codes)
            for j from 0 do
        (setf (aref new-verts j 0) (float (first v) 1.0d0)
              (aref new-verts j 1) (float (second v) 1.0d0)
              (aref new-codes j) c))
      (make-path :vertices new-verts :codes new-codes))))

(defmethod invert ((tr polar-transform))
  "Return the inverse transform (Cartesian → polar)."
  (make-instance 'inverted-polar-transform))

;;; ============================================================
;;; InvertedPolarTransform — Cartesian (x, y) → polar (theta, r)
;;; ============================================================

(defclass inverted-polar-transform (transform)
  ()
  (:documentation "Inverse of polar-transform: Cartesian (x, y) → polar (theta, r).
Output theta is in [0, 2π)."))

(defmethod transform-point ((tr inverted-polar-transform) point)
  "Transform a Cartesian point (x, y) to polar (theta, r)."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (r (sqrt (+ (* x x) (* y y))))
         (theta (atan y x))
         ;; Normalize theta to [0, 2π)
         (theta-norm (if (< theta 0.0d0) (+ theta (* 2.0d0 pi)) theta))
         (result (make-array 2 :element-type 'double-float)))
    (setf (aref result 0) theta-norm
          (aref result 1) r)
    result))

(defmethod transform-path ((tr inverted-polar-transform) path)
  "Transform all vertices in PATH from Cartesian to polar."
  (let* ((verts (mpl-path-vertices path))
         (n (array-dimension verts 0))
         (new-verts (make-array (list n 2) :element-type 'double-float)))
    (dotimes (i n)
      (let ((pt (transform-point tr (list (aref verts i 0) (aref verts i 1)))))
        (setf (aref new-verts i 0) (aref pt 0)
              (aref new-verts i 1) (aref pt 1))))
    (make-path :vertices new-verts
               :codes (mpl-path-codes path)
               :interpolation-steps (mpl-path-interpolation-steps path))))

(defmethod invert ((tr inverted-polar-transform))
  "Return the inverse transform (polar → Cartesian)."
  (make-instance 'polar-transform))

;;; ============================================================
;;; PolarAffine — maps polar Cartesian output to axes bbox
;;; ============================================================

(defclass polar-affine (affine-2d)
  ((r-max :initarg :r-max :initform 1.0d0 :accessor polar-affine-r-max
          :documentation "Maximum radius for scaling."))
  (:documentation "Affine transform that maps polar Cartesian output to axes bbox.
Scale factor: 0.5 / r_max. Translation: (0.5, 0.5).
Maps unit circle to center of [0,1]×[0,1] axes space."))

(defmethod initialize-instance :after ((pa polar-affine) &key r-max)
  (polar-affine-update pa (or r-max 1.0d0)))

(defun polar-affine-update (pa r-max)
  "Update polar-affine transform for new r-max."
  (let* ((scale (/ 0.5d0 (max r-max 1.0d-10)))
         (m (make-array 6 :element-type 'double-float)))
    ;; Matrix: scale x and y by scale, translate by (0.5, 0.5)
    ;; [scale  0     0.5]
    ;; [0      scale 0.5]
    ;; [0      0     1  ]
    ;; Stored as [a b c d e f] = [scale 0 0 scale 0.5 0.5]
    (setf (aref m 0) scale   ; a
          (aref m 1) 0.0d0   ; b
          (aref m 2) 0.0d0   ; c
          (aref m 3) scale   ; d
          (aref m 4) 0.5d0   ; e (x translation)
          (aref m 5) 0.5d0)  ; f (y translation)
    (setf (affine-2d-matrix pa) m)
    (setf (polar-affine-r-max pa) (float r-max 1.0d0))
    (setf (transform-node-invalid pa) +valid+)))
