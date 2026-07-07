;;;; plot.lisp — the ggplot generic and label/limit helpers

(in-package #:ggplot)

(defgeneric ggplot (data &optional mapping &rest initargs &key &allow-other-keys)
  (:documentation "Create a ggplot specification from DATA and an aes MAPPING.

DATA may be anything satisfying the gg data protocol (ggcolumns, ggcolumn,
ggnrows) — built-in support covers column alists, column plists,
hash-tables, lists of row plists, and make-ggdata array wrappers.

To plug in your own data structure either implement the protocol generics
(preferred: everything, including per-layer :data, then works) or
specialize this generic to convert your object and call-next-method."))

(defmethod ggplot (data &optional mapping &rest initargs)
  (declare (ignore initargs))
  (unless (ggdata-p data)
    (error "~S does not satisfy the gg data protocol. Implement ggcolumns/~
            ggcolumn/ggnrows for your data type, or pass a column alist, ~
            column plist, hash-table, list of row plists, or make-ggdata."
           data))
  (make-instance 'ggplot :data data :mapping mapping))

(defmethod ggplot ((data null) &optional mapping &rest initargs)
  "A data-less plot: layers must supply their own :data."
  (declare (ignore initargs))
  (make-instance 'ggplot :data nil :mapping mapping))

;;; ============================================================
;;; labs and friends
;;; ============================================================

(defun labs (&rest pairs &key title subtitle caption x y &allow-other-keys)
  "Set plot labels: (labs :title \"...\" :x \"...\" :y \"...\").
Keys other than :title/:subtitle/:caption/:x/:y name aesthetics whose
guide title to set (e.g. :color \"Cylinders\")."
  (declare (ignore title subtitle caption x y))
  (make-instance 'labs-spec
                 :alist (loop for (k v) on pairs by #'cddr
                              collect (cons k v))))

(defun xlab (label) (labs :x label))
(defun ylab (label) (labs :y label))
(defun ggtitle (title &optional subtitle)
  (if subtitle
      (labs :title title :subtitle subtitle)
      (labs :title title)))
