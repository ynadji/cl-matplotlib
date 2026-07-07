;;;; stats.lisp — statistical transformations
;;;;
;;;; Numeric behavior mirrors plotnine's stats (constants noted per stat)
;;;; so SSIM comparisons against plotnine references can pass.

(in-package #:ggplot)

;;; ============================================================
;;; Protocol
;;; ============================================================

(defclass stat-identity-obj (stat) ())
(defclass stat-count-obj (stat) ())
(defclass stat-bin-obj (stat)
  ((bins :initarg :bins :initform nil :reader stat-bin-bins)
   (binwidth :initarg :binwidth :initform nil :reader stat-bin-binwidth)
   (boundary :initarg :boundary :initform nil :reader stat-bin-boundary)))
(defclass stat-density-obj (stat)
  ((bw :initarg :bw :initform :nrd0 :reader stat-density-bw)
   (adjust :initarg :adjust :initform 1.0d0 :reader stat-density-adjust)
   (n :initarg :n :initform 1024 :reader stat-density-n)))
(defclass stat-boxplot-obj (stat)
  ((coef :initarg :coef :initform 1.5d0 :reader stat-boxplot-coef)))
(defclass stat-ydensity-obj (stat-density-obj) ())

(defgeneric stat-default-aes (stat)
  (:documentation "Plist of aesthetic -> after-stat default mappings.")
  (:method ((stat stat)) '()))

(defgeneric stat-compute-panel (stat data scales &key &allow-other-keys)
  (:documentation "Apply STAT to one panel's gtable, returning a new gtable.")
  (:method ((stat stat-identity-obj) data scales &key)
    (declare (ignore scales))
    data))

(defun resolve-stat (designator)
  (etypecase designator
    (stat designator)
    (keyword (ecase designator
               (:identity (make-instance 'stat-identity-obj))
               (:count (make-instance 'stat-count-obj))
               (:bin (make-instance 'stat-bin-obj))
               (:density (make-instance 'stat-density-obj))
               (:boxplot (make-instance 'stat-boxplot-obj))
               (:ydensity (make-instance 'stat-ydensity-obj))))))

(defun %carry-group-constants (source result)
  "Copy the (constant within a group) non-positional aesthetic columns of
SOURCE onto every row of RESULT."
  (let ((n (gtable-nrows result)))
    (dolist (aes '(:color :fill :shape :size :alpha :linetype :group))
      (let ((col (gtable-column source aes)))
        (when (and col (plusp (length col))
                   (null (gtable-column result aes)))
          (setf result
                (gtable-set-column result aes
                                   (make-array n :initial-element (svref col 0)))))))
    result))

(defun %map-stat-groups (data fn)
  "Split DATA by :group, apply FN to each sub-table, carry group constants,
rbind the results."
  (gtable-rbind
   (loop for (nil . sub) in (gtable-split data :group)
         for out = (funcall fn sub)
         when (and out (plusp (gtable-nrows out)))
           collect (%carry-group-constants sub out))))

;;; ============================================================
;;; Numeric helpers (quantiles, bandwidth, KDE)
;;; ============================================================

(defun %sorted-doubles (sequence)
  (sort (map 'vector (lambda (v) (float v 1.0d0)) sequence) #'<))

(defun %quantile-type7 (sorted q)
  "R/numpy default (type 7, linear interpolation) quantile of a sorted vector."
  (let* ((n (length sorted))
         (h (* (- n 1) (float q 1.0d0)))
         (lo (floor h))
         (hi (min (1+ lo) (1- n)))
         (frac (- h lo)))
    (+ (* (aref sorted lo) (- 1.0d0 frac))
       (* (aref sorted hi) frac))))

(defun %std-ddof1 (values)
  (let* ((n (length values))
         (mean (/ (reduce #'+ values) n))
         (ss (reduce #'+ values
                     :key (lambda (v) (expt (- (float v 1.0d0) mean) 2)))))
    (if (> n 1) (sqrt (/ ss (- n 1))) 0.0d0)))

(defun nrd0-bandwidth (values)
  "R's bw.nrd0 (plotnine's default density bandwidth):
0.9 * min(sd, IQR/1.349) * n^-0.2, guarded against zero."
  (let* ((sorted (%sorted-doubles values))
         (n (length sorted))
         (sd (%std-ddof1 sorted))
         (iqr-est (/ (- (%quantile-type7 sorted 0.75d0)
                        (%quantile-type7 sorted 0.25d0))
                     1.349d0))
         (low (min sd iqr-est)))
    (when (zerop low)
      (setf low (or (and (plusp iqr-est) iqr-est)
                    (and (plusp (abs (aref sorted 0))) (abs (aref sorted 0)))
                    1.0d0)))
    (* 0.9d0 low (expt (float n 1.0d0) -0.2d0))))

(defun %gaussian-kde (values grid bw)
  "Gaussian kernel density of VALUES evaluated at each point of GRID."
  (let* ((n (length values))
         (norm (/ 1.0d0 (* n bw (sqrt (* 2.0d0 pi))))))
    (map 'simple-vector
         (lambda (tv)
           (let ((sum 0.0d0))
             (map nil (lambda (xi)
                        (let ((u (/ (- (float tv 1.0d0) (float xi 1.0d0)) bw)))
                          (incf sum (exp (* -0.5d0 u u)))))
                  values)
             (* norm sum)))
         grid)))

(defun %linspace (lo hi n)
  (if (= n 1)
      (vector lo)
      (let ((step (/ (- hi lo) (- n 1))))
        (coerce (loop for i from 0 below n collect (+ lo (* i step)))
                'simple-vector))))

;;; ============================================================
;;; stat-count
;;; ============================================================

(defmethod stat-default-aes ((stat stat-count-obj))
  (list :y (after-stat :count)))

(defmethod stat-compute-panel ((stat stat-count-obj) data scales &key)
  (declare (ignore scales))
  (%map-stat-groups
   data
   (lambda (sub)
     (let ((x-col (gtable-column sub :x)))
       (unless x-col (error "stat-count requires an x aesthetic"))
       (let ((counts '()))
         (loop for i from 0 below (length x-col)
               for xv = (svref x-col i)
               for entry = (assoc xv counts :test #'equal)
               do (if entry (incf (cdr entry)) (push (cons xv 1) counts)))
         (setf counts (nreverse counts))
         (make-gtable
          :x (map 'vector #'car counts)
          :count (map 'vector (lambda (c) (float (cdr c) 1.0d0)) counts)))))))

;;; ============================================================
;;; stat-bin (plotnine: bins default Freedman-Diaconis, binwidth =
;;; range/(bins-1), boundary = binwidth/2, right-closed bins)
;;; ============================================================

(defmethod stat-default-aes ((stat stat-bin-obj))
  (list :y (after-stat :count)))

(defun %bin-breaks (lo hi bins binwidth boundary)
  (let* ((binwidth (or binwidth
                       (if (<= bins 1)
                           (- hi lo)
                           (/ (- hi lo) (- bins 1)))))
         (boundary (or boundary (/ binwidth 2.0d0)))
         (shift (ffloor (/ (- lo boundary) binwidth)))
         (origin (+ boundary (* shift binwidth)))
         (max-x (+ hi (* binwidth (- 1.0d0 double-float-epsilon)))))
    (coerce (loop for b = origin then (+ b binwidth)
                  while (< b max-x)
                  collect b)
            'simple-vector)))

(defun %freedman-diaconis-bins (sorted)
  (let* ((n (length sorted))
         (iqr (- (%quantile-type7 sorted 0.75d0)
                 (%quantile-type7 sorted 0.25d0)))
         (h (/ (* 2.0d0 iqr) (expt (float n 1.0d0) (/ 1.0d0 3.0d0)))))
    (if (zerop h)
        (ceiling (sqrt (float n 1.0d0)))
        (ceiling (/ (- (aref sorted (1- n)) (aref sorted 0)) h)))))

(defmethod stat-compute-panel ((stat stat-bin-obj) data scales &key)
  (declare (ignore scales))
  (%map-stat-groups
   data
   (lambda (sub)
     (let ((x-col (gtable-column sub :x)))
       (unless x-col (error "stat-bin requires an x aesthetic"))
       (let* ((sorted (%sorted-doubles x-col))
              (lo (aref sorted 0))
              (hi (aref sorted (1- (length sorted))))
              (bins (or (stat-bin-bins stat) (%freedman-diaconis-bins sorted)))
              (breaks (%bin-breaks lo hi bins (stat-bin-binwidth stat)
                                   (stat-bin-boundary stat)))
              (nbins (1- (length breaks)))
              (counts (make-array nbins :initial-element 0)))
         ;; right-closed bins (plotnine closed="right"): (lo, hi]
         (map nil (lambda (v)
                    (let ((v (float v 1.0d0)))
                      (loop for b from 0 below nbins
                            when (or (and (zerop b) (<= (aref breaks 0) v (aref breaks 1)))
                                     (and (plusp b)
                                          (< (aref breaks b) v)
                                          (<= v (aref breaks (1+ b)))))
                              do (incf (aref counts b)) (return))))
              x-col)
         (let* ((total (max 1 (reduce #'+ counts)))
                (centers (loop for b from 0 below nbins
                               collect (/ (+ (aref breaks b) (aref breaks (1+ b))) 2.0d0)))
                (widths (loop for b from 0 below nbins
                              collect (- (aref breaks (1+ b)) (aref breaks b)))))
           (make-gtable
            :x (coerce centers 'vector)
            :count (map 'vector (lambda (c) (float c 1.0d0)) counts)
            :width (coerce widths 'vector)
            :density (map 'vector
                          (lambda (c w) (/ (float c 1.0d0) (* total w)))
                          counts widths))))))))

;;; ============================================================
;;; stat-density (plotnine: gaussian kernel, bw nrd0, n=1024 grid over
;;; the data range)
;;; ============================================================

(defmethod stat-default-aes ((stat stat-density-obj))
  (list :y (after-stat :density)))

(defun %compute-density-table (values n-grid bw-spec adjust &key range)
  (let* ((sorted (%sorted-doubles values))
         (count (length sorted)))
    (when (< count 2)
      (return-from %compute-density-table nil))
    (let* ((bw (* adjust (if (eq bw-spec :nrd0)
                             (nrd0-bandwidth sorted)
                             (float bw-spec 1.0d0))))
           (lo (if range (first range) (aref sorted 0)))
           (hi (if range (second range) (aref sorted (1- count))))
           (grid (%linspace lo hi n-grid))
           (density (%gaussian-kde sorted grid bw))
           (dmax (reduce #'max density)))
      (make-gtable
       :x grid
       :density density
       :scaled (map 'vector (lambda (d) (/ d (max dmax 1.0d-300))) density)
       :count (map 'vector (lambda (d) (* d count)) density)))))

(defmethod stat-compute-panel ((stat stat-density-obj) data scales &key)
  (declare (ignore scales))
  (%map-stat-groups
   data
   (lambda (sub)
     (let ((x-col (gtable-column sub :x)))
       (unless x-col (error "stat-density requires an x aesthetic"))
       (%compute-density-table x-col (stat-density-n stat)
                               (stat-density-bw stat)
                               (stat-density-adjust stat))))))

;;; ============================================================
;;; stat-boxplot (type-7 quantiles; whiskers at the most extreme data
;;; point within coef * IQR of the box, plotnine coef default 1.5)
;;; ============================================================

(defmethod stat-compute-panel ((stat stat-boxplot-obj) data scales &key)
  (declare (ignore scales))
  (%map-stat-groups
   data
   (lambda (sub)
     (let ((x-col (gtable-column sub :x))
           (y-col (gtable-column sub :y)))
       (unless (and x-col y-col)
         (error "stat-boxplot requires x and y aesthetics"))
       (let* ((sorted (%sorted-doubles y-col))
              (q1 (%quantile-type7 sorted 0.25d0))
              (q2 (%quantile-type7 sorted 0.5d0))
              (q3 (%quantile-type7 sorted 0.75d0))
              (iqr (- q3 q1))
              (lo-fence (- q1 (* (stat-boxplot-coef stat) iqr)))
              (hi-fence (+ q3 (* (stat-boxplot-coef stat) iqr)))
              (ymin (reduce #'min (remove-if (lambda (v) (< v lo-fence)) sorted)
                            :initial-value q1))
              (ymax (reduce #'max (remove-if (lambda (v) (> v hi-fence)) sorted)
                            :initial-value q3))
              (outliers (remove-if (lambda (v) (<= lo-fence v hi-fence)) sorted)))
         (make-gtable
          :x (vector (svref x-col 0))
          :ymin (vector ymin)
          :lower (vector q1)
          :middle (vector q2)
          :upper (vector q3)
          :ymax (vector ymax)
          :outliers (vector (coerce outliers 'list))))))))

;;; ============================================================
;;; stat-ydensity (violin: per-group KDE over the group's own data range
;;; (trim), violinwidth normalized across the panel — plotnine
;;; scale="area" default)
;;; ============================================================

(defmethod stat-compute-panel ((stat stat-ydensity-obj) data scales &key)
  (declare (ignore scales))
  (let* ((result
           (%map-stat-groups
            data
            (lambda (sub)
              (let ((x-col (gtable-column sub :x))
                    (y-col (gtable-column sub :y)))
                (unless (and x-col y-col)
                  (error "stat-ydensity requires x and y aesthetics"))
                (let ((table (%compute-density-table
                              y-col (stat-density-n stat)
                              (stat-density-bw stat)
                              (stat-density-adjust stat))))
                  (when table
                    ;; the density grid runs along y; x is the group position
                    (let ((n (gtable-nrows table)))
                      (gtable-set-column
                       (gtable-set-column
                        (gtable-set-column table :y (gtable-column table :x))
                        :x (make-array n :initial-element (svref x-col 0)))
                       :density (gtable-column table :density)))))))))
         (density (gtable-column result :density))
         (dmax (if (and density (plusp (length density)))
                   (reduce #'max density)
                   1.0d0)))
    ;; scale="area": every violin's width is relative to the panel's
    ;; largest density
    (gtable-set-column result :violinwidth
                       (map 'vector (lambda (d) (/ d (max dmax 1.0d-300)))
                            density))))
