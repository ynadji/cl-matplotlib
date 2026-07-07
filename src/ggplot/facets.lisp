;;;; facets.lisp — faceting (small multiples)

(in-package #:ggplot)

(defclass facet-null-obj (facet) ())

(defclass facet-wrap-obj (facet)
  ((vars :initarg :vars :reader facet-vars
         :documentation "List of column designators to facet by.")
   (nrow :initarg :nrow :initform nil :reader facet-nrow)
   (ncol :initarg :ncol :initform nil :reader facet-ncol)
   (scales :initarg :scales :initform :fixed :reader facet-scales)))

(defun facet-wrap (vars &key nrow ncol (scales :fixed))
  "Wrap panels of the data split by VARS (a column name or list of names)
into a roughly square grid. :scales :free is not implemented yet."
  (unless (eq scales :fixed)
    (error "facet-wrap: only :scales :fixed is implemented so far"))
  (make-instance 'facet-wrap-obj
                 :vars (mapcar #'normalize-column-name
                               (if (listp vars) vars (list vars)))
                 :nrow nrow :ncol ncol :scales scales))

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
                           :label (format nil "~{~A~^, ~}" key)
                           :key key))
       nrow ncol))))

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
