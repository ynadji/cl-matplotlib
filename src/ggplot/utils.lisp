;;;; utils.lisp — internal column table (gtable) and numeric helpers

(in-package #:ggplot)

;;; ============================================================
;;; gtable — the internal column-oriented table
;;; ============================================================
;;; Every pipeline stage consumes and produces gtables; user data is
;;; converted exactly once at the top of ggbuild.

(defstruct (gtable (:constructor %make-gtable (columns nrows)))
  ;; COLUMNS is an ordered list of (keyword . simple-vector)
  (columns nil :type list)
  (nrows 0 :type fixnum))

(defun make-gtable (&rest name-column-plist)
  "Build a gtable from alternating NAME VECTOR arguments.
Columns are coerced to simple vectors and must share one length."
  (let ((cols (loop for (name col) on name-column-plist by #'cddr
                    collect (cons name (coerce col 'simple-vector)))))
    (let ((n (if cols (length (cdr (first cols))) 0)))
      (dolist (c (rest cols))
        (unless (= (length (cdr c)) n)
          (error "gtable columns must have equal length: ~S has ~D rows, expected ~D"
                 (car c) (length (cdr c)) n)))
      (%make-gtable cols n))))

(defun gtable-column (table name)
  "Column NAME of TABLE, or NIL if absent."
  (cdr (assoc name (gtable-columns table))))

(defun gtable-column-names (table)
  (mapcar #'car (gtable-columns table)))

(defun gtable-set-column (table name column)
  "Return a new gtable with column NAME set/replaced by COLUMN."
  (let ((vec (coerce column 'simple-vector)))
    (unless (or (zerop (gtable-nrows table))
                (= (length vec) (gtable-nrows table)))
      (error "Column ~S has ~D rows; table has ~D" name (length vec) (gtable-nrows table)))
    (let ((existing (assoc name (gtable-columns table))))
      (%make-gtable
       (if existing
           (mapcar (lambda (c) (if (eq (car c) name) (cons name vec) c))
                   (gtable-columns table))
           (append (gtable-columns table) (list (cons name vec))))
       (max (gtable-nrows table) (length vec))))))

(defun gtable-select (table row-indices)
  "Return a new gtable containing only the rows in ROW-INDICES (a list or vector)."
  (let ((idx (coerce row-indices 'list)))
    (%make-gtable
     (mapcar (lambda (c)
               (cons (car c)
                     (map 'simple-vector (lambda (i) (svref (cdr c) i)) idx)))
             (gtable-columns table))
     (length idx))))

(defun gtable-split (table name)
  "Split TABLE by the values of column NAME.
Returns an alist of (value . sub-gtable) in order of first appearance.
If the column is absent, returns ((nil . table))."
  (let ((col (gtable-column table name)))
    (if (null col)
        (list (cons nil table))
        (let ((groups '()))   ; (value . list-of-indices) reversed
          (dotimes (i (length col))
            (let ((entry (assoc (svref col i) groups :test #'equal)))
              (if entry
                  (push i (cdr entry))
                  (push (cons (svref col i) (list i)) groups))))
          (mapcar (lambda (g) (cons (car g) (gtable-select table (nreverse (cdr g)))))
                  (nreverse groups))))))

(defun gtable-rbind (tables)
  "Concatenate a list of gtables row-wise. Columns are unioned; missing
values are filled with NIL."
  (let* ((tables (remove nil tables))
         (names (remove-duplicates (mapcan #'gtable-column-names (copy-list tables))
                                   :from-end t))
         (total (reduce #'+ tables :key #'gtable-nrows)))
    (%make-gtable
     (mapcar (lambda (name)
               (let ((out (make-array total)) (pos 0))
                 (dolist (tbl tables)
                   (let ((col (gtable-column tbl name)))
                     (dotimes (i (gtable-nrows tbl))
                       (setf (aref out (+ pos i)) (and col (svref col i)))))
                   (incf pos (gtable-nrows tbl)))
                 (cons name (coerce out 'simple-vector))))
             names)
     total)))

(defun gtable-sort-by (table name &key (predicate #'<))
  "Return a new gtable with rows stably sorted by column NAME."
  (let ((col (gtable-column table name)))
    (if (null col)
        table
        (let ((indices (stable-sort
                        (loop for i from 0 below (gtable-nrows table) collect i)
                        predicate
                        :key (lambda (i) (svref col i)))))
          (gtable-select table indices)))))

;;; ============================================================
;;; Numeric helpers
;;; ============================================================

(defun finite-range (values)
  "Return (values min max) over the finite numbers in VALUES, or NILs."
  (let ((lo nil) (hi nil))
    (map nil (lambda (v)
               (when (and (realp v)
                          (not (and (floatp v)
                                    (or (float-features:float-nan-p (float v 1.0d0))
                                        (float-features:float-infinity-p (float v 1.0d0))))))
                 (let ((v (float v 1.0d0)))
                   (when (or (null lo) (< v lo)) (setf lo v))
                   (when (or (null hi) (> v hi)) (setf hi v)))))
         values)
    (values lo hi)))

(defun discrete-value-p (v)
  "Heuristic: is V a discrete (categorical) value?"
  (or (stringp v) (symbolp v) (characterp v)))

;;; ============================================================
;;; Extended Wilkinson tick placement (Talbot, Lindlöf, Heer 2010)
;;; ============================================================
;;; Port of the algorithm used by mizani's extended_breaks (plotnine's
;;; default), so gg tick positions match plotnine's pixel-for-pixel.

(defparameter *extended-q* #(1.0d0 5.0d0 2.0d0 2.5d0 4.0d0 3.0d0))
(defparameter *extended-w* #(0.25d0 0.2d0 0.5d0 0.05d0))

(defun %ext-simplicity (qi j lmin lmax lstep)
  (let* ((eps 1.0d-10)
         (n (length *extended-q*))
         (i (1+ qi))
         (v (if (and (or (< (mod lmin lstep) eps)
                         (< (- lstep (mod lmin lstep)) eps))
                     (<= lmin 0.0d0) (>= lmax 0.0d0))
                1.0d0 0.0d0)))
    (+ (/ (- n i) (- n 1.0d0)) v (- j))))

(defun %ext-simplicity-max (qi j)
  (let ((n (length *extended-q*))
        (i (1+ qi)))
    (+ (/ (- n i) (- n 1.0d0)) 1.0d0 (- j))))

(defun %ext-coverage (dmin dmax lmin lmax)
  (let ((r (- dmax dmin)))
    (- 1.0d0 (* 0.5d0 (/ (+ (expt (- dmax lmax) 2) (expt (- dmin lmin) 2))
                         (expt (* 0.1d0 r) 2))))))

(defun %ext-coverage-max (dmin dmax span)
  (let ((r (- dmax dmin)))
    (if (> span r)
        (let ((half (/ (- span r) 2.0d0)))
          (- 1.0d0 (* 0.5d0 (/ (+ (* half half) (* half half))
                               (expt (* 0.1d0 r) 2)))))
        1.0d0)))

(defun %ext-density (k m dmin dmax lmin lmax)
  (let ((r (/ (- k 1.0d0) (- lmax lmin)))
        (rt (/ (- m 1.0d0) (- (max lmax dmax) (min lmin dmin)))))
    (- 2.0d0 (max (/ r rt) (/ rt r)))))

(defun %ext-density-max (k m)
  (if (>= k m)
      (- 2.0d0 (/ (- k 1.0d0) (- m 1.0d0)))
      1.0d0))

(defun extended-breaks (dmin dmax &optional (m 5))
  "Compute ~M 'nice' tick locations covering [DMIN, DMAX].
Faithful port of the extended-Wilkinson algorithm as implemented in
mizani (plotnine's default breaks), so positions match plotnine."
  (let ((dmin (float dmin 1.0d0))
        (dmax (float dmax 1.0d0)))
    (when (> dmin dmax) (rotatef dmin dmax))
    (when (< (- dmax dmin) 1.0d-14)
      (return-from extended-breaks (list dmin)))
    (let ((best nil)
          (best-score -2.0d0))
      (loop for j from 1 below 10
            with done = nil
            until done do
              (loop for qi from 0 below (length *extended-q*)
                    for q = (aref *extended-q* qi)
                    for sm = (%ext-simplicity-max qi j)
                    do (when (< (+ (* (aref *extended-w* 0) sm)
                                   (aref *extended-w* 1)
                                   (aref *extended-w* 2)
                                   (aref *extended-w* 3))
                                best-score)
                         (setf done t)
                         (return))
                       (loop for k from 2 below 13
                             for dm = (%ext-density-max k m)
                             do (when (< (+ (* (aref *extended-w* 0) sm)
                                            (aref *extended-w* 1)
                                            (* (aref *extended-w* 2) dm)
                                            (aref *extended-w* 3))
                                         best-score)
                                  (return))
                                (let* ((delta (/ (- dmax dmin) (+ k 1.0d0) j q))
                                       (z (ceiling (log delta 10.0d0))))
                                  (loop for zz from z below (+ z 15)
                                        for step = (* j q (expt 10.0d0 zz))
                                        for cm = (%ext-coverage-max dmin dmax (* step (1- k)))
                                        do (when (< (+ (* (aref *extended-w* 0) sm)
                                                       (* (aref *extended-w* 1) cm)
                                                       (* (aref *extended-w* 2) dm)
                                                       (aref *extended-w* 3))
                                                    best-score)
                                             (return))
                                           (let ((min-start (- (* (floor dmax step) j) (* (1- k) j)))
                                                 (max-start (* (ceiling dmin step) j)))
                                             (when (<= min-start max-start)
                                               (loop for start from min-start to max-start
                                                     for lmin = (* start (/ step j))
                                                     for lmax = (+ lmin (* step (1- k)))
                                                     for s = (%ext-simplicity qi j lmin lmax step)
                                                     for c = (%ext-coverage dmin dmax lmin lmax)
                                                     for g = (%ext-density k m dmin dmax lmin lmax)
                                                     for score = (+ (* (aref *extended-w* 0) s)
                                                                    (* (aref *extended-w* 1) c)
                                                                    (* (aref *extended-w* 2) g)
                                                                    (aref *extended-w* 3))
                                                     do (when (> score best-score)
                                                          (setf best-score score
                                                                best (list lmin lmax step)))))))))))
      (if best
          (destructuring-bind (lmin lmax lstep) best
            (loop for tick = lmin then (+ tick lstep)
                  while (<= tick (+ lmax (* 1.0d-10 lstep)))
                  ;; snap floating noise (e.g. 0.30000000000000004 -> 0.3)
                  collect (let ((snapped (/ (round (* tick 1.0d10)) 1.0d10)))
                            (float snapped 1.0d0))))
          (list dmin dmax)))))

;;; ============================================================
;;; rc helper — functional variant of mpl.rc:with-rc for computed alists
;;; ============================================================

(defun call-with-rc-alist (alist thunk)
  "Bind rc params from ALIST ((key . value) ...) around THUNK, restoring on
exit. Keys this rc implementation doesn't know are skipped silently (the
theme mapping targets standard matplotlib names; not all exist here)."
  (let ((known (remove-if-not
                (lambda (kv)
                  (handler-case (progn (cl-matplotlib.rc:rc (car kv)) t)
                    (error () nil)))
                alist)))
    (let ((saved (mapcar (lambda (kv) (cons (car kv) (cl-matplotlib.rc:rc (car kv))))
                         known)))
      (unwind-protect
           (progn
             (dolist (kv known)
               (handler-case (setf (cl-matplotlib.rc:rc (car kv)) (cdr kv))
                 (error ()
                   (warn "Ignoring rc value ~S for ~S (rejected by validator)"
                         (cdr kv) (car kv)))))
             (funcall thunk))
        (dolist (kv saved)
          (ignore-errors (setf (cl-matplotlib.rc:rc (car kv)) (cdr kv))))))))
