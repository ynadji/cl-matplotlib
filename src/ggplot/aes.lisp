;;;; aes.lisp — aesthetic mappings

(in-package #:ggplot)

(defparameter *known-aesthetics*
  '(:x :y :xmin :xmax :ymin :ymax :xend :yend :xintercept :yintercept
    :color :colour :fill :size :shape :alpha :linetype :group :label
    :stroke :weight :sample :intercept :slope :lower :middle :upper
    :width :height)
  "Aesthetic names accepted by aes. :colour is canonicalized to :color.")

(defclass aesthetic-mapping ()
  ((alist :initarg :alist :reader aes-alist
          :documentation "Alist of aesthetic keyword -> column reference."))
  (:documentation "A set of aesthetic mappings from data columns (or functions
of the data) to visual properties."))

(defmethod print-object ((m aesthetic-mapping) stream)
  (print-unreadable-object (m stream :type t)
    (format stream "~{~(~a~)=~a~^ ~}"
            (loop for (k . v) in (aes-alist m) append (list k v)))))

(defun %canonicalize-aesthetic (key)
  (let ((key (if (eq key :colour) :color key)))
    (unless (member key *known-aesthetics*)
      (error "Unknown aesthetic ~S. Known aesthetics: ~{~S~^ ~}"
             key *known-aesthetics*))
    key))

(defun make-aesthetic-mapping (plist)
  (make-instance
   'aesthetic-mapping
   :alist (loop for (k v) on plist by #'cddr
                collect (cons (%canonicalize-aesthetic k) v))))

(defgeneric aes (first &rest more)
  (:documentation "Construct an aesthetic mapping.

Standard forms (FIRST is a keyword or a column reference):
  (aes :x :wt :y :mpg :color :cyl)   ; explicit plist
  (aes :wt :mpg :color :cyl)         ; positional x, y  [only when :wt names a column]
Column references are keywords/symbols/strings naming columns, functions of
the data table (must return a column-length sequence or a scalar), or
constants. Specialize this generic on your own mapping-spec class to plug
in custom mapping syntaxes."))

(defmethod aes (first &rest more)
  (make-aesthetic-mapping
   (cond
     ;; Pure plist form: (aes :x ... :y ...) — first is a known aesthetic key
     ((and (keywordp first)
           (member (if (eq first :colour) :color first) *known-aesthetics*)
           (oddp (length more)))
      (cons first more))
     ;; Positional: (aes xref yref &rest plist)
     ((and more (not (and (keywordp (car more))
                          (member (car more) *known-aesthetics*))))
      (list* :x first :y (car more) (cdr more)))
     ;; Positional x only: (aes xref &rest plist)
     (t (list* :x first more)))))

(defun aes-ref (mapping aesthetic)
  "The column reference mapped to AESTHETIC, or NIL."
  (cdr (assoc aesthetic (aes-alist mapping))))

(defun merge-aes (parent child)
  "Merge two aesthetic mappings; CHILD entries win. Either may be NIL."
  (cond ((null parent) child)
        ((null child) parent)
        (t (make-instance
            'aesthetic-mapping
            :alist (append (aes-alist child)
                           (remove-if (lambda (e)
                                        (assoc (car e) (aes-alist child)))
                                      (aes-alist parent)))))))

;;; ============================================================
;;; after-stat — deferred aesthetic resolved after the stat step
;;; ============================================================

(defstruct (after-stat-ref (:constructor after-stat (name)))
  "Marker for an aesthetic computed by the layer's stat, e.g.
(aes :y (after-stat :density))."
  name)

;;; ============================================================
;;; Evaluating references against a gtable
;;; ============================================================

(defun eval-aesthetic (ref table)
  "Evaluate column reference REF against TABLE (a gtable).
Returns a simple vector of gtable-nrows values, or an after-stat-ref
marker (resolved later), or NIL."
  (let ((n (gtable-nrows table)))
    (etypecase ref
      (null nil)
      (after-stat-ref ref)
      (function
       (let ((result (funcall ref table)))
         (if (typep result 'sequence)
             (let ((vec (coerce result 'simple-vector)))
               (if (= (length vec) n)
                   vec
                   (error "Computed aesthetic returned ~D values for ~D rows"
                          (length vec) n)))
             (make-array n :initial-element result))))
      ((or keyword (and symbol (not null)) string)
       (let ((col (gtable-column table (normalize-column-name ref))))
         (if col
             col
             ;; A symbol/string that names no column is an error; only
             ;; self-evaluating constants recycle silently.
             (error "No column named ~S in data (columns: ~{~S~^ ~})"
                    ref (gtable-column-names table)))))
      ((or number character)
       (make-array n :initial-element ref)))))
