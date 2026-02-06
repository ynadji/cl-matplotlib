;;;; transforms.lisp — Transform system with invalidation caching
;;;; Ported from matplotlib's transforms.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.primitives)

;;; ============================================================
;;; Invalidation state constants
;;; ============================================================

(defconstant +valid+ 0
  "Transform is valid; cached matrix is up to date.")
(defconstant +invalid-affine-only+ 1
  "Only the affine part is invalid; non-affine still valid.")
(defconstant +invalid-full+ 2
  "Everything is invalid; must fully recompute.")

;;; ============================================================
;;; Affine matrix type and identity
;;; ============================================================

(deftype affine-matrix ()
  "A 3×3 affine matrix stored as 6 doubles: [a b c d e f].
Represents: [[a c e] [b d f] [0 0 1]]
Transform point (x, y): x' = ax + cy + e, y' = bx + dy + f"
  '(simple-array double-float (6)))

(declaim (inline make-identity-matrix))
(defun make-identity-matrix ()
  "Return a fresh identity affine matrix."
  (make-array 6 :element-type 'double-float
                :initial-contents '(1.0d0 0.0d0 0.0d0 1.0d0 0.0d0 0.0d0)))

(declaim (inline matrix-a matrix-b matrix-c matrix-d matrix-e matrix-f))
(defun matrix-a (m) (declare (type affine-matrix m)) (aref m 0))
(defun matrix-b (m) (declare (type affine-matrix m)) (aref m 1))
(defun matrix-c (m) (declare (type affine-matrix m)) (aref m 2))
(defun matrix-d (m) (declare (type affine-matrix m)) (aref m 3))
(defun matrix-e (m) (declare (type affine-matrix m)) (aref m 4))
(defun matrix-f (m) (declare (type affine-matrix m)) (aref m 5))

;;; ============================================================
;;; Matrix operations
;;; ============================================================

(declaim (inline affine-matrix-multiply))
(defun affine-matrix-multiply (m1 m2)
  "Multiply two affine matrices. Result = M1 * M2.
M1 is applied AFTER M2 (i.e., M1(M2(point)))."
  (declare (type affine-matrix m1 m2))
  (let ((a1 (aref m1 0)) (b1 (aref m1 1))
        (c1 (aref m1 2)) (d1 (aref m1 3))
        (e1 (aref m1 4)) (f1 (aref m1 5))
        (a2 (aref m2 0)) (b2 (aref m2 1))
        (c2 (aref m2 2)) (d2 (aref m2 3))
        (e2 (aref m2 4)) (f2 (aref m2 5)))
    (declare (type double-float a1 b1 c1 d1 e1 f1 a2 b2 c2 d2 e2 f2))
    (let ((result (make-array 6 :element-type 'double-float)))
      (setf (aref result 0) (+ (* a1 a2) (* c1 b2))       ; a
            (aref result 1) (+ (* b1 a2) (* d1 b2))       ; b
            (aref result 2) (+ (* a1 c2) (* c1 d2))       ; c
            (aref result 3) (+ (* b1 c2) (* d1 d2))       ; d
            (aref result 4) (+ (* a1 e2) (* c1 f2) e1)    ; e
            (aref result 5) (+ (* b1 e2) (* d1 f2) f1))   ; f
      result)))

(defun affine-matrix-invert (m)
  "Compute the inverse of an affine matrix.
Signals error if matrix is singular (determinant = 0)."
  (declare (type affine-matrix m))
  (let* ((a (aref m 0)) (b (aref m 1))
         (c (aref m 2)) (d (aref m 3))
         (e (aref m 4)) (f (aref m 5))
         (det (- (* a d) (* b c))))
    (declare (type double-float a b c d e f det))
    (when (zerop det)
      (error "Singular affine matrix cannot be inverted"))
    (let ((inv-det (/ 1.0d0 det))
          (result (make-array 6 :element-type 'double-float)))
      (setf (aref result 0) (* d inv-det)                          ; a
            (aref result 1) (* (- b) inv-det)                      ; b
            (aref result 2) (* (- c) inv-det)                      ; c
            (aref result 3) (* a inv-det)                          ; d
            (aref result 4) (* (- (* c f) (* d e)) inv-det)        ; e
            (aref result 5) (* (- (* b e) (* a f)) inv-det))       ; f
      result)))

(declaim (inline affine-transform-point))
(defun affine-transform-point (m x y)
  "Transform a single point (X, Y) by affine matrix M.
Returns (values new-x new-y)."
  (declare (type affine-matrix m)
           (type double-float x y))
  (values (+ (* (aref m 0) x) (* (aref m 2) y) (aref m 4))
          (+ (* (aref m 1) x) (* (aref m 3) y) (aref m 5))))

(defun copy-matrix (m)
  "Return a fresh copy of affine matrix M."
  (declare (type affine-matrix m))
  (let ((result (make-array 6 :element-type 'double-float)))
    (replace result m)
    result))

(defun matrix-equal-p (m1 m2)
  "Return T if two affine matrices are element-wise equal."
  (declare (type affine-matrix m1 m2))
  (and (= (aref m1 0) (aref m2 0))
       (= (aref m1 1) (aref m2 1))
       (= (aref m1 2) (aref m2 2))
       (= (aref m1 3) (aref m2 3))
       (= (aref m1 4) (aref m2 4))
       (= (aref m1 5) (aref m2 5))))

;;; ============================================================
;;; Transform node — base class for invalidation tree
;;; ============================================================

(defclass transform-node ()
  ((parents :initform nil :accessor transform-node-parents
            :documentation "List of weak pointers to parent transform nodes.")
   (invalid :initform +invalid-full+ :accessor transform-node-invalid
            :type fixnum
            :documentation "Invalidation state: +valid+, +invalid-affine-only+, +invalid-full+.")
   (is-affine :initform nil :reader transform-node-is-affine-p
              :allocation :class
              :documentation "T if this transform is affine.")
   (pass-through :initform nil :reader transform-node-pass-through-p
                 :allocation :class
                 :documentation "If T, invalidation always propagates to parents."))
  (:documentation "Base class for anything in the transform tree that needs invalidation."))

(defgeneric frozen (node)
  (:documentation "Return an immutable snapshot of this transform node."))

(defmethod frozen ((node transform-node))
  node)

(defun prune-dead-parents (node)
  "Remove weak pointers whose referents have been garbage collected."
  (setf (transform-node-parents node)
        (delete-if-not (lambda (wp)
                         (trivial-garbage:weak-pointer-value wp))
                       (transform-node-parents node))))

(defun invalidate (node)
  "Invalidate this transform node and propagate upward to parents."
  (invalidate-internal node
                       (if (transform-node-is-affine-p node)
                           +invalid-affine-only+
                           +invalid-full+)))

(defun invalidate-internal (node level)
  "Internal invalidation: set level and walk parents."
  (when (and (<= level (transform-node-invalid node))
             (not (transform-node-pass-through-p node)))
    (return-from invalidate-internal))
  (setf (transform-node-invalid node) level)
  ;; Walk weak-pointer parents, prune dead refs
  (let ((live-parents nil))
    (dolist (wp (transform-node-parents node))
      (let ((parent (trivial-garbage:weak-pointer-value wp)))
        (when parent
          (push wp live-parents)
          (invalidate-internal parent level))))
    (setf (transform-node-parents node) (nreverse live-parents))))

(defun set-children (parent &rest children)
  "Register PARENT as a dependent of each child.
Uses weak pointers so children don't prevent parent from being GC'd."
  (dolist (child children)
    (push (trivial-garbage:make-weak-pointer parent)
          (transform-node-parents child))))

;;; ============================================================
;;; Transform — abstract base for actual transformations
;;; ============================================================

(defclass transform (transform-node)
  ((input-dims :initform 2 :reader transform-input-dims :allocation :class)
   (output-dims :initform 2 :reader transform-output-dims :allocation :class)
   (has-inverse :initform nil :reader transform-has-inverse-p :allocation :class))
  (:documentation "Base class for all transforms that actually transform coordinates."))

(defgeneric get-matrix (transform)
  (:documentation "Return the affine matrix for this transform (compute if invalid)."))

(defgeneric transform-point (transform point)
  (:documentation "Transform a point (vector of 2 doubles). Returns a new vector."))

(defgeneric transform-path (transform path)
  (:documentation "Transform a path by applying this transform to all vertices."))

(defgeneric invert (transform)
  (:documentation "Return the inverse transform."))

(defgeneric compose (a b)
  (:documentation "Compose two transforms: apply A first, then B.
Returns a new transform C such that C(point) = B(A(point))."))

;;; ============================================================
;;; Affine2DBase — read-only base for 2D affine transforms
;;; ============================================================

(defclass affine-2d-base (transform)
  ((is-affine :initform t :allocation :class)
   (has-inverse :initform t :allocation :class)
   (cached-inverse :initform nil :accessor transform-cached-inverse))
  (:documentation "Base class for 2D affine transforms. Provides read-only interface."))

(defmethod transform-point ((tr affine-2d-base) point)
  "Transform a point using the affine matrix."
  (let ((m (get-matrix tr))
        (x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
        (y (float (if (listp point) (second point) (elt point 1)) 1.0d0)))
    (declare (type affine-matrix m) (type double-float x y))
    (multiple-value-bind (nx ny) (affine-transform-point m x y)
      (let ((result (make-array 2 :element-type 'double-float)))
        (setf (aref result 0) nx
              (aref result 1) ny)
        result))))

(defmethod transform-path ((tr affine-2d-base) path)
  "Transform all vertices in PATH by this affine transform."
  (let* ((m (get-matrix tr))
         (verts (mpl-path-vertices path))
         (n (array-dimension verts 0))
         (new-verts (make-array (list n 2) :element-type 'double-float)))
    (declare (type affine-matrix m))
    (dotimes (i n)
      (let ((x (aref verts i 0))
            (y (aref verts i 1)))
        (declare (type double-float x y))
        (multiple-value-bind (nx ny) (affine-transform-point m x y)
          (setf (aref new-verts i 0) nx
                (aref new-verts i 1) ny))))
    (make-path :vertices new-verts
               :codes (mpl-path-codes path)
               :interpolation-steps (mpl-path-interpolation-steps path))))

(defmethod invert ((tr affine-2d-base))
  "Return the inverse affine transform."
  (when (or (null (transform-cached-inverse tr))
            (/= (transform-node-invalid tr) +valid+))
    (let ((inv-mtx (affine-matrix-invert (get-matrix tr))))
      (setf (transform-cached-inverse tr) (make-instance 'affine-2d :matrix inv-mtx))
      (setf (transform-node-invalid tr) +valid+)))
  (transform-cached-inverse tr))

(defmethod frozen ((tr affine-2d-base))
  "Return a frozen (immutable) copy of this affine transform."
  (make-instance 'frozen-transform :matrix (copy-matrix (get-matrix tr))))

;;; ============================================================
;;; Affine2D — mutable 2D affine transform
;;; ============================================================

(defclass affine-2d (affine-2d-base)
  ((matrix :type affine-matrix
           :accessor affine-2d-matrix
           :documentation "The 3×3 affine matrix stored as 6 doubles."))
  (:documentation "A mutable 2D affine transformation."))

(defmethod initialize-instance :after ((tr affine-2d) &key matrix translate scale rotate)
  "Initialize affine-2d. Accepts :matrix, :translate, :scale, :rotate."
  (cond
    ;; Explicit matrix (already a 6-element array)
    ((and matrix (typep matrix '(simple-array double-float (6))))
     (setf (affine-2d-matrix tr) (copy-matrix matrix)))
    ;; Matrix as list of 6 values
    ((and matrix (listp matrix))
     (let ((m (make-array 6 :element-type 'double-float)))
       (loop for v in matrix for i from 0
             do (setf (aref m i) (float v 1.0d0)))
       (setf (affine-2d-matrix tr) m)))
    ;; Start with identity, apply operations
    (t
     (setf (affine-2d-matrix tr) (make-identity-matrix))
     (when scale
       (let ((sx (float (if (listp scale) (first scale) (elt scale 0)) 1.0d0))
             (sy (float (if (listp scale) (second scale) (elt scale 1)) 1.0d0)))
         (affine-2d-scale tr sx sy)))
     (when rotate
       (affine-2d-rotate tr (float rotate 1.0d0)))
     (when translate
       (let ((tx (float (if (listp translate) (first translate) (elt translate 0)) 1.0d0))
             (ty (float (if (listp translate) (second translate) (elt translate 1)) 1.0d0)))
         (affine-2d-translate tr tx ty)))))
  (setf (transform-node-invalid tr) +valid+))

(defun make-affine-2d (&rest args &key matrix translate scale rotate)
  "Create a new mutable Affine2D transform.
Keyword arguments:
  :matrix — A 6-element double-float array [a b c d e f] or list
  :translate — A list or vector (tx ty) for translation
  :scale — A list or vector (sx sy) for scaling
  :rotate — An angle in radians for rotation
Operations are applied in order: scale, rotate, translate."
  (declare (ignore matrix translate scale rotate))
  (apply #'make-instance 'affine-2d args))

(defmethod get-matrix ((tr affine-2d))
  "Return the underlying affine matrix."
  (when (/= (transform-node-invalid tr) +valid+)
    (setf (transform-cached-inverse tr) nil)
    (setf (transform-node-invalid tr) +valid+))
  (affine-2d-matrix tr))

(defun set-matrix (tr matrix)
  "Set the affine matrix of TR and invalidate."
  (setf (affine-2d-matrix tr) (copy-matrix matrix))
  (invalidate tr))

(defun affine-2d-clear (tr)
  "Reset transform to identity."
  (setf (affine-2d-matrix tr) (make-identity-matrix))
  (invalidate tr)
  tr)

(defun affine-2d-translate (tr tx ty)
  "Add a translation in place. Returns TR for chaining."
  (declare (type double-float tx ty))
  (let ((m (affine-2d-matrix tr)))
    (declare (type affine-matrix m))
    (incf (aref m 4) tx)
    (incf (aref m 5) ty))
  (invalidate tr)
  tr)

(defun set-translate (tr translate-spec)
  "Set the translation component of TR. TRANSLATE-SPEC is a list or vector (tx ty)."
  (let ((tx (float (if (listp translate-spec) (first translate-spec) (elt translate-spec 0)) 1.0d0))
        (ty (float (if (listp translate-spec) (second translate-spec) (elt translate-spec 1)) 1.0d0))
        (m (affine-2d-matrix tr)))
    (declare (type affine-matrix m) (type double-float tx ty))
    ;; For a pure translation change, reset the translation components
    ;; while keeping the rest of the matrix intact
    (setf (aref m 4) tx
          (aref m 5) ty))
  (invalidate tr)
  tr)

(defun affine-2d-scale (tr sx &optional (sy nil sy-supplied-p))
  "Add a scale in place. If SY is nil, uses SX for both axes. Returns TR for chaining."
  (let ((sx (float sx 1.0d0))
        (sy (if sy-supplied-p (float sy 1.0d0) (float sx 1.0d0))))
    (declare (type double-float sx sy))
    (let ((m (affine-2d-matrix tr)))
      (declare (type affine-matrix m))
      (setf (aref m 0) (* (aref m 0) sx)
            (aref m 2) (* (aref m 2) sx)
            (aref m 4) (* (aref m 4) sx)
            (aref m 1) (* (aref m 1) sy)
            (aref m 3) (* (aref m 3) sy)
            (aref m 5) (* (aref m 5) sy))))
  (invalidate tr)
  tr)

(defun affine-2d-rotate (tr theta)
  "Add a rotation of THETA radians in place. Returns TR for chaining."
  (declare (type double-float theta))
  (let* ((a (cos theta))
         (b (sin theta))
         (m (affine-2d-matrix tr))
         (xx (aref m 0)) (xy (aref m 2)) (x0 (aref m 4))
         (yx (aref m 1)) (yy (aref m 3)) (y0 (aref m 5)))
    (declare (type double-float a b xx xy x0 yx yy y0))
    ;; mtx = [[a -b 0], [b a 0], [0 0 1]] * mtx
    (setf (aref m 0) (- (* a xx) (* b yx))
          (aref m 2) (- (* a xy) (* b yy))
          (aref m 4) (- (* a x0) (* b y0))
          (aref m 1) (+ (* b xx) (* a yx))
          (aref m 3) (+ (* b xy) (* a yy))
          (aref m 5) (+ (* b x0) (* a y0))))
  (invalidate tr)
  tr)

(defun affine-2d-rotate-deg (tr degrees)
  "Add a rotation of DEGREES in place. Returns TR for chaining."
  (affine-2d-rotate tr (* (float degrees 1.0d0) (/ pi 180.0d0))))

(defun affine-2d-rotate-around (tr x y theta)
  "Add a rotation of THETA radians around point (X, Y). Returns TR for chaining."
  (affine-2d-translate tr (- (float x 1.0d0)) (- (float y 1.0d0)))
  (affine-2d-rotate tr (float theta 1.0d0))
  (affine-2d-translate tr (float x 1.0d0) (float y 1.0d0))
  tr)

(defun affine-2d-rotate-deg-around (tr x y degrees)
  "Add a rotation of DEGREES around point (X, Y). Returns TR for chaining."
  (affine-2d-rotate-around tr x y (* (float degrees 1.0d0) (/ pi 180.0d0))))

(defun affine-2d-skew (tr x-shear y-shear)
  "Add a skew in place. X-SHEAR and Y-SHEAR are in radians. Returns TR for chaining."
  (let* ((rx (tan (float x-shear 1.0d0)))
         (ry (tan (float y-shear 1.0d0)))
         (m (affine-2d-matrix tr))
         (xx (aref m 0)) (xy (aref m 2)) (x0 (aref m 4))
         (yx (aref m 1)) (yy (aref m 3)) (y0 (aref m 5)))
    (declare (type double-float rx ry xx xy x0 yx yy y0))
    ;; mtx = [[1 rx 0], [ry 1 0], [0 0 1]] * mtx
    (setf (aref m 0) (+ xx (* rx yx))
          (aref m 2) (+ xy (* rx yy))
          (aref m 4) (+ x0 (* rx y0))
          (aref m 1) (+ (* ry xx) yx)
          (aref m 3) (+ (* ry xy) yy)
          (aref m 5) (+ (* ry x0) y0)))
  (invalidate tr)
  tr)

(defun affine-2d-skew-deg (tr x-shear y-shear)
  "Add a skew in place. X-SHEAR and Y-SHEAR are in degrees. Returns TR for chaining."
  (affine-2d-skew tr
                  (* (float x-shear 1.0d0) (/ pi 180.0d0))
                  (* (float y-shear 1.0d0) (/ pi 180.0d0))))

;;; ============================================================
;;; IdentityTransform — singleton identity
;;; ============================================================

(defclass identity-transform (affine-2d-base)
  ()
  (:documentation "The identity transform — does nothing."))

(defvar *identity-transform-matrix* (make-identity-matrix)
  "Shared identity matrix (do not mutate).")

(defmethod get-matrix ((tr identity-transform))
  *identity-transform-matrix*)

(defmethod transform-point ((tr identity-transform) point)
  (let ((result (make-array 2 :element-type 'double-float)))
    (setf (aref result 0) (float (if (listp point) (first point) (elt point 0)) 1.0d0)
          (aref result 1) (float (if (listp point) (second point) (elt point 1)) 1.0d0))
    result))

(defmethod transform-path ((tr identity-transform) path)
  path)

(defmethod invert ((tr identity-transform))
  tr)

(defmethod frozen ((tr identity-transform))
  tr)

(defvar *identity-transform* (make-instance 'identity-transform)
  "Singleton identity transform instance.")

(defun make-identity-transform ()
  "Return the singleton identity transform."
  *identity-transform*)

;;; ============================================================
;;; FrozenTransform — immutable snapshot
;;; ============================================================

(defclass frozen-transform (affine-2d-base)
  ((matrix :type affine-matrix :reader frozen-transform-matrix
           :documentation "Immutable affine matrix."))
  (:documentation "An immutable frozen snapshot of an affine transform.
Does not participate in invalidation."))

(defmethod initialize-instance :after ((tr frozen-transform) &key matrix)
  (setf (slot-value tr 'matrix)
        (if matrix (copy-matrix matrix) (make-identity-matrix)))
  (setf (transform-node-invalid tr) +valid+))

(defmethod get-matrix ((tr frozen-transform))
  (frozen-transform-matrix tr))

(defmethod frozen ((tr frozen-transform))
  tr)

;;; ============================================================
;;; CompositeAffine2D — composition of two affine transforms
;;; ============================================================

(defclass composite-affine-2d (affine-2d-base)
  ((transform-a :initarg :a :reader composite-a
                :documentation "First transform (applied first).")
   (transform-b :initarg :b :reader composite-b
                :documentation "Second transform (applied second).")
   (cached-matrix :initform nil :accessor composite-cached-matrix
                  :documentation "Cached result of matrix multiplication.")
   (pass-through :initform t :allocation :class))
  (:documentation "Composite of two affine 2D transforms."))

(defmethod initialize-instance :after ((tr composite-affine-2d) &key a b)
  (set-children tr a b)
  (setf (transform-node-invalid tr) +invalid-full+))

(defmethod get-matrix ((tr composite-affine-2d))
  "Compute B * A matrix product (apply A first, then B)."
  (when (/= (transform-node-invalid tr) +valid+)
    (let ((ma (get-matrix (composite-a tr)))
          (mb (get-matrix (composite-b tr))))
      (setf (composite-cached-matrix tr)
            (affine-matrix-multiply mb ma))
      (setf (transform-cached-inverse tr) nil)
      (setf (transform-node-invalid tr) +valid+)))
  (composite-cached-matrix tr))

;;; ============================================================
;;; CompositeGenericTransform — composition of arbitrary transforms
;;; ============================================================

(defclass composite-generic-transform (transform)
  ((transform-a :initarg :a :reader composite-a
                :documentation "First transform (applied first).")
   (transform-b :initarg :b :reader composite-b
                :documentation "Second transform (applied second).")
   (pass-through :initform t :allocation :class))
  (:documentation "Composite of two arbitrary transforms."))

(defmethod initialize-instance :after ((tr composite-generic-transform) &key a b)
  (set-children tr a b)
  (setf (transform-node-invalid tr) +invalid-full+))

(defmethod get-matrix ((tr composite-generic-transform))
  "Get the affine matrix for the composite (delegates to affine parts)."
  (let ((ma (get-matrix (composite-a tr)))
        (mb (get-matrix (composite-b tr))))
    (affine-matrix-multiply mb ma)))

(defmethod transform-point ((tr composite-generic-transform) point)
  "Transform by applying A then B."
  (transform-point (composite-b tr)
                   (transform-point (composite-a tr) point)))

(defmethod transform-path ((tr composite-generic-transform) path)
  "Transform path by applying A then B."
  (transform-path (composite-b tr)
                  (transform-path (composite-a tr) path)))

(defmethod invert ((tr composite-generic-transform))
  "Invert composite: (A then B)^-1 = B^-1 then A^-1."
  (compose (invert (composite-b tr))
           (invert (composite-a tr))))

;;; ============================================================
;;; compose — the main composition generic function
;;; ============================================================

(defmethod compose ((a affine-2d-base) (b affine-2d-base))
  "Compose two affine transforms: apply A first, then B."
  (if (typep a 'identity-transform)
      b
      (if (typep b 'identity-transform)
          a
          (make-instance 'composite-affine-2d :a a :b b))))

(defmethod compose ((a transform) (b transform))
  "Compose two arbitrary transforms: apply A first, then B."
  (if (typep a 'identity-transform)
      b
      (if (typep b 'identity-transform)
          a
          (if (and (transform-node-is-affine-p a)
                   (transform-node-is-affine-p b))
              (make-instance 'composite-affine-2d :a a :b b)
              (make-instance 'composite-generic-transform :a a :b b)))))

;;; ============================================================
;;; BlendedAffine2D — separate X/Y transforms (both affine)
;;; ============================================================

(defclass blended-affine-2d (affine-2d-base)
  ((x-transform :initarg :x :reader blended-x-transform
                :documentation "Transform for the X dimension.")
   (y-transform :initarg :y :reader blended-y-transform
                :documentation "Transform for the Y dimension.")
   (cached-matrix :initform nil :accessor blended-cached-matrix))
  (:documentation "A blended transform using one transform for X, another for Y (affine)."))

(defmethod initialize-instance :after ((tr blended-affine-2d) &key x y)
  (set-children tr x y)
  (setf (transform-node-invalid tr) +invalid-full+))

(defmethod get-matrix ((tr blended-affine-2d))
  "Build blended matrix from X and Y transform matrices."
  (when (/= (transform-node-invalid tr) +valid+)
    (let ((mx (get-matrix (blended-x-transform tr)))
          (my (get-matrix (blended-y-transform tr))))
      (declare (type affine-matrix mx my))
      ;; Take x-row from mx, y-row from my
      (let ((result (make-array 6 :element-type 'double-float)))
        (setf (aref result 0) (aref mx 0)   ; a (from x)
              (aref result 1) (aref my 1)    ; b (from y)
              (aref result 2) (aref mx 2)    ; c (from x)
              (aref result 3) (aref my 3)    ; d (from y)
              (aref result 4) (aref mx 4)    ; e (from x)
              (aref result 5) (aref my 5))   ; f (from y)
        (setf (blended-cached-matrix tr) result)))
    (setf (transform-cached-inverse tr) nil)
    (setf (transform-node-invalid tr) +valid+))
  (blended-cached-matrix tr))

;;; ============================================================
;;; BlendedGenericTransform — separate X/Y transforms (generic)
;;; ============================================================

(defclass blended-generic-transform (transform)
  ((x-transform :initarg :x :reader blended-x-transform
                :documentation "Transform for the X dimension.")
   (y-transform :initarg :y :reader blended-y-transform
                :documentation "Transform for the Y dimension.")
   (pass-through :initform t :allocation :class))
  (:documentation "A blended transform using one transform for X, another for Y (generic)."))

(defmethod initialize-instance :after ((tr blended-generic-transform) &key x y)
  (set-children tr x y)
  (setf (transform-node-invalid tr) +invalid-full+))

(defmethod transform-point ((tr blended-generic-transform) point)
  "Transform X using x-transform, Y using y-transform."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (tx (transform-point (blended-x-transform tr) (list x y)))
         (ty (transform-point (blended-y-transform tr) (list x y)))
         (result (make-array 2 :element-type 'double-float)))
    (setf (aref result 0) (aref tx 0)
          (aref result 1) (aref ty 1))
    result))

(defmethod invert ((tr blended-generic-transform))
  "Invert blended transform by inverting each component."
  (make-blended-transform (invert (blended-x-transform tr))
                          (invert (blended-y-transform tr))))

(defun make-blended-transform (x-transform y-transform)
  "Create a blended transform. Uses optimized affine version when possible."
  (if (and (typep x-transform 'affine-2d-base)
           (typep y-transform 'affine-2d-base))
      (make-instance 'blended-affine-2d :x x-transform :y y-transform)
      (make-instance 'blended-generic-transform :x x-transform :y y-transform)))

;;; ============================================================
;;; TransformWrapper — mutable wrapper around a child transform
;;; ============================================================

(defclass transform-wrapper (transform)
  ((child :initarg :child :accessor transform-wrapper-child
          :documentation "The wrapped child transform.")
   (pass-through :initform t :allocation :class))
  (:documentation "A mutable wrapper that delegates to a child transform."))

(defmethod initialize-instance :after ((tr transform-wrapper) &key child)
  (when child
    (set-children tr child)
    (setf (transform-node-invalid tr) +valid+)))

(defmethod get-matrix ((tr transform-wrapper))
  (get-matrix (transform-wrapper-child tr)))

(defmethod transform-point ((tr transform-wrapper) point)
  (transform-point (transform-wrapper-child tr) point))

(defmethod transform-path ((tr transform-wrapper) path)
  (transform-path (transform-wrapper-child tr) path))

(defmethod invert ((tr transform-wrapper))
  (invert (transform-wrapper-child tr)))

(defmethod frozen ((tr transform-wrapper))
  (frozen (transform-wrapper-child tr)))

(defun transform-wrapper-set (wrapper new-child)
  "Replace the child of WRAPPER with NEW-CHILD."
  (invalidate wrapper)
  (setf (transform-wrapper-child wrapper) new-child)
  (set-children wrapper new-child)
  (setf (transform-node-invalid wrapper) +valid+)
  (invalidate wrapper)
  (setf (transform-node-invalid wrapper) +valid+))

;;; ============================================================
;;; BboxTransform — linear transform between two bboxes
;;; ============================================================

(defclass bbox-transform (affine-2d-base)
  ((boxin :initarg :boxin :reader bbox-transform-boxin)
   (boxout :initarg :boxout :reader bbox-transform-boxout)
   (cached-matrix :initform nil :accessor bbox-transform-cached-matrix))
  (:documentation "Transform that linearly maps points from one bbox to another."))

(defmethod initialize-instance :after ((tr bbox-transform) &key boxin boxout)
  (declare (ignore boxin boxout))
  (setf (transform-node-invalid tr) +invalid-full+))

(defmethod get-matrix ((tr bbox-transform))
  (when (/= (transform-node-invalid tr) +valid+)
    (let* ((bin (bbox-transform-boxin tr))
           (bout (bbox-transform-boxout tr))
           (inl (bbox-x0 bin)) (inb (bbox-y0 bin))
           (inw (bbox-width bin)) (inh (bbox-height bin))
           (outl (bbox-x0 bout)) (outb (bbox-y0 bout))
           (outw (bbox-width bout)) (outh (bbox-height bout))
           (x-scale (/ outw inw))
           (y-scale (/ outh inh))
           (result (make-array 6 :element-type 'double-float)))
      (setf (aref result 0) x-scale
            (aref result 1) 0.0d0
            (aref result 2) 0.0d0
            (aref result 3) y-scale
            (aref result 4) (+ (- (* inl x-scale)) outl)
            (aref result 5) (+ (- (* inb y-scale)) outb))
      (setf (bbox-transform-cached-matrix tr) result)
      (setf (transform-cached-inverse tr) nil)
      (setf (transform-node-invalid tr) +valid+)))
  (bbox-transform-cached-matrix tr))

(defun make-bbox-transform (boxin boxout)
  "Create a transform that linearly maps from BOXIN to BOXOUT."
  (make-instance 'bbox-transform :boxin boxin :boxout boxout))

;;; ============================================================
;;; TransformedBbox — bbox that auto-updates from a transform
;;; ============================================================

(defclass transformed-bbox (transform-node)
  ((source-bbox :initarg :bbox :reader transformed-bbox-source)
   (source-transform :initarg :transform :reader transformed-bbox-transform)
   (cached-x0 :initform 0.0d0 :type double-float)
   (cached-y0 :initform 0.0d0 :type double-float)
   (cached-x1 :initform 0.0d0 :type double-float)
   (cached-y1 :initform 0.0d0 :type double-float)
   (is-affine :initform t :allocation :class))
  (:documentation "A bbox that is automatically transformed by a given transform."))

(defmethod initialize-instance :after ((tb transformed-bbox) &key bbox transform)
  (declare (ignore bbox transform))
  (setf (transform-node-invalid tb) +invalid-full+))

(defun transformed-bbox-recompute (tb)
  "Recompute the transformed bbox if invalid."
  (when (/= (transform-node-invalid tb) +valid+)
    (let* ((src (transformed-bbox-source tb))
           (tr (transformed-bbox-transform tb))
           (x0 (bbox-x0 src)) (y0 (bbox-y0 src))
           (x1 (bbox-x1 src)) (y1 (bbox-y1 src)))
      ;; Transform all four corners
      (let ((p1 (transform-point tr (list x0 y0)))
            (p2 (transform-point tr (list x0 y1)))
            (p3 (transform-point tr (list x1 y0)))
            (p4 (transform-point tr (list x1 y1))))
        ;; Find bounding box of transformed corners
        (let ((min-x (min (aref p1 0) (aref p2 0) (aref p3 0) (aref p4 0)))
              (max-x (max (aref p1 0) (aref p2 0) (aref p3 0) (aref p4 0)))
              (min-y (min (aref p1 1) (aref p2 1) (aref p3 1) (aref p4 1)))
              (max-y (max (aref p1 1) (aref p2 1) (aref p3 1) (aref p4 1))))
          (setf (slot-value tb 'cached-x0) min-x
                (slot-value tb 'cached-y0) min-y
                (slot-value tb 'cached-x1) max-x
                (slot-value tb 'cached-y1) max-y))))
    (setf (transform-node-invalid tb) +valid+)))

(defun transformed-bbox-x0 (tb)
  (transformed-bbox-recompute tb)
  (slot-value tb 'cached-x0))
(defun transformed-bbox-y0 (tb)
  (transformed-bbox-recompute tb)
  (slot-value tb 'cached-y0))
(defun transformed-bbox-x1 (tb)
  (transformed-bbox-recompute tb)
  (slot-value tb 'cached-x1))
(defun transformed-bbox-y1 (tb)
  (transformed-bbox-recompute tb)
  (slot-value tb 'cached-y1))

(defun make-transformed-bbox (bbox transform)
  "Create a bbox that auto-transforms when bbox or transform changes."
  (make-instance 'transformed-bbox :bbox bbox :transform transform))

;;; ============================================================
;;; TransformedPath — cached transformed path
;;; ============================================================

(defclass transformed-path-node (transform-node)
  ((source-path :initarg :path :reader transformed-path-source)
   (source-transform :initarg :transform :reader transformed-path-transform)
   (cached-path :initform nil :accessor transformed-path-cached))
  (:documentation "Caches a transformed copy of a path, auto-updating when transform changes."))

(defmethod initialize-instance :after ((tp transformed-path-node) &key transform path)
  (declare (ignore path))
  (when transform
    (set-children tp transform))
  (setf (transform-node-invalid tp) +invalid-full+))

(defun transformed-path-get (tp)
  "Return the fully transformed path, recomputing if necessary."
  (when (or (/= (transform-node-invalid tp) +valid+)
            (null (transformed-path-cached tp)))
    (setf (transformed-path-cached tp)
          (transform-path (transformed-path-transform tp)
                          (transformed-path-source tp)))
    (setf (transform-node-invalid tp) +valid+))
  (transformed-path-cached tp))
