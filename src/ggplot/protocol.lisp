;;;; protocol.lisp — the pluggable data protocol
;;;;
;;;; There is no dominant data-frame library in Common Lisp, so gg defines a
;;;; minimal generic-function protocol. Implement these three generics for
;;;; your data structure and every gg feature works with it, including
;;;; per-layer :data.

(in-package #:ggplot)

(defgeneric ggcolumns (data)
  (:documentation "Return the list of column names of DATA, as keywords, in order."))

(defgeneric ggcolumn (data name)
  (:documentation "Return column NAME (a keyword) of DATA as a fresh simple vector.
Should also accept the column's original name form (string/symbol) when practical."))

(defgeneric ggnrows (data)
  (:documentation "Return the number of rows in DATA."))

(defgeneric ggdata-p (object)
  (:documentation "Return true if OBJECT satisfies the gg data protocol.
Used to disambiguate data arguments in qplot and layer specs.")
  (:method (object) (declare (ignore object)) nil))

(defun normalize-column-name (name)
  "Normalize a column designator (keyword, symbol, string) to a keyword."
  (etypecase name
    (keyword name)
    (symbol (intern (symbol-name name) :keyword))
    (string (intern (string-upcase name) :keyword))))

;;; ============================================================
;;; Built-in method: hash-table (column name → sequence)
;;; ============================================================

(defmethod ggcolumns ((data hash-table))
  (let ((names '()))
    (maphash (lambda (k v) (declare (ignore v))
               (push (normalize-column-name k) names))
             data)
    (nreverse names)))

(defmethod ggcolumn ((data hash-table) name)
  (let ((key (normalize-column-name name)))
    (or (gethash key data)
        ;; string- or symbol-keyed tables
        (block found
          (maphash (lambda (k v)
                     (when (eq (normalize-column-name k) key)
                       (return-from found (coerce v 'simple-vector))))
                   data)
          nil)
        (error "No column named ~S in hash-table data" name))))

(defmethod ggnrows ((data hash-table))
  (let ((n 0))
    (maphash (lambda (k v) (declare (ignore k))
               (setf n (max n (length v))))
             data)
    n))

(defmethod ggdata-p ((data hash-table)) t)

;;; ============================================================
;;; Built-in methods: lists (three shapes, disambiguated)
;;; ============================================================
;;; 1. column alist:      ((:x . #(1 2)) (:y . #(3 4)))
;;; 2. column plist:      (:x #(1 2) :y #(3 4))
;;; 3. rows of plists:    ((:x 1 :y 3) (:x 2 :y 4))

(defun %proper-list-p (x)
  (and (listp x)
       (loop for tail = x then (cdr tail)
             while (consp tail)
             finally (return (null tail)))))

(defun %column-alist-p (data)
  (and (consp data)
       (every (lambda (e)
                (and (consp e)
                     (or (keywordp (car e)) (symbolp (car e)) (stringp (car e)))
                     (typep (cdr e) 'sequence)
                     (not (null (cdr e)))))
              data)))

(defun %column-plist-p (data)
  (and (consp data)
       (%proper-list-p data)
       (evenp (length data))
       (loop for (k v) on data by #'cddr
             always (and (keywordp k) (typep v 'sequence) (not (null v))))))

(defun %row-plists-p (data)
  (and (consp data)
       (every (lambda (row)
                (and (%proper-list-p row)
                     (evenp (length row))
                     (loop for (k nil) on row by #'cddr
                           always (keywordp k))))
              data)))

(defun %list-data-shape (data)
  "One of :alist, :plist, :rows, or NIL.
Rows are checked before alists: ((:x 1 :y 4) ...) reads as row plists, so
alist columns should be vectors (or dotted (name . list) pairs), which the
row check rejects."
  (cond ((%column-plist-p data) :plist)
        ((%row-plists-p data) :rows)
        ((%column-alist-p data) :alist)
        (t nil)))

(defmethod ggdata-p ((data list))
  (and (%list-data-shape data) t))

(defmethod ggcolumns ((data list))
  (ecase (%list-data-shape data)
    (:alist (mapcar (lambda (e) (normalize-column-name (car e))) data))
    (:plist (loop for (k nil) on data by #'cddr collect k))
    (:rows (let ((names '()))
             (dolist (row data (nreverse names))
               (loop for (k nil) on row by #'cddr
                     do (pushnew k names)))))))

(defmethod ggcolumn ((data list) name)
  (let ((key (normalize-column-name name)))
    (ecase (%list-data-shape data)
      (:alist (let ((entry (assoc key data
                                  :key #'normalize-column-name)))
                (unless entry (error "No column named ~S in alist data" name))
                (coerce (cdr entry) 'simple-vector)))
      (:plist (let ((tail (member key data)))
                (unless tail (error "No column named ~S in plist data" name))
                (coerce (second tail) 'simple-vector)))
      (:rows (map 'simple-vector (lambda (row) (getf row key)) data)))))

(defmethod ggnrows ((data list))
  (ecase (%list-data-shape data)
    (:alist (reduce #'max data :key (lambda (e) (length (cdr e))) :initial-value 0))
    (:plist (loop for (nil v) on data by #'cddr maximize (length v)))
    (:rows (length data))))

;;; ============================================================
;;; Built-in wrapper: 2D array + column names
;;; ============================================================

;; :predicate nil — the type predicate would clash with the ggdata-p generic
(defstruct (ggdata (:constructor %make-ggdata (array columns))
                   (:predicate nil))
  "Wrapper giving a 2D array (rows x columns) named columns."
  array
  columns)   ; list of keywords, one per array column

(defun make-ggdata (array &key columns)
  "Wrap a 2D ARRAY (rows x cols) with COLUMNS names for use as gg data."
  (check-type array (array * (* *)))
  (let ((names (mapcar #'normalize-column-name columns)))
    (unless (= (length names) (array-dimension array 1))
      (error "~D column names given for an array with ~D columns"
             (length names) (array-dimension array 1)))
    (%make-ggdata array names)))

(defmethod ggcolumns ((data ggdata))
  (ggdata-columns data))

(defmethod ggcolumn ((data ggdata) name)
  (let* ((key (normalize-column-name name))
         (j (position key (ggdata-columns data))))
    (unless j (error "No column named ~S in ggdata" name))
    (let* ((arr (ggdata-array data))
           (n (array-dimension arr 0))
           (out (make-array n)))
      (dotimes (i n)
        (setf (aref out i) (aref arr i j)))
      (coerce out 'simple-vector))))

(defmethod ggnrows ((data ggdata))
  (array-dimension (ggdata-array data) 0))

(defmethod ggdata-p ((data ggdata)) t)

;;; ============================================================
;;; Conversion into the internal gtable
;;; ============================================================

(defun coerce-ggdata (data)
  "Normalize any protocol-satisfying DATA into an internal gtable."
  (if (gtable-p data)
      data
      (%make-gtable
       (mapcar (lambda (name) (cons name (ggcolumn data name)))
               (ggcolumns data))
       (ggnrows data))))

(defmethod ggcolumns ((data gtable)) (gtable-column-names data))
(defmethod ggcolumn ((data gtable) name)
  (or (gtable-column data (normalize-column-name name))
      (error "No column named ~S" name)))
(defmethod ggnrows ((data gtable)) (gtable-nrows data))
(defmethod ggdata-p ((data gtable)) t)
