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

(defvar *stat-registry* (make-hash-table :test #'eq)
  "Keyword -> stat class, extensible via register-stat.")

(defun register-stat (keyword class-name)
  "Make (geom-* :stat KEYWORD) resolve to CLASS-NAME. Extension API."
  (setf (gethash keyword *stat-registry*) class-name))

(mapc (lambda (pair) (register-stat (car pair) (cdr pair)))
      '((:identity . stat-identity-obj)
        (:count . stat-count-obj)
        (:bin . stat-bin-obj)
        (:density . stat-density-obj)
        (:boxplot . stat-boxplot-obj)
        (:ydensity . stat-ydensity-obj)
        (:smooth . stat-smooth-obj)
        (:ecdf . stat-ecdf-obj)
        (:qq . stat-qq-obj)))

(defun resolve-stat (designator)
  (etypecase designator
    (stat designator)
    (keyword
     (let ((class (gethash designator *stat-registry*)))
       (unless class
         (error "Unknown stat ~S. Known: ~{~S~^ ~} (register-stat adds more)"
                designator
                (loop for k being the hash-keys of *stat-registry* collect k)))
       (make-instance class)))))

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

(defun map-stat-groups (data fn)
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
  (map-stat-groups
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
  (map-stat-groups
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
  (map-stat-groups
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
  (map-stat-groups
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
          :outliers (vector (coerce outliers 'list))
          ;; extend the trained y range over the outliers (plotnine's
          ;; ymin_final/ymax_final)
          :ymin-final (vector (reduce #'min outliers :initial-value ymin))
          :ymax-final (vector (reduce #'max outliers
                                      :initial-value ymax))))))))

;;; ============================================================
;;; stat-ydensity (violin: per-group KDE over the group's own data range
;;; (trim), violinwidth normalized across the panel — plotnine
;;; scale="area" default)
;;; ============================================================

(defmethod stat-compute-panel ((stat stat-ydensity-obj) data scales &key)
  (declare (ignore scales))
  (let* ((result
           (map-stat-groups
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

;;; ============================================================
;;; stat-smooth (plotnine: method lm/loess, level 0.95, n=80 grid,
;;; loess span 0.75)
;;; ============================================================

(defclass stat-smooth-obj (stat)
  ((method :initarg :method :initform :lm :reader stat-smooth-method)
   (se :initarg :se :initform t :reader stat-smooth-se-p)
   (level :initarg :level :initform 0.95d0 :reader stat-smooth-level)
   (n :initarg :n :initform 80 :reader stat-smooth-n)
   (span :initarg :span :initform 0.75d0 :reader stat-smooth-span)))

(defun %ols-fit (xs ys)
  "Ordinary least squares y = a + b x.
Returns (values a b s2 xbar sxx n) where s2 is the residual variance."
  (let* ((n (length xs))
         (xbar (/ (reduce #'+ xs) n))
         (ybar (/ (reduce #'+ ys) n))
         (sxx (reduce #'+ xs :key (lambda (x) (expt (- x xbar) 2))))
         (sxy (loop for x across xs for y across ys
                    sum (* (- x xbar) (- y ybar))))
         (b (if (zerop sxx) 0.0d0 (/ sxy sxx)))
         (a (- ybar (* b xbar)))
         (ss (loop for x across xs for y across ys
                   sum (expt (- y a (* b x)) 2)))
         (s2 (if (> n 2) (/ ss (- n 2)) 0.0d0)))
    (values a b s2 xbar sxx n)))

(defun %smooth-lm (xs ys grid level se-p)
  (multiple-value-bind (a b s2 xbar sxx n) (%ols-fit xs ys)
    (let ((tq (if (and se-p (> n 2))
                  (student-t-quantile (- 1.0d0 (/ (- 1.0d0 level) 2.0d0))
                                      (- n 2))
                  0.0d0)))
      (values
       (map 'simple-vector (lambda (x) (+ a (* b x))) grid)
       (when se-p
         (map 'simple-vector
              (lambda (x)
                (* tq (sqrt (* s2 (+ (/ 1.0d0 n)
                                     (if (zerop sxx)
                                         0.0d0
                                         (/ (expt (- x xbar) 2) sxx)))))))
              grid))))))

(defun %smooth-loess (xs ys grid level se-p span)
  "Local linear regression with tricube weights. The se ribbon uses the
equivalent-kernel norm ||l(x)|| with a pooled residual variance — the
standard first-order loess variance approximation."
  (let* ((n (length xs))
         (q (max 2 (ceiling (* span n))))
         (order (sort (loop for i from 0 below n collect i) #'<
                      :key (lambda (i) (svref xs i))))
         (sx (map 'simple-vector (lambda (i) (svref xs i)) order))
         (sy (map 'simple-vector (lambda (i) (svref ys i)) order))
         (fitted (make-array n))
         (fit-at (lambda (x0 &optional collect-l)
                   ;; q nearest neighbours of x0
                   (let* ((dists (map 'simple-vector
                                      (lambda (x) (abs (- x x0))) sx))
                          (idx (subseq (sort (loop for i from 0 below n collect i)
                                             #'< :key (lambda (i) (svref dists i)))
                                       0 q))
                          (dmax (max (reduce #'max idx
                                             :key (lambda (i) (svref dists i)))
                                     1.0d-12))
                          (w (mapcar (lambda (i)
                                       (let ((u (/ (svref dists i) dmax)))
                                         (if (< u 1.0d0)
                                             (expt (- 1.0d0 (expt u 3)) 3)
                                             0.0d0)))
                                     idx))
                          (sw (reduce #'+ w))
                          (wx (loop for i in idx for wi in w
                                    sum (* wi (svref sx i))))
                          (xb (/ wx (max sw 1.0d-12)))
                          (sxx (loop for i in idx for wi in w
                                     sum (* wi (expt (- (svref sx i) xb) 2))))
                          ;; weighted local linear equivalent kernel
                          (l (mapcar (lambda (i wi)
                                       (* (/ wi (max sw 1.0d-12))
                                          (+ 1.0d0
                                             (if (zerop sxx)
                                                 0.0d0
                                                 (/ (* (- x0 xb)
                                                       (- (svref sx i) xb)
                                                       sw)
                                                    sxx)))))
                                     idx w)))
                     (values (loop for i in idx for li in l
                                   sum (* li (svref sy i)))
                             (when collect-l
                               (loop for li in l sum (* li li))))))))
    ;; residual variance from in-sample fits
    (dotimes (i n)
      (setf (svref fitted i) (funcall fit-at (svref sx i))))
    (let* ((s2 (if (> n 2)
                   (/ (loop for i from 0 below n
                            sum (expt (- (svref sy i) (svref fitted i)) 2))
                      (- n 2))
                   0.0d0))
           (tq (if (and se-p (> n 2))
                   (student-t-quantile (- 1.0d0 (/ (- 1.0d0 level) 2.0d0))
                                       (- n 2))
                   0.0d0))
           (yhat (make-array (length grid)))
           (half (when se-p (make-array (length grid)))))
      (loop for gi from 0 below (length grid)
            do (multiple-value-bind (fit lnorm)
                   (funcall fit-at (svref grid gi) se-p)
                 (setf (svref yhat gi) fit)
                 (when se-p
                   (setf (svref half gi) (* tq (sqrt (* s2 lnorm)))))))
      (values yhat half))))

(defmethod stat-compute-panel ((stat stat-smooth-obj) data scales &key)
  (declare (ignore scales))
  (map-stat-groups
   data
   (lambda (sub)
     (let ((x-col (gtable-column sub :x))
           (y-col (gtable-column sub :y)))
       (unless (and x-col y-col)
         (error "stat-smooth requires x and y aesthetics"))
       (let* ((xs (map 'simple-vector (lambda (v) (float v 1.0d0)) x-col))
              (ys (map 'simple-vector (lambda (v) (float v 1.0d0)) y-col))
              (n (length xs)))
         ;; ggplot2/plotnine: a group needs two distinct x values to fit;
         ;; smaller groups are dropped. The confidence band needs residual
         ;; degrees of freedom (n > 2); a two-point group gets the line only.
         (when (> (length (remove-duplicates xs :test #'=)) 1)
           (let* ((lo (reduce #'min xs))
                  (hi (reduce #'max xs))
                  (grid (%linspace lo hi (stat-smooth-n stat)))
                  (se-p (and (stat-smooth-se-p stat) (> n 2))))
             (multiple-value-bind (yhat half)
                 (ecase (stat-smooth-method stat)
                   (:lm (%smooth-lm xs ys grid (stat-smooth-level stat) se-p))
                   (:loess (%smooth-loess xs ys grid (stat-smooth-level stat)
                                          se-p (stat-smooth-span stat))))
               (let ((table (make-gtable :x grid :y yhat)))
                 (if (and se-p half)
                     (gtable-set-column
                      (gtable-set-column
                       table :ymin (map 'simple-vector #'- yhat half))
                      :ymax (map 'simple-vector #'+ yhat half))
                     table))))))))))

;;; ============================================================
;;; stat-ecdf / stat-qq
;;; ============================================================

(defclass stat-ecdf-obj (stat) ())

(defmethod stat-default-aes ((stat stat-ecdf-obj))
  (list :y (after-stat :ecdf)))

(defmethod stat-compute-panel ((stat stat-ecdf-obj) data scales &key)
  (declare (ignore scales))
  (map-stat-groups
   data
   (lambda (sub)
     (let ((x-col (gtable-column sub :x)))
       (unless x-col (error "stat-ecdf requires an x aesthetic"))
       (let* ((sorted (%sorted-doubles x-col))
              (n (length sorted)))
         ;; plotnine pads the curve with (-Inf, 0) and (+Inf, 1) so the
         ;; step runs to the panel edges; the infinities are excluded from
         ;; scale training (finite-range) and clipped at draw time.
         (make-gtable
          :x (concatenate 'vector
                          (vector float-features:double-float-negative-infinity)
                          sorted
                          (vector float-features:double-float-positive-infinity))
          :ecdf (coerce (cons 0.0d0
                              (append (loop for i from 1 to n
                                            collect (/ (float i 1.0d0) n))
                                      (list 1.0d0)))
                        'vector)))))))

(defclass stat-qq-obj (stat) ())

(defmethod stat-compute-panel ((stat stat-qq-obj) data scales &key)
  (declare (ignore scales))
  (map-stat-groups
   data
   (lambda (sub)
     (let ((sample-col (or (gtable-column sub :sample)
                           (gtable-column sub :y)
                           (gtable-column sub :x))))
       (unless sample-col (error "stat-qq requires a sample aesthetic"))
       (let* ((sorted (%sorted-doubles sample-col))
              (n (length sorted))
              ;; R's ppoints: (i - a)/(n + 1 - 2a), a = 3/8 for n<=10 else 1/2
              (a (if (<= n 10) 0.375d0 0.5d0)))
         (make-gtable
          :x (coerce (loop for i from 1 to n
                           collect (inverse-normal-cdf
                                    (/ (- i a) (+ n 1.0d0 (* -2.0d0 a)))))
                     'vector)
          :y sorted))))))

;;; ============================================================
;;; stat-bin2d: rectangular 2D binning
;;; ============================================================

(defclass stat-bin2d-obj (stat)
  ((bins :initarg :bins :initform 30 :reader stat-bin2d-bins)))

(defmethod stat-default-aes ((stat stat-bin2d-obj))
  (list :fill (after-stat :count)))

(defmethod stat-compute-panel ((stat stat-bin2d-obj) data scales &key)
  (declare (ignore scales))
  (let ((x-col (gtable-column data :x))
        (y-col (gtable-column data :y))
        (bins (stat-bin2d-bins stat)))
    (unless (and x-col y-col)
      (error "stat-bin2d requires x and y aesthetics"))
    (multiple-value-bind (xlo xhi) (finite-range x-col)
      (multiple-value-bind (ylo yhi) (finite-range y-col)
        ;; plotnine: binwidth = range/bins, edges on the k*binwidth grid
        ;; anchored at 0 (verified against geom_bin_2d output)
        (let* ((xw (/ (max (- xhi xlo) 1.0d-12) bins))
               (yw (/ (max (- yhi ylo) 1.0d-12) bins))
               (counts (make-hash-table :test #'equal)))
          (dotimes (i (length x-col))
            (let ((bx (floor (float (svref x-col i) 1.0d0) xw))
                  (by (floor (float (svref y-col i) 1.0d0) yw)))
              (incf (gethash (list bx by) counts 0))))
          (let ((cells (sort (loop for k being the hash-keys of counts
                                     using (hash-value v)
                                   collect (cons k v))
                             (lambda (a b)
                               (or (< (first (car a)) (first (car b)))
                                   (and (= (first (car a)) (first (car b)))
                                        (< (second (car a)) (second (car b)))))))))
            (make-gtable
             :xmin (map 'vector (lambda (c) (* (first (car c)) xw)) cells)
             :xmax (map 'vector (lambda (c) (* (1+ (first (car c))) xw)) cells)
             :ymin (map 'vector (lambda (c) (* (second (car c)) yw)) cells)
             :ymax (map 'vector (lambda (c) (* (1+ (second (car c))) yw)) cells)
             :x (map 'vector (lambda (c) (* (+ 0.5d0 (first (car c))) xw)) cells)
             :y (map 'vector (lambda (c) (* (+ 0.5d0 (second (car c))) yw)) cells)
             :count (map 'vector (lambda (c) (float (cdr c) 1.0d0)) cells))))))))

;;; ============================================================
;;; stat-sum: count observations per (x, y) location
;;; ============================================================

(defclass stat-sum-obj (stat) ())

(defmethod stat-default-aes ((stat stat-sum-obj))
  (list :size (after-stat :n)))

(defmethod stat-compute-panel ((stat stat-sum-obj) data scales &key)
  (declare (ignore scales))
  (map-stat-groups
   data
   (lambda (sub)
     (let ((x-col (gtable-column sub :x))
           (y-col (gtable-column sub :y))
           (counts (make-hash-table :test #'equal)))
       (unless (and x-col y-col)
         (error "stat-sum requires x and y aesthetics"))
       (dotimes (i (length x-col))
         (incf (gethash (list (svref x-col i) (svref y-col i)) counts 0)))
       (let ((locs (sort (loop for k being the hash-keys of counts
                                 using (hash-value v)
                               collect (cons k v))
                         (lambda (a b)
                           (or (< (first (car a)) (first (car b)))
                               (and (= (first (car a)) (first (car b)))
                                    (< (second (car a)) (second (car b)))))))))
         (make-gtable
          :x (map 'vector (lambda (l) (first (car l))) locs)
          :y (map 'vector (lambda (l) (second (car l))) locs)
          :n (map 'vector (lambda (l) (float (cdr l) 1.0d0)) locs)))))))

(register-stat :bin2d 'stat-bin2d-obj)
(register-stat :sum 'stat-sum-obj)
