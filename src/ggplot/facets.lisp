;;;; facets.lisp — faceting (small multiples)

(in-package #:ggplot)

(defclass facet-null-obj (facet) ())

(defclass facet-wrap-obj (facet)
  ((vars :initarg :vars :reader facet-vars
         :documentation "List of column designators to facet by.")
   (nrow :initarg :nrow :initform nil :reader facet-nrow)
   (ncol :initarg :ncol :initform nil :reader facet-ncol)
   (scales :initarg :scales :initform :fixed :reader facet-scales)
   (labeller :initarg :labeller :initform :value :reader facet-labeller)))

(defclass facet-grid-obj (facet)
  ((row-vars :initarg :row-vars :reader facet-row-vars)
   (col-vars :initarg :col-vars :reader facet-col-vars)
   (scales :initarg :scales :initform :fixed :reader facet-scales)
   (labeller :initarg :labeller :initform :value :reader facet-labeller)))

(defun %check-facet-scales (scales)
  (unless (member scales '(:fixed :free :free-x :free-y))
    (error "facet scales must be :fixed, :free, :free-x or :free-y, got ~S"
           scales))
  scales)

(defun facet-free-x-p (facet)
  (and (typep facet '(or facet-wrap-obj facet-grid-obj))
       (member (facet-scales facet) '(:free :free-x))))

(defun facet-free-y-p (facet)
  (and (typep facet '(or facet-wrap-obj facet-grid-obj))
       (member (facet-scales facet) '(:free :free-y))))

(defun facet-wrap (vars &key nrow ncol (scales :fixed) (labeller :value))
  "Wrap panels of the data split by VARS (a column name or list of names)
into a roughly square grid. SCALES: :fixed (default), :free, :free-x or
:free-y (free dimensions get per-panel limits and breaks; continuous
scales only). LABELLER: :value (default), :both (\"var: value\"), or a
function of (var value) returning a string."
  (make-instance 'facet-wrap-obj
                 :vars (mapcar #'normalize-column-name
                               (if (listp vars) vars (list vars)))
                 :nrow nrow :ncol ncol
                 :scales (%check-facet-scales scales)
                 :labeller labeller))

(defun facet-grid (&key rows cols (scales :fixed) (labeller :value))
  "Panel matrix: distinct ROWS values down, distinct COLS values across
(plotnine facet_grid). Column strips sit above the top row; row strips
sit right of the last column. At least one of ROWS/COLS is required."
  (unless (or rows cols)
    (error "facet-grid needs :rows and/or :cols"))
  (flet ((norm (v) (and v (mapcar #'normalize-column-name
                                  (if (listp v) v (list v))))))
    (make-instance 'facet-grid-obj
                   :row-vars (norm rows)
                   :col-vars (norm cols)
                   :scales (%check-facet-scales scales)
                   :labeller labeller)))

(defun %facet-label (labeller var value)
  (ecase (if (functionp labeller) :function labeller)
    (:value (princ-to-string value))
    (:both (format nil "~(~a~): ~a" var value))
    (:function (funcall labeller var value))))

(defun %facet-key-label (labeller vars key)
  (format nil "~{~A~^, ~}"
          (mapcar (lambda (var value) (%facet-label labeller var value))
                  vars key)))

(defun %facet-key (facet raw-table row-index)
  "The panel key of one data row: list of the facet vars' values."
  (mapcar (lambda (var)
            (let ((col (gtable-column raw-table var)))
              (unless col
                (error "facet variable ~S is not a column (columns: ~{~S~^ ~})"
                       var (gtable-column-names raw-table)))
              (svref col row-index)))
          (facet-vars facet)))

(defgeneric facet-layout (facet layer-raw-tables)
  (:documentation "Compute the panel layout. Returns a list of plists
(:index :row :col :label :key) plus (values layout nrow ncol).")
  (:method ((facet facet-null-obj) layer-raw-tables)
    (declare (ignore layer-raw-tables))
    (values (list (list :index 0 :row 0 :col 0 :label nil :key nil)) 1 1)))

(defmethod facet-layout ((facet facet-wrap-obj) layer-raw-tables)
  (let ((keys '()))
    (dolist (table layer-raw-tables)
      (dotimes (i (gtable-nrows table))
        (pushnew (%facet-key facet table i) keys :test #'equal)))
    ;; sort panels like plotnine: by the (stringified) key
    (setf keys (sort (nreverse keys) #'string<
                     :key (lambda (k) (format nil "~{~A~^|~}" k))))
    (let* ((n (length keys))
           (ncol (or (facet-ncol facet)
                     (and (facet-nrow facet)
                          (ceiling n (facet-nrow facet)))
                     (ceiling (sqrt (float n 1.0d0)))))
           (nrow (or (facet-nrow facet) (ceiling n ncol))))
      (values
       (loop for key in keys
             for i from 0
             collect (list :index i
                           :row (floor i ncol)
                           :col (mod i ncol)
                           :label (%facet-key-label (facet-labeller facet)
                                                    (facet-vars facet) key)
                           :key key))
       nrow ncol))))

(defun %facet-grid-var-key (vars table row-index)
  (mapcar (lambda (var)
            (let ((col (gtable-column table var)))
              (unless col
                (error "facet variable ~S is not a column (columns: ~{~S~^ ~})"
                       var (gtable-column-names table)))
              (svref col row-index)))
          vars))

(defun %facet-grid-axis-keys (vars layer-raw-tables)
  "Sorted distinct keys along one grid axis; a single NIL key when the
axis has no faceting variables."
  (if (null vars)
      (list nil)
      (let ((keys '()))
        (dolist (table layer-raw-tables)
          (dotimes (i (gtable-nrows table))
            (pushnew (%facet-grid-var-key vars table i) keys :test #'equal)))
        (sort (nreverse keys) #'string<
              :key (lambda (k) (format nil "~{~A~^|~}" k))))))

(defmethod facet-layout ((facet facet-grid-obj) layer-raw-tables)
  (let* ((row-keys (%facet-grid-axis-keys (facet-row-vars facet)
                                          layer-raw-tables))
         (col-keys (%facet-grid-axis-keys (facet-col-vars facet)
                                          layer-raw-tables))
         (nrow (length row-keys))
         (ncol (length col-keys))
         (labeller (facet-labeller facet)))
    (values
     (loop for r from 0 below nrow
           append (loop for c from 0 below ncol
                        collect
                        (list :index (+ (* r ncol) c)
                              :row r :col c
                              ;; top strip (first row only): column key
                              :label (when (and (zerop r)
                                                (facet-col-vars facet))
                                       (%facet-key-label
                                        labeller (facet-col-vars facet)
                                        (nth c col-keys)))
                              ;; right strip (last column only): row key
                              :row-label (when (and (= c (1- ncol))
                                                    (facet-row-vars facet))
                                           (%facet-key-label
                                            labeller (facet-row-vars facet)
                                            (nth r row-keys)))
                              :key (list (nth r row-keys)
                                         (nth c col-keys)))))
     nrow ncol)))

(defmethod facet-assign-panels ((facet facet-grid-obj) layout raw-table)
  (let ((out (make-array (gtable-nrows raw-table))))
    (dotimes (i (gtable-nrows raw-table))
      (let* ((rk (and (facet-row-vars facet)
                      (%facet-grid-var-key (facet-row-vars facet) raw-table i)))
             (ck (and (facet-col-vars facet)
                      (%facet-grid-var-key (facet-col-vars facet) raw-table i)))
             (entry (find (list rk ck) layout
                          :key (lambda (p) (getf p :key))
                          :test #'equal)))
        (unless entry
          (error "no facet-grid panel for key ~S" (list rk ck)))
        (setf (aref out i) (getf entry :index))))
    out))

(defgeneric facet-assign-panels (facet layout raw-table)
  (:documentation "Vector of panel indices, one per row of RAW-TABLE.")
  (:method ((facet facet-null-obj) layout raw-table)
    (declare (ignore layout))
    (make-array (gtable-nrows raw-table) :initial-element 0)))

(defmethod facet-assign-panels ((facet facet-wrap-obj) layout raw-table)
  (let ((out (make-array (gtable-nrows raw-table))))
    (dotimes (i (gtable-nrows raw-table))
      (let* ((key (%facet-key facet raw-table i))
             (entry (find key layout :key (lambda (p) (getf p :key))
                                     :test #'equal)))
        (setf (aref out i) (getf entry :index))))
    out))

(defun %gtable-panel-subset (table panel-index)
  "Rows of TABLE belonging to PANEL-INDEX (all rows when no :panel column)."
  (let ((panel-col (gtable-column table :panel)))
    (if (null panel-col)
        table
        (gtable-select table
                       (loop for i from 0 below (gtable-nrows table)
                             when (eql (svref panel-col i) panel-index)
                               collect i)))))

(defun %split-by-panel (table)
  "Alist (panel-index . sub-table); tables without a :panel column are one
panel."
  (if (gtable-column table :panel)
      (gtable-split table :panel)
      (list (cons 0 table))))

(defun %map-table-panels (table fn)
  "Apply FN to each panel's sub-table, preserving the :panel column."
  (gtable-rbind
   (loop for (panel . sub) in (%split-by-panel table)
         for out = (funcall fn sub)
         when (and out (plusp (gtable-nrows out)))
           collect (if (gtable-column out :panel)
                       out
                       (gtable-set-column
                        out :panel
                        (make-array (gtable-nrows out)
                                    :initial-element panel))))))
