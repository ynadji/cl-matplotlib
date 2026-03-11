;;;; scale-transforms.lisp — Scale-specific transforms for logarithmic and other non-linear scales
;;;; Ported from matplotlib's scale.py transform classes
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.primitives)

;;; ============================================================
;;; LogTransform — logarithmic transform
;;; ============================================================

(defclass log-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor log-transform-base
         :type double-float
         :documentation "Base of the logarithm.")
   (nonpositive :initarg :nonpositive
                :initform :clip
                :accessor log-transform-nonpositive
                :documentation "How to handle non-positive values: :clip or :mask."))
  (:documentation "Logarithmic transform: forward(x) = log_base(x).
Ported from matplotlib.scale.LogTransform."))

(defmethod initialize-instance :after ((tr log-transform) &key base nonpositive)
  (declare (ignore nonpositive))
  (when base
    (when (or (<= base 0.0d0) (= base 1.0d0))
      (error "The log base cannot be <= 0 or == 1"))))

(defmethod transform-point ((tr log-transform) point)
  "Transform a point using logarithm."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (log-transform-base tr))
         (clip-p (eq (log-transform-nonpositive tr) :clip))
         (result (make-array 2 :element-type 'double-float)))
    ;; Transform x coordinate
    (setf (aref result 0)
          (cond
            ((<= x 0.0d0)
             (if clip-p -1000.0d0 (/ 0.0d0 0.0d0))) ; NaN for mask
            (t
             (/ (log x) (log base)))))
    ;; Y coordinate passes through unchanged
    (setf (aref result 1) y)
    result))

(defmethod transform-path ((tr log-transform) path)
  "Transform all vertices in PATH by this log transform (X axis)."
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

(defmethod invert ((tr log-transform))
  "Return the inverse transform (InvertedLogTransform)."
  (make-instance 'inverted-log-transform :base (log-transform-base tr)))

;;; ============================================================
;;; LogYTransform — logarithmic transform on Y axis
;;; ============================================================

(defclass log-y-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor log-y-transform-base
         :type double-float
         :documentation "Base of the logarithm.")
   (nonpositive :initarg :nonpositive
                :initform :clip
                :accessor log-y-transform-nonpositive
                :documentation "How to handle non-positive values: :clip or :mask."))
  (:documentation "Logarithmic transform on Y axis: forward(x,y) = (x, log_base(y)).
Ported from matplotlib.scale.LogTransform, applied to Y dimension."))

(defmethod initialize-instance :after ((tr log-y-transform) &key base nonpositive)
  (declare (ignore nonpositive))
  (when base
    (when (or (<= base 0.0d0) (= base 1.0d0))
      (error "The log base cannot be <= 0 or == 1"))))

(defmethod transform-point ((tr log-y-transform) point)
  "Transform a point using logarithm on Y coordinate."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (log-y-transform-base tr))
         (clip-p (eq (log-y-transform-nonpositive tr) :clip))
         (result (make-array 2 :element-type 'double-float)))
    ;; X coordinate passes through unchanged
    (setf (aref result 0) x)
    ;; Transform y coordinate
    (setf (aref result 1)
          (cond
            ((<= y 0.0d0)
             (if clip-p -1000.0d0 (/ 0.0d0 0.0d0))) ; NaN for mask
            (t
             (/ (log y) (log base)))))
    result))

(defmethod transform-path ((tr log-y-transform) path)
  "Transform all vertices in PATH by this log-Y transform."
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

(defmethod invert ((tr log-y-transform))
  "Return the inverse transform (InvertedLogYTransform)."
  (make-instance 'inverted-log-y-transform :base (log-y-transform-base tr)))

;;; ============================================================
;;; InvertedLogYTransform — inverse of logarithmic Y transform
;;; ============================================================

(defclass inverted-log-y-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor inverted-log-y-transform-base
         :type double-float
         :documentation "Base of the logarithm."))
  (:documentation "Inverse logarithmic Y transform: forward(x,y) = (x, base^y).
Ported from matplotlib.scale.InvertedLogTransform, applied to Y dimension."))

(defmethod transform-point ((tr inverted-log-y-transform) point)
  "Transform a point using exponentiation on Y coordinate."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (inverted-log-y-transform-base tr))
         (result (make-array 2 :element-type 'double-float)))
    ;; X coordinate passes through unchanged
    (setf (aref result 0) x)
    ;; Transform y coordinate: base^y
    (setf (aref result 1) (expt base y))
    result))

(defmethod transform-path ((tr inverted-log-y-transform) path)
  "Transform all vertices in PATH by this inverted log-Y transform."
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

(defmethod invert ((tr inverted-log-y-transform))
  "Return the inverse transform (LogYTransform)."
  (make-instance 'log-y-transform :base (inverted-log-y-transform-base tr)))

;;; ============================================================
;;; LogXYTransform — logarithmic transform on BOTH X and Y axes
;;; ============================================================

(defclass log-xy-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor log-xy-transform-base
         :type double-float
         :documentation "Base of the logarithm.")
   (nonpositive :initarg :nonpositive
                :initform :clip
                :accessor log-xy-transform-nonpositive
                :documentation "How to handle non-positive values: :clip or :mask."))
  (:documentation "Logarithmic transform on BOTH X and Y axes.
Used for loglog plots where both axes are log-scale."))

(defmethod initialize-instance :after ((tr log-xy-transform) &key base nonpositive)
  (declare (ignore nonpositive))
  (when base
    (when (or (<= base 0.0d0) (= base 1.0d0))
      (error "The log base cannot be <= 0 or == 1"))))

(defmethod transform-point ((tr log-xy-transform) point)
  "Transform a point using logarithm on BOTH X and Y coordinates."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (log-xy-transform-base tr))
         (clip-p (eq (log-xy-transform-nonpositive tr) :clip))
         (result (make-array 2 :element-type 'double-float)))
    ;; Transform x coordinate
    (setf (aref result 0)
          (cond
            ((<= x 0.0d0)
             (if clip-p -1000.0d0 (/ 0.0d0 0.0d0)))
            (t
             (/ (log x) (log base)))))
    ;; Transform y coordinate
    (setf (aref result 1)
          (cond
            ((<= y 0.0d0)
             (if clip-p -1000.0d0 (/ 0.0d0 0.0d0)))
            (t
             (/ (log y) (log base)))))
    result))

(defmethod transform-path ((tr log-xy-transform) path)
  "Transform all vertices in PATH by this log-XY transform."
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

(defmethod invert ((tr log-xy-transform))
  "Return the inverse transform (InvertedLogXYTransform)."
  (make-instance 'inverted-log-xy-transform :base (log-xy-transform-base tr)))

;;; ============================================================
;;; InvertedLogXYTransform — inverse of log-xy transform
;;; ============================================================

(defclass inverted-log-xy-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor inverted-log-xy-transform-base
         :type double-float
         :documentation "Base of the logarithm."))
  (:documentation "Inverse logarithmic transform on BOTH X and Y axes."))

(defmethod transform-point ((tr inverted-log-xy-transform) point)
  "Transform a point using exponentiation on BOTH X and Y coordinates."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (inverted-log-xy-transform-base tr))
         (result (make-array 2 :element-type 'double-float)))
    (setf (aref result 0) (expt base x))
    (setf (aref result 1) (expt base y))
    result))

(defmethod transform-path ((tr inverted-log-xy-transform) path)
  "Transform all vertices in PATH by this inverted log-XY transform."
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

(defmethod invert ((tr inverted-log-xy-transform))
  "Return the inverse transform (LogXYTransform)."
  (make-instance 'log-xy-transform :base (inverted-log-xy-transform-base tr)))

;;; ============================================================
;;; InvertedLogTransform — inverse of logarithmic transform
;;; ============================================================

(defclass inverted-log-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor inverted-log-transform-base
         :type double-float
         :documentation "Base of the logarithm."))
  (:documentation "Inverse logarithmic transform: forward(y) = base^y.
Ported from matplotlib.scale.InvertedLogTransform."))

(defmethod transform-point ((tr inverted-log-transform) point)
  "Transform a point using exponentiation."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (inverted-log-transform-base tr))
         (result (make-array 2 :element-type 'double-float)))
    ;; Transform x coordinate: base^x
    (setf (aref result 0) (expt base x))
    ;; Y coordinate passes through unchanged
    (setf (aref result 1) y)
    result))

(defmethod invert ((tr inverted-log-transform))
  "Return the inverse transform (LogTransform)."
  (make-instance 'log-transform :base (inverted-log-transform-base tr)))

;;; ============================================================
;;; SymmetricalLogTransform — symmetrical log transform
;;; ============================================================

(defclass symlog-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor symlog-transform-base
         :type double-float
         :documentation "Base of the logarithm.")
   (linthresh :initarg :linthresh
              :initform 2.0d0
              :accessor symlog-transform-linthresh
              :type double-float
              :documentation "Linear threshold around zero.")
   (linscale :initarg :linscale
             :initform 1.0d0
             :accessor symlog-transform-linscale
             :type double-float
             :documentation "Scale factor for linear region."))
  (:documentation "Symmetrical logarithmic transform: linear near zero, log elsewhere.
Ported from matplotlib.scale.SymmetricalLogTransform."))

(defmethod initialize-instance :after ((tr symlog-transform) &key base linthresh linscale)
  (declare (ignore base linthresh linscale))
  (when (<= (symlog-transform-base tr) 1.0d0)
    (error "'base' must be larger than 1"))
  (when (<= (symlog-transform-linthresh tr) 0.0d0)
    (error "'linthresh' must be positive"))
  (when (<= (symlog-transform-linscale tr) 0.0d0)
    (error "'linscale' must be positive")))

(defmethod transform-point ((tr symlog-transform) point)
  "Transform a point using symmetrical log."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (symlog-transform-base tr))
         (linthresh (symlog-transform-linthresh tr))
         (linscale (symlog-transform-linscale tr))
         (linscale-adj (/ linscale (- 1.0d0 (/ 1.0d0 base))))
         (log-base (log base))
         (abs-x (abs x))
         (result (make-array 2 :element-type 'double-float)))
    ;; Transform x coordinate
    (setf (aref result 0)
          (if (<= abs-x linthresh)
              ;; Linear region
              (* x linscale-adj)
              ;; Log region
              (* (signum x) linthresh
                 (+ linscale-adj
                    (- (/ (log linthresh) log-base))
                    (/ (log abs-x) log-base)))))
    ;; Y coordinate passes through unchanged
    (setf (aref result 1) y)
    result))

(defmethod invert ((tr symlog-transform))
  "Return the inverse transform (InvertedSymLogTransform)."
  (make-instance 'inverted-symlog-transform
                 :base (symlog-transform-base tr)
                 :linthresh (symlog-transform-linthresh tr)
                 :linscale (symlog-transform-linscale tr)))

;;; ============================================================
;;; InvertedSymmetricalLogTransform — inverse of symlog
;;; ============================================================

(defclass inverted-symlog-transform (transform)
  ((base :initarg :base
         :initform 10.0d0
         :accessor inverted-symlog-transform-base
         :type double-float)
   (linthresh :initarg :linthresh
              :initform 2.0d0
              :accessor inverted-symlog-transform-linthresh
              :type double-float)
   (linscale :initarg :linscale
             :initform 1.0d0
             :accessor inverted-symlog-transform-linscale
             :type double-float))
  (:documentation "Inverse of symmetrical logarithmic transform.
Ported from matplotlib.scale.InvertedSymmetricalLogTransform."))

(defmethod transform-point ((tr inverted-symlog-transform) point)
  "Transform a point using inverse symmetrical log."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (base (inverted-symlog-transform-base tr))
         (linthresh (inverted-symlog-transform-linthresh tr))
         (linscale (inverted-symlog-transform-linscale tr))
         (linscale-adj (/ linscale (- 1.0d0 (/ 1.0d0 base))))
         ;; Compute invlinthresh: the transformed value of linthresh
         (invlinthresh (* linthresh linscale-adj))
         (abs-x (abs x))
         (result (make-array 2 :element-type 'double-float)))
    ;; Transform x coordinate
    (setf (aref result 0)
          (if (<= abs-x invlinthresh)
              ;; Linear region
              (/ x linscale-adj)
              ;; Log region
              (* (signum x) linthresh
                 (exp (* (- (/ abs-x linthresh) linscale-adj)
                         (log base))))))
    ;; Y coordinate passes through unchanged
    (setf (aref result 1) y)
    result))

(defmethod invert ((tr inverted-symlog-transform))
  "Return the inverse transform (SymLogTransform)."
  (make-instance 'symlog-transform
                 :base (inverted-symlog-transform-base tr)
                 :linthresh (inverted-symlog-transform-linthresh tr)
                 :linscale (inverted-symlog-transform-linscale tr)))

;;; ============================================================
;;; LogitTransform — logit transform
;;; ============================================================

(defclass logit-transform (transform)
  ((nonpositive :initarg :nonpositive
                :initform :mask
                :accessor logit-transform-nonpositive
                :documentation "How to handle values outside (0,1): :clip or :mask."))
  (:documentation "Logit transform: forward(x) = log10(x / (1-x)).
Ported from matplotlib.scale.LogitTransform."))

(defmethod transform-point ((tr logit-transform) point)
  "Transform a point using logit."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (clip-p (eq (logit-transform-nonpositive tr) :clip))
         (result (make-array 2 :element-type 'double-float)))
    ;; Transform x coordinate: log10(x / (1-x))
    (setf (aref result 0)
          (cond
            ((<= x 0.0d0)
             (if clip-p -1000.0d0 (/ 0.0d0 0.0d0))) ; NaN for mask
            ((>= x 1.0d0)
             (if clip-p 1000.0d0 (/ 0.0d0 0.0d0)))  ; NaN for mask
            (t
             (log (/ x (- 1.0d0 x)) 10.0d0))))
    ;; Y coordinate passes through unchanged
    (setf (aref result 1) y)
    result))

(defmethod invert ((tr logit-transform))
  "Return the inverse transform (LogisticTransform)."
  (make-instance 'logistic-transform
                 :nonpositive (logit-transform-nonpositive tr)))

;;; ============================================================
;;; LogisticTransform — inverse of logit (logistic function)
;;; ============================================================

(defclass logistic-transform (transform)
  ((nonpositive :initarg :nonpositive
                :initform :mask
                :accessor logistic-transform-nonpositive))
  (:documentation "Logistic transform: forward(x) = 1 / (1 + 10^(-x)).
Ported from matplotlib.scale.LogisticTransform."))

(defmethod transform-point ((tr logistic-transform) point)
  "Transform a point using logistic function."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (result (make-array 2 :element-type 'double-float)))
    ;; Transform x coordinate: 1 / (1 + 10^(-x))
    (setf (aref result 0) (/ 1.0d0 (+ 1.0d0 (expt 10.0d0 (- x)))))
    ;; Y coordinate passes through unchanged
    (setf (aref result 1) y)
    result))

(defmethod invert ((tr logistic-transform))
  "Return the inverse transform (LogitTransform)."
  (make-instance 'logit-transform
                 :nonpositive (logistic-transform-nonpositive tr)))

;;; ============================================================
;;; FuncTransform — user-provided function transform
;;; ============================================================

(defclass func-transform (transform)
  ((forward-fn :initarg :forward
               :accessor func-transform-forward
               :documentation "Forward transformation function.")
   (inverse-fn :initarg :inverse
               :accessor func-transform-inverse
               :documentation "Inverse transformation function."))
  (:documentation "Transform using arbitrary user-provided functions.
Ported from matplotlib.scale.FuncTransform."))

(defmethod initialize-instance :after ((tr func-transform) &key forward inverse)
  (unless (and (functionp forward) (functionp inverse))
    (error "Both forward and inverse must be functions")))

(defmethod transform-point ((tr func-transform) point)
  "Transform a point using the forward function."
  (let* ((x (float (if (listp point) (first point) (elt point 0)) 1.0d0))
         (y (float (if (listp point) (second point) (elt point 1)) 1.0d0))
         (forward-fn (func-transform-forward tr))
         (result (make-array 2 :element-type 'double-float)))
    ;; Apply forward function to x coordinate
    (setf (aref result 0) (float (funcall forward-fn x) 1.0d0))
    ;; Y coordinate passes through unchanged
    (setf (aref result 1) y)
    result))

(defmethod invert ((tr func-transform))
  "Return the inverse transform (swapping forward and inverse functions)."
  (make-instance 'func-transform
                 :forward (func-transform-inverse tr)
                 :inverse (func-transform-forward tr)))
