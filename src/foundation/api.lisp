;;;; api.lisp — Deprecation warning system and caching utilities
;;;; Ported from matplotlib._api

(in-package #:cl-matplotlib.api)

;;; ============================================================
;;; Deprecation warning system
;;; ============================================================

(define-condition matplotlib-deprecation-warning (simple-warning)
  ((since :initarg :since :reader deprecation-since
          :documentation "Version since which the feature is deprecated.")
   (name :initarg :name :reader deprecation-name :initform nil
         :documentation "Name of the deprecated feature.")
   (removal :initarg :removal :reader deprecation-removal :initform nil
            :documentation "Version in which the feature will be removed."))
  (:documentation "Warning for deprecated matplotlib features.")
  (:report (lambda (c stream)
             (format stream "~A~@[ (deprecated since ~A)~]~@[, will be removed in ~A~]"
                     (simple-condition-format-control c)
                     (deprecation-since c)
                     (deprecation-removal c)))))

(defun warn-deprecated (since &key name message removal)
  "Issue a deprecation warning.
SINCE is the version string when deprecation started.
NAME is the deprecated feature name.
MESSAGE is an optional custom message."
  (let ((msg (or message
                 (format nil "~@[~A is~] deprecated since version ~A~@[; will be removed in ~A~]."
                         name since removal))))
    (warn 'matplotlib-deprecation-warning
          :since since
          :name name
          :removal removal
          :format-control "~A"
          :format-arguments (list msg))))

(defmacro suppress-matplotlib-deprecation-warning (&body body)
  "Execute BODY with matplotlib deprecation warnings muffled."
  `(handler-bind ((matplotlib-deprecation-warning #'muffle-warning))
     ,@body))

(defmacro deprecated (since &key name message removal)
  "Macro to mark a function as deprecated. Wraps the function to emit a warning."
  (declare (ignore since name message removal))
  ;; For now, this is a no-op placeholder. Full implementation would wrap functions.
  `(progn))

;;; ============================================================
;;; Caching utilities
;;; ============================================================

(defmacro define-cached-function (name args &body body)
  "Define a memoized function. Results are cached in a hash table keyed by args.
Adapted from Python's functools.lru_cache for CL patterns."
  (let ((cache (gensym "CACHE"))
        (sentinel (gensym "SENTINEL"))
        (key (gensym "KEY"))
        (result (gensym "RESULT")))
    `(let ((,cache (make-hash-table :test 'equal)))
       (defun ,name ,args
         (let* ((,key (list ,@args))
                (,sentinel ',sentinel)
                (,result (gethash ,key ,cache ,sentinel)))
           (if (eq ,result ,sentinel)
               (setf (gethash ,key ,cache)
                     (progn ,@body))
               ,result))))))

(defun clear-cache (fn-name)
  "Clear the cache for a cached function (placeholder — actual clearing depends on implementation)."
  (declare (ignore fn-name))
  ;; In a real implementation, we'd store caches in a registry.
  ;; For now this is a no-op.
  (values))

;;; ============================================================
;;; Sentinel value (like Python's _api.UNSET)
;;; ============================================================

(defstruct (unset-type (:constructor %make-unset))
  "Sentinel value for unset optional arguments.")

(defvar *unset* (%make-unset)
  "Sentinel value for optional arguments where NIL is a valid value.")

(defmethod print-object ((obj unset-type) stream)
  (print-unreadable-object (obj stream :type nil)
    (write-string "UNSET" stream)))

(defun unsetp (value)
  "Return T if VALUE is the UNSET sentinel."
  (unset-type-p value))

;;; ============================================================
;;; Misc helpers
;;; ============================================================

(defun nargs-error (func-name expected got)
  "Signal a simple error about wrong number of arguments."
  (error "~A() takes ~A positional arguments but ~A were given"
         func-name expected got))

(defun getitem-checked (mapping key &key (error-cls 'simple-error))
  "Look up KEY in MAPPING (hash table). If not found, signal ERROR-CLS with
a helpful message suggesting close matches."
  (multiple-value-bind (value found) (gethash key mapping)
    (if found
        value
        (let* ((keys (loop for k being the hash-keys of mapping collect k))
               (close (remove-if-not (lambda (k)
                                       (and (stringp k) (stringp key)
                                            (<= (levenshtein-distance k key) 3)))
                                     keys)))
          (error error-cls
                 :format-control "~S is not a valid key~@[; did you mean ~{~S~^, ~}?~]"
                 :format-arguments (list key (when close close)))))))

(defun levenshtein-distance (s1 s2)
  "Compute the Levenshtein edit distance between strings S1 and S2."
  (let* ((n (length s1))
         (m (length s2))
         (d (make-array (list (1+ n) (1+ m)) :element-type 'fixnum :initial-element 0)))
    (loop for i from 0 to n do (setf (aref d i 0) i))
    (loop for j from 0 to m do (setf (aref d 0 j) j))
    (loop for i from 1 to n do
      (loop for j from 1 to m do
        (let ((cost (if (char= (char s1 (1- i)) (char s2 (1- j))) 0 1)))
          (setf (aref d i j)
                (min (1+ (aref d (1- i) j))
                     (1+ (aref d i (1- j)))
                     (+ (aref d (1- i) (1- j)) cost))))))
    (aref d n m)))
