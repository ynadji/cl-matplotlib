;;;; positions.lisp — position adjustments

(in-package #:ggplot)

(defclass position-identity-obj (ggposition) ())
(defclass position-stack-obj (ggposition) ())
(defclass position-fill-obj (position-stack-obj) ())
(defclass position-dodge-obj (ggposition)
  ((width :initarg :width :initform nil :reader position-dodge-width)))
(defclass position-jitter-obj (ggposition)
  ((width :initarg :width :initform nil :reader position-jitter-w)
   (height :initarg :height :initform nil :reader position-jitter-h)))
(defclass position-nudge-obj (ggposition)
  ((x :initarg :x :initform 0.0d0 :reader position-nudge-x)
   (y :initarg :y :initform 0.0d0 :reader position-nudge-y)))

(defgeneric position-adjust (position data &key &allow-other-keys)
  (:documentation "Apply a position adjustment to a panel gtable.")
  (:method ((position position-identity-obj) data &key) data))

(defun %rows-by-x (data)
  "Alist of (x-value . list-of-row-indices), insertion ordered."
  (let ((x (gtable-column data :x))
        (buckets '()))
    (dotimes (i (length x))
      (let ((entry (assoc (svref x i) buckets :test #'equal)))
        (if entry
            (push i (cdr entry))
            (push (cons (svref x i) (list i)) buckets))))
    (mapcar (lambda (b) (cons (car b) (nreverse (cdr b))))
            (nreverse buckets))))

(defmethod position-adjust ((position position-stack-obj) data &key)
  "Stack ymin/ymax runs per x. Rows later in the data stack UNDER earlier
ones (ggplot2 stacks in reverse group order so the first level ends on top)."
  (let ((ymin (copy-seq (gtable-column data :ymin)))
        (ymax (copy-seq (gtable-column data :ymax))))
    (unless (and ymin ymax)
      (error "position-stack requires ymin/ymax geometry"))
    (loop for (nil . indices) in (%rows-by-x data) do
      (let ((cum 0.0d0))
        (dolist (i (reverse indices))
          (let ((h (- (svref ymax i) (svref ymin i))))
            (setf (svref ymin i) cum
                  (svref ymax i) (+ cum h)
                  cum (+ cum h))))))
    (when (typep position 'position-fill-obj)
      (loop for (nil . indices) in (%rows-by-x data) do
        (let ((total (reduce #'max indices
                             :key (lambda (i) (svref ymax i))
                             :initial-value 1.0d-12)))
          (dolist (i indices)
            (setf (svref ymin i) (/ (svref ymin i) total)
                  (svref ymax i) (/ (svref ymax i) total))))))
    (gtable-set-column (gtable-set-column data :ymin ymin) :ymax ymax)))

(defmethod position-adjust ((position position-dodge-obj) data &key)
  "Place group members side by side within each x slot."
  (let ((xmin (copy-seq (gtable-column data :xmin)))
        (xmax (copy-seq (gtable-column data :xmax))))
    (unless (and xmin xmax)
      (error "position-dodge requires xmin/xmax geometry"))
    (loop for (nil . indices) in (%rows-by-x data) do
      (let* ((n (length indices))
             (slot-min (reduce #'min indices :key (lambda (i) (svref xmin i))))
             (slot-max (reduce #'max indices :key (lambda (i) (svref xmax i))))
             (width (or (position-dodge-width position) (- slot-max slot-min)))
             (each (/ width n))
             (start (- (/ (+ slot-min slot-max) 2.0d0) (/ width 2.0d0))))
        (loop for i in indices
              for k from 0
              do (setf (svref xmin i) (+ start (* k each))
                       (svref xmax i) (+ start (* (1+ k) each))))))
    (gtable-set-column (gtable-set-column data :xmin xmin) :xmax xmax)))

(defvar *ggrandom-state* (make-random-state t)
  "Random state for position-jitter. Rebind (or reseed) for reproducible
jitter; jittered SSIM examples are allowlisted regardless since CL and
numpy RNGs can't produce identical streams.")

(defmethod position-adjust ((position position-jitter-obj) data &key)
  (let* ((x (copy-seq (gtable-column data :x)))
         (y (copy-seq (gtable-column data :y)))
         ;; plotnine default: 40% of the data resolution in each direction
         (w (or (position-jitter-w position) 0.4d0))
         (h (or (position-jitter-h position) 0.4d0)))
    (dotimes (i (length x))
      (setf (svref x i)
            (+ (svref x i) (- (random (* 2.0d0 w) *ggrandom-state*) w)))
      (when y
        (setf (svref y i)
              (+ (svref y i) (- (random (* 2.0d0 h) *ggrandom-state*) h)))))
    (let ((result (gtable-set-column data :x x)))
      (if y (gtable-set-column result :y y) result))))

(defmethod position-adjust ((position position-nudge-obj) data &key)
  (let ((x (gtable-column data :x))
        (y (gtable-column data :y))
        (dx (position-nudge-x position))
        (dy (position-nudge-y position))
        (result data))
    (when (and x (/= dx 0.0d0))
      (setf result (gtable-set-column
                    result :x (map 'simple-vector
                                   (lambda (v) (+ v dx)) x))))
    (when (and y (/= dy 0.0d0))
      (setf result (gtable-set-column
                    result :y (map 'simple-vector
                                   (lambda (v) (+ v dy)) y))))
    result))

(defun resolve-position (designator)
  (etypecase designator
    (ggposition designator)
    (keyword (ecase designator
               (:identity (make-instance 'position-identity-obj))
               (:stack (make-instance 'position-stack-obj))
               (:fill (make-instance 'position-fill-obj))
               (:dodge (make-instance 'position-dodge-obj))
               (:jitter (make-instance 'position-jitter-obj))
               (:nudge (make-instance 'position-nudge-obj))))))

(defun position-identity () (make-instance 'position-identity-obj))
(defun position-stack () (make-instance 'position-stack-obj))
(defun position-fill () (make-instance 'position-fill-obj))
(defun position-dodge (&key width)
  (make-instance 'position-dodge-obj :width width))
(defun position-jitter (&key width height)
  (make-instance 'position-jitter-obj :width width :height height))
(defun position-nudge (&key (x 0.0d0) (y 0.0d0))
  (make-instance 'position-nudge-obj :x (float x 1.0d0) :y (float y 1.0d0)))
