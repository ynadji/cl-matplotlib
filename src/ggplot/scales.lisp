;;;; scales.lisp — scale protocol and continuous positional scales
;;;;
;;;; PR0 scope: continuous x/y scales with plotnine-parity expansion and
;;;; extended-Wilkinson breaks. Discrete and non-positional scales follow.

(in-package #:ggplot)

;;; ============================================================
;;; Scale protocol
;;; ============================================================

(defgeneric scale-train (scale values)
  (:documentation "Accumulate range (continuous) or levels (discrete) from VALUES."))

(defgeneric scale-transform (scale values)
  (:documentation "Apply the scale's forward transformation to VALUES.")
  (:method ((scale scale) values) values))

(defgeneric scale-map (scale values)
  (:documentation "Map data values to aesthetic values.")
  (:method ((scale scale) values) values))

(defgeneric scale-limits (scale)
  (:documentation "Effective (min max) limits: user limits or trained range."))

(defgeneric scale-breaks (scale)
  (:documentation "List of break (tick) positions within the limits."))

(defgeneric scale-break-labels (scale breaks)
  (:documentation "List of label strings for BREAKS."))

(defgeneric scale-expanded-range (scale)
  (:documentation "(min max) limits after applying the scale's expansion."))

;;; ============================================================
;;; Continuous scales
;;; ============================================================

(defclass scale-continuous (scale)
  ((trans :initarg :trans :initform :identity :reader scale-trans)
   (range-min :initform nil :accessor scale-range-min)
   (range-max :initform nil :accessor scale-range-max))
  (:documentation "Continuous scale. Default expansion is plotnine's
(mult 0.05, add 0) on each side."))

(defmethod scale-train ((scale scale-continuous) values)
  (multiple-value-bind (lo hi) (finite-range values)
    (when lo
      (when (or (null (scale-range-min scale)) (< lo (scale-range-min scale)))
        (setf (scale-range-min scale) lo))
      (when (or (null (scale-range-max scale)) (> hi (scale-range-max scale)))
        (setf (scale-range-max scale) hi)))))

(defmethod scale-limits ((scale scale-continuous))
  (let ((user (scale-user-limits scale)))
    (list (or (and user (first user)) (scale-range-min scale) 0.0d0)
          (or (and user (second user)) (scale-range-max scale) 1.0d0))))

(defmethod scale-expanded-range ((scale scale-continuous))
  (destructuring-bind (lo hi) (scale-limits scale)
    (let* ((expand (or (scale-user-expand scale) '(0.05d0 0.0d0)))
           (mult (first expand))
           (add (or (second expand) 0.0d0))
           (range (- hi lo))
           ;; Degenerate range: plotnine expands by 0.5 units either side
           (range (if (zerop range) 1.0d0 range))
           (pad (+ (* mult range) add)))
      (list (- lo pad) (+ hi pad)))))

(defmethod scale-breaks ((scale scale-continuous))
  (let ((user (scale-user-breaks scale)))
    (if (not (eq user :auto))
        user
        (destructuring-bind (lo hi) (scale-limits scale)
          ;; Breaks are computed on the unexpanded limits (plotnine), then
          ;; the renderer keeps only those inside the expanded range.
          (extended-breaks lo hi 5)))))

(defun %decimals-needed (x &optional (max-decimals 10))
  "Smallest number of decimal places that represents X exactly enough."
  (loop for d from 0 to max-decimals
        for scale = (expt 10 d)
        when (< (abs (- x (/ (round (* x scale)) scale))) 1.0d-9)
          do (return d)
        finally (return max-decimals)))

(defun %format-break-set (breaks)
  "Format BREAKS the way mizani does: one shared decimal precision across
the whole set (so 10, 12.5 render as \"10.0\", \"12.5\", but 1, 2, 3 render
without decimal points)."
  (let ((decimals (reduce #'max breaks :key #'%decimals-needed
                                       :initial-value 0)))
    (mapcar (lambda (b)
              (if (zerop decimals)
                  (format nil "~D" (round b))
                  (format nil "~,VF" decimals b)))
            breaks)))

(defmethod scale-break-labels ((scale scale-continuous) breaks)
  (let ((user (scale-user-labels scale)))
    (cond ((not (eq user :auto)) user)
          ((null breaks) '())
          (t (%format-break-set breaks)))))

;;; ============================================================
;;; Constructors
;;; ============================================================

(defun scale-x-continuous (&rest args &key name breaks labels limits expand trans)
  (declare (ignore name breaks labels limits expand trans))
  (apply #'make-instance 'scale-continuous :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-continuous (&rest args &key name breaks labels limits expand trans)
  (declare (ignore name breaks labels limits expand trans))
  (apply #'make-instance 'scale-continuous :aesthetics '(:y :ymin :ymax :yend) args))

(defun xlim (min max)
  "Set x limits (shorthand for scale-x-continuous :limits)."
  (scale-x-continuous :limits (list (and min (float min 1.0d0))
                                    (and max (float max 1.0d0)))))

(defun ylim (min max)
  "Set y limits (shorthand for scale-y-continuous :limits)."
  (scale-y-continuous :limits (list (and min (float min 1.0d0))
                                    (and max (float max 1.0d0)))))

(defun lims (&key x y)
  "Set limits for several aesthetics at once: (lims :x '(0 10) :y '(0 1))."
  (remove nil (list (when x (apply #'xlim x))
                    (when y (apply #'ylim y)))))

;;; ============================================================
;;; Discrete scales
;;; ============================================================

(defclass scale-discrete (scale)
  ((values-seen :initform '() :accessor scale-values-seen)
   (drop :initarg :drop :initform t :reader scale-drop-p))
  (:documentation "Discrete scale: distinct values map to positions 1..n
(positional) or palette entries (non-positional). Default expansion is
plotnine's additive 0.6."))

(defmethod scale-train ((scale scale-discrete) values)
  (map nil (lambda (v)
             (pushnew v (scale-values-seen scale) :test #'equal))
       values))

(defun scale-levels (scale)
  "Sorted distinct values: numbers numerically, everything else by string."
  (let ((user (scale-user-limits scale)))
    (or user
        (let ((vals (scale-values-seen scale)))
          (if (every #'realp vals)
              (sort (copy-list vals) #'<)
              (sort (copy-list vals) #'string<
                    :key (lambda (v) (princ-to-string v))))))))

(defun %level-position (scale value)
  (let ((pos (position value (scale-levels scale) :test #'equal)))
    (unless pos
      (error "Value ~S is not among the scale's levels ~S"
             value (scale-levels scale)))
    (1+ pos)))

(defmethod scale-limits ((scale scale-discrete))
  (let ((n (length (scale-levels scale))))
    (list 1.0d0 (float (max n 1) 1.0d0))))

(defmethod scale-expanded-range ((scale scale-discrete))
  (destructuring-bind (lo hi) (scale-limits scale)
    (let* ((expand (or (scale-user-expand scale) '(0.0d0 0.6d0)))
           (mult (first expand))
           (add (or (second expand) 0.6d0))
           (range (max (- hi lo) 1.0d0))
           (pad (+ (* mult range) add)))
      (list (- lo pad) (+ hi pad)))))

(defmethod scale-map ((scale scale-discrete) values)
  (map 'simple-vector (lambda (v) (float (%level-position scale v) 1.0d0))
       values))

(defmethod scale-breaks ((scale scale-discrete))
  (let ((user (scale-user-breaks scale)))
    (if (not (eq user :auto))
        user
        (loop for i from 1 to (length (scale-levels scale))
              collect (float i 1.0d0)))))

(defmethod scale-break-labels ((scale scale-discrete) breaks)
  (declare (ignore breaks))
  (let ((user (scale-user-labels scale)))
    (if (not (eq user :auto))
        user
        (mapcar #'princ-to-string (scale-levels scale)))))

(defun scale-x-discrete (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-discrete :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-discrete (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-discrete :aesthetics '(:y :ymin :ymax :yend) args))

;;; ============================================================
;;; Non-positional discrete scales (color/fill/shape)
;;; ============================================================

(defclass scale-discrete-palette (scale-discrete)
  ((palette :initarg :palette :reader scale-palette
            :documentation "Function n -> list of n aesthetic values."))
  (:documentation "Discrete scale mapping levels through a palette."))

(defmethod scale-map ((scale scale-discrete-palette) values)
  (let* ((levels (scale-levels scale))
         (mapped (funcall (scale-palette scale) (length levels))))
    (unless (>= (length mapped) (length levels))
      (error "Palette supplied ~D values for ~D levels"
             (length mapped) (length levels)))
    (map 'simple-vector
         (lambda (v) (elt mapped (1- (%level-position scale v))))
         values)))

(defun scale-color-discrete (&rest args &key name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (apply #'make-instance 'scale-discrete-palette
         :aesthetics '(:color) :palette #'hls-palette args))

(defun scale-fill-discrete (&rest args &key name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (apply #'make-instance 'scale-discrete-palette
         :aesthetics '(:fill) :palette #'hls-palette args))

(defun %manual-palette (values)
  (lambda (n)
    (unless (>= (length values) n)
      (error "scale-*-manual: ~D values supplied but ~D levels present"
             (length values) n))
    (coerce values 'list)))

(defun scale-color-manual (&rest args &key values name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (eq k :values) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:color) :palette (%manual-palette values) rest)))

(defun scale-fill-manual (&rest args &key values name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (eq k :values) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:fill) :palette (%manual-palette values) rest)))

(defparameter *default-shapes* '(:o :^ :s :d :v :star :p :x)
  "plotnine's default shape order, as backend marker keywords.")

(defun scale-shape-manual (&rest args &key values name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (eq k :values) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:shape)
           :palette (%manual-palette (or values *default-shapes*)) rest)))

;;; ============================================================
;;; Continuous size / alpha scales
;;; ============================================================

(defclass scale-size-obj (scale-continuous)
  ((range :initarg :range :initform '(1.0d0 6.0d0) :reader scale-size-range))
  (:documentation "Continuous size scale using plotnine's area palette:
sizes proportional to sqrt of the rescaled value."))

(defmethod scale-map ((scale scale-size-obj) values)
  (destructuring-bind (lo hi) (scale-limits scale)
    (destructuring-bind (rmin rmax) (scale-size-range scale)
      (let ((span (max (- hi lo) 1.0d-12)))
        (map 'simple-vector
             (lambda (v)
               (let ((u (/ (- (float v 1.0d0) lo) span)))
                 (sqrt (+ (* u (- (* rmax rmax) (* rmin rmin)))
                          (* rmin rmin)))))
             values)))))

(defun scale-size (&rest args &key range name breaks labels limits guide)
  (declare (ignore range name breaks labels limits guide))
  (apply #'make-instance 'scale-size-obj :aesthetics '(:size) args))

(defclass scale-alpha-obj (scale-continuous)
  ((range :initarg :range :initform '(0.1d0 1.0d0) :reader scale-alpha-range)))

(defmethod scale-map ((scale scale-alpha-obj) values)
  (destructuring-bind (lo hi) (scale-limits scale)
    (destructuring-bind (rmin rmax) (scale-alpha-range scale)
      (let ((span (max (- hi lo) 1.0d-12)))
        (map 'simple-vector
             (lambda (v)
               (+ rmin (* (/ (- (float v 1.0d0) lo) span) (- rmax rmin))))
             values)))))

(defun scale-alpha (&rest args &key range name breaks labels limits guide)
  (declare (ignore range name breaks labels limits guide))
  (apply #'make-instance 'scale-alpha-obj :aesthetics '(:alpha) args))

;;; ============================================================
;;; Default scale inference
;;; ============================================================

(defun find-default-scale (aesthetic sample-values)
  "Create a default scale for AESTHETIC based on SAMPLE-VALUES' types."
  (let ((discrete (some #'discrete-value-p sample-values)))
    (case aesthetic
      ((:x :xmin :xmax :xend)
       (if discrete (scale-x-discrete) (scale-x-continuous)))
      ((:y :ymin :ymax :yend)
       (if discrete (scale-y-discrete) (scale-y-continuous)))
      (:color
       (if discrete
           (scale-color-discrete)
           (error "Continuous color scales arrive with the gradient slice")))
      (:fill
       (if discrete
           (scale-fill-discrete)
           (error "Continuous fill scales arrive with the gradient slice")))
      (:shape (scale-shape-manual))
      (:size
       (if discrete
           (error "Discrete size scales are not supported (use a manual scale)")
           (scale-size)))
      (:alpha
       (if discrete
           (error "Discrete alpha scales are not supported (use a manual scale)")
           (scale-alpha)))
      (t nil))))
