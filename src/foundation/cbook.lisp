;;;; cbook.lisp — Utility functions ported from matplotlib.cbook
;;;; Cherry-picked useful functions; Python-specific utilities skipped.

(in-package #:cl-matplotlib.cbook)

;;; ============================================================
;;; Type-checking helpers (from _api.check_isinstance etc.)
;;; ============================================================

(define-condition check-error (simple-error)
  ()
  (:documentation "Signalled by check-* functions when validation fails."))

(defun check-isinstance (value &rest types)
  "Check that VALUE is an instance of one of TYPES. Signals CHECK-ERROR if not.
TYPES are CL type specifiers (symbols like 'integer, 'string, etc.).
NIL in TYPES is treated as the null type."
  (let ((resolved-types (mapcar (lambda (tp)
                                  (if (null tp) 'null tp))
                                types)))
    (unless (some (lambda (tp) (typep value tp)) resolved-types)
      (error 'check-error
             :format-control "~S must be an instance of ~{~A~^, or ~}, not ~A"
             :format-arguments (list value resolved-types (type-of value))))))

(defun check-in-list (value valid-values &key (key nil) (print-supported-values t))
  "Check that VALUE is a member of VALID-VALUES. Signals CHECK-ERROR if not.
KEY is an optional label for the value in error messages."
  (unless (member value valid-values :test #'equal)
    (let ((msg (format nil "~S is not a valid value~@[ for ~A~]" value key)))
      (when print-supported-values
        (setf msg (format nil "~A; supported values are ~{~S~^, ~}" msg valid-values)))
      (error 'check-error
             :format-control "~A"
             :format-arguments (list msg)))))

(defun check-shape (array expected-shape &key (key "array"))
  "Check that ARRAY has the EXPECTED-SHAPE (list of dimensions).
NIL in EXPECTED-SHAPE means any size for that dimension.
ARRAY should be a CL array."
  (let ((actual-shape (array-dimensions array)))
    (unless (and (= (length actual-shape) (length expected-shape))
                 (every (lambda (actual expected)
                          (or (null expected) (= actual expected)))
                        actual-shape expected-shape))
      (error 'check-error
             :format-control "~A must be ~DD with shape ~S, but has shape ~S"
             :format-arguments (list key (length expected-shape)
                                     expected-shape actual-shape)))))

;;; ============================================================
;;; ls-mapper — line style aliases
;;; ============================================================

(defparameter *ls-mapper*
  '(("-"       . :solid)
    ("--"      . :dashed)
    ("-."      . :dashdot)
    (":"       . :dotted)
    ("solid"   . :solid)
    ("dashed"  . :dashed)
    ("dashdot" . :dashdot)
    ("dotted"  . :dotted))
  "Alist mapping matplotlib line style strings to CL keyword symbols.")

(defun ls-mapper (style-string)
  "Map a line style string (e.g. \"--\") to a keyword symbol (e.g. :DASHED).
Returns NIL if not found."
  (cdr (assoc style-string *ls-mapper* :test #'string-equal)))

;;; ============================================================
;;; normalize-kwargs — keyword argument normalization
;;; ============================================================

(defparameter *kwarg-aliases*
  '((:c . :color)
    (:lw . :linewidth)
    (:ls . :linestyle)
    (:fc . :facecolor)
    (:ec . :edgecolor)
    (:mfc . :markerfacecolor)
    (:mec . :markeredgecolor)
    (:mew . :markeredgewidth)
    (:ms . :markersize))
  "Alist mapping short keyword aliases to canonical keyword names.")

(defun normalize-kwargs (plist &optional (aliases *kwarg-aliases*))
  "Normalize a keyword plist by expanding aliases.
E.g., (:lw 2 :color \"red\") → (:linewidth 2 :color \"red\").
Signals an error if both alias and canonical name are present."
  (let ((result '())
        (seen (make-hash-table :test 'eq)))
    (loop for (key val) on plist by #'cddr do
      (let* ((canonical (or (cdr (assoc key aliases :test #'eq)) key))
             (existing (gethash canonical seen)))
        (when existing
          (error 'check-error
                 :format-control "Cannot specify both ~S and its alias for ~S"
                 :format-arguments (list key canonical)))
        (setf (gethash canonical seen) t)
        (push canonical result)
        (push val result)))
    (nreverse result)))

;;; ============================================================
;;; silent-list — a list that prints compactly
;;; ============================================================

(defstruct (silent-list (:constructor make-silent-list (type &optional items)))
  "A list wrapper that prints a summary instead of all elements."
  (type "items" :type string)
  (items '() :type list))

(defmethod print-object ((sl silent-list) stream)
  (print-unreadable-object (sl stream :type nil)
    (format stream "~A list of ~D ~A"
            (silent-list-type sl)
            (length (silent-list-items sl))
            (silent-list-type sl))))

;;; ============================================================
;;; Dict/list utilities
;;; ============================================================

(defun flatten (lst)
  "Flatten a nested list one level.
E.g. ((1 2) (3 4)) → (1 2 3 4)."
  (loop for item in lst
        if (listp item) append item
        else collect item))

(defun safe-first (sequence)
  "Return the first element of SEQUENCE, or NIL if empty."
  (if (and sequence (> (length sequence) 0))
      (elt sequence 0)
      nil))

(defun pairwise (list)
  "Return a list of consecutive pairs.
E.g. (1 2 3 4) → ((1 2) (2 3) (3 4))."
  (loop for (a b) on list while b collect (list a b)))

(defun index-of (item sequence &key (test #'eql))
  "Return the index of ITEM in SEQUENCE, or NIL if not found."
  (position item sequence :test test))

;;; ============================================================
;;; String utilities (adapted from cbook/_api)
;;; ============================================================

(defun str-lower-equal (a b)
  "Case-insensitive string comparison. Returns T if A and B are
 strings that are equal ignoring case."
  (and (stringp a) (stringp b) (string-equal a b)))

(defun str-equal (a b)
  "Case-sensitive string comparison. Returns T if A and B are
 strings that are equal."
  (and (stringp a) (stringp b) (string= a b)))
