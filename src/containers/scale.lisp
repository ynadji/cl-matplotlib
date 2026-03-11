;;;; scale.lisp — Scale classes for logarithmic and other non-linear axis scales
;;;; Ported from matplotlib's scale.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; ScaleBase — base class for all scales
;;; ============================================================

(defclass scale-base ()
  ((scale-name :initarg :name
               :initform "linear"
               :accessor scale-name
               :type string
               :documentation "Name of this scale type.")
   (scale-axis :initarg :axis
               :initform nil
               :accessor scale-axis
               :documentation "The axis this scale is attached to."))
  (:documentation "Base class for all scales.
Scales are separable transformations working on a single dimension.
Ported from matplotlib.scale.ScaleBase."))

(defgeneric scale-get-transform (scale)
  (:documentation "Return the Transform object associated with this scale."))

(defgeneric scale-set-default-locators-and-formatters (scale axis)
  (:documentation "Set default locators and formatters for AXIS using this scale."))

(defgeneric scale-limit-range-for-scale (scale vmin vmax minpos)
  (:documentation "Return (values vmin vmax) restricted to the domain supported by this scale.
MINPOS is the minimum positive value in the data (used by log scales)."))

(defmethod scale-limit-range-for-scale ((scale scale-base) vmin vmax minpos)
  "Default: no restriction."
  (declare (ignore minpos))
  (values vmin vmax))

;;; ============================================================
;;; LinearScale — default linear scale (identity)
;;; ============================================================

(defclass linear-scale (scale-base)
  ()
  (:default-initargs :name "linear")
  (:documentation "The default linear scale (identity transform).
Ported from matplotlib.scale.LinearScale."))

(defmethod scale-get-transform ((scale linear-scale))
  "Return the identity transform."
  (mpl.primitives:make-identity-transform))

(defmethod scale-set-default-locators-and-formatters ((scale linear-scale) axis)
  "Set AutoLocator and ScalarFormatter for linear scale."
  (axis-set-major-locator axis (make-instance 'auto-locator))
  (axis-set-major-formatter axis (make-instance 'scalar-formatter))
  (axis-set-minor-formatter axis (make-instance 'null-formatter))
  (axis-set-minor-locator axis (make-instance 'null-locator)))

;;; ============================================================
;;; LogScale — logarithmic scale
;;; ============================================================

(defclass log-scale (scale-base)
  ((base :initarg :base
         :initform 10.0d0
         :accessor log-scale-base
         :type double-float
         :documentation "Base of the logarithm.")
   (subs :initarg :subs
         :initform nil
         :accessor log-scale-subs
         :documentation "Subdivisions for minor ticks (nil = default).")
   (nonpositive :initarg :nonpositive
                :initform :clip
                :accessor log-scale-nonpositive
                :documentation "How to handle non-positive values: :clip or :mask.")
   (transform-obj :initform nil
                  :accessor log-scale-transform
                  :documentation "Cached LogTransform instance."))
  (:default-initargs :name "log")
  (:documentation "Logarithmic scale. Care is taken to only plot positive values.
Ported from matplotlib.scale.LogScale."))

(defmethod initialize-instance :after ((scale log-scale) &key base subs nonpositive)
  (declare (ignore subs nonpositive))
  (setf (log-scale-transform scale)
        (make-instance 'mpl.primitives:log-transform
                       :base (or base 10.0d0)
                       :nonpositive (or nonpositive :clip))))

(defmethod scale-get-transform ((scale log-scale))
  "Return the LogTransform associated with this scale."
  (log-scale-transform scale))

(defmethod scale-set-default-locators-and-formatters ((scale log-scale) axis)
  "Set LogLocator and LogFormatter for log scale."
  (let ((base (log-scale-base scale))
        (subs (or (log-scale-subs scale) '(1.0d0))))
    (axis-set-major-locator axis (make-instance 'log-locator :base base :subs subs))
    (axis-set-major-formatter axis (make-instance 'log-formatter :base base))
    (axis-set-minor-locator axis (make-instance 'log-locator :base base :subs '(2.0d0 3.0d0 4.0d0 5.0d0 6.0d0 7.0d0 8.0d0 9.0d0)))
    (axis-set-minor-formatter axis (make-instance 'log-formatter
                                                   :base base
                                                   :label-only-base t))))

(defmethod scale-limit-range-for-scale ((scale log-scale) vmin vmax minpos)
  "Limit the domain to positive values."
  (let ((safe-minpos (if (and (numberp minpos) (> minpos 0.0d0))
                         minpos
                         1.0d-300)))
    (values (if (<= vmin 0.0d0) safe-minpos vmin)
            (if (<= vmax 0.0d0) safe-minpos vmax))))

;;; ============================================================
;;; SymmetricalLogScale — symmetrical log scale
;;; ============================================================

(defclass symlog-scale (scale-base)
  ((base :initarg :base
         :initform 10.0d0
         :accessor symlog-scale-base
         :type double-float)
   (linthresh :initarg :linthresh
              :initform 2.0d0
              :accessor symlog-scale-linthresh
              :type double-float
              :documentation "Linear threshold around zero.")
   (linscale :initarg :linscale
             :initform 1.0d0
             :accessor symlog-scale-linscale
             :type double-float
             :documentation "Scale factor for linear region.")
   (subs :initarg :subs
         :initform nil
         :accessor symlog-scale-subs)
   (transform-obj :initform nil
                  :accessor symlog-scale-transform))
  (:default-initargs :name "symlog")
  (:documentation "Symmetrical logarithmic scale: logarithmic in both positive and negative directions.
Linear around zero to avoid infinity.
Ported from matplotlib.scale.SymmetricalLogScale."))

(defmethod initialize-instance :after ((scale symlog-scale) &key base linthresh linscale subs)
  (declare (ignore subs))
  (setf (symlog-scale-transform scale)
        (make-instance 'mpl.primitives:symlog-transform
                       :base (or base 10.0d0)
                       :linthresh (or linthresh 2.0d0)
                       :linscale (or linscale 1.0d0))))

(defmethod scale-get-transform ((scale symlog-scale))
  "Return the SymLogTransform associated with this scale."
  (symlog-scale-transform scale))

(defmethod scale-set-default-locators-and-formatters ((scale symlog-scale) axis)
  "Set SymmetricalLogLocator and LogFormatter for symlog scale."
  ;; For now, use AutoLocator (SymmetricalLogLocator not yet implemented)
  (axis-set-major-locator axis (make-instance 'auto-locator))
  (axis-set-major-formatter axis (make-instance 'log-formatter
                                                 :base (symlog-scale-base scale)))
  (axis-set-minor-locator axis (make-instance 'null-locator))
  (axis-set-minor-formatter axis (make-instance 'null-formatter)))

;;; ============================================================
;;; LogitScale — logit scale for data between 0 and 1
;;; ============================================================

(defclass logit-scale (scale-base)
  ((nonpositive :initarg :nonpositive
                :initform :mask
                :accessor logit-scale-nonpositive)
   (transform-obj :initform nil
                  :accessor logit-scale-transform))
  (:default-initargs :name "logit")
  (:documentation "Logit scale for data between zero and one (both excluded).
Similar to log scale near 0 and 1, almost linear around 0.5.
Ported from matplotlib.scale.LogitScale."))

(defmethod initialize-instance :after ((scale logit-scale) &key nonpositive)
  (setf (logit-scale-transform scale)
        (make-instance 'mpl.primitives:logit-transform
                       :nonpositive (or nonpositive :mask))))

(defmethod scale-get-transform ((scale logit-scale))
  "Return the LogitTransform associated with this scale."
  (logit-scale-transform scale))

(defmethod scale-set-default-locators-and-formatters ((scale logit-scale) axis)
  "Set AutoLocator and ScalarFormatter for logit scale."
  ;; For now, use AutoLocator (LogitLocator not yet implemented)
  (axis-set-major-locator axis (make-instance 'auto-locator))
  (axis-set-major-formatter axis (make-instance 'scalar-formatter))
  (axis-set-minor-locator axis (make-instance 'null-locator))
  (axis-set-minor-formatter axis (make-instance 'null-formatter)))

(defmethod scale-limit-range-for-scale ((scale logit-scale) vmin vmax minpos)
  "Limit the domain to values between 0 and 1 (excluded)."
  (let ((safe-minpos (if (and (numberp minpos) (> minpos 0.0d0))
                         minpos
                         1.0d-7)))
    (values (if (<= vmin 0.0d0) safe-minpos vmin)
            (if (>= vmax 1.0d0) (- 1.0d0 safe-minpos) vmax))))

;;; ============================================================
;;; FuncScale — user-provided function scale
;;; ============================================================

(defclass func-scale (scale-base)
  ((functions :initarg :functions
              :accessor func-scale-functions
              :documentation "Two-tuple of (forward inverse) functions.")
   (transform-obj :initform nil
                  :accessor func-scale-transform))
  (:default-initargs :name "function")
  (:documentation "Arbitrary scale with user-supplied forward and inverse functions.
Ported from matplotlib.scale.FuncScale."))

(defmethod initialize-instance :after ((scale func-scale) &key functions)
  (unless (and functions (= (length functions) 2))
    (error "FuncScale requires a two-tuple of (forward inverse) functions"))
  (let ((forward (first functions))
        (inverse (second functions)))
    (unless (and (functionp forward) (functionp inverse))
      (error "Both forward and inverse must be functions"))
    (setf (func-scale-transform scale)
          (make-instance 'mpl.primitives:func-transform
                         :forward forward
                         :inverse inverse))))

(defmethod scale-get-transform ((scale func-scale))
  "Return the FuncTransform associated with this scale."
  (func-scale-transform scale))

(defmethod scale-set-default-locators-and-formatters ((scale func-scale) axis)
  "Set AutoLocator and ScalarFormatter for function scale."
  (axis-set-major-locator axis (make-instance 'auto-locator))
  (axis-set-major-formatter axis (make-instance 'scalar-formatter))
  (axis-set-minor-locator axis (make-instance 'null-locator))
  (axis-set-minor-formatter axis (make-instance 'null-formatter)))

;;; ============================================================
;;; Scale factory function
;;; ============================================================

(defun make-scale (scale-name &rest args &key axis &allow-other-keys)
  "Create a scale instance from a scale name keyword.
SCALE-NAME can be :linear, :log, :symlog, :logit, or :function.
Additional keyword arguments are passed to the scale constructor."
  (declare (ignore axis))
  (let ((scale-class (case scale-name
                       (:linear 'linear-scale)
                       (:log 'log-scale)
                       (:symlog 'symlog-scale)
                       (:logit 'logit-scale)
                       (:function 'func-scale)
                       (t (error "Unknown scale type: ~A" scale-name)))))
    (apply #'make-instance scale-class args)))
