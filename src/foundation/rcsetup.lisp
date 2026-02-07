;;;; rcsetup.lisp — RC parameter system with validators
;;;; Ported from matplotlib.rcsetup and matplotlib.RcParams

(in-package #:cl-matplotlib.rc)

;;; ============================================================
;;; Conditions
;;; ============================================================

(define-condition rc-validation-error (simple-error)
  ((key :initarg :key :reader rc-validation-error-key :initform nil)
   (value :initarg :value :reader rc-validation-error-value :initform nil))
  (:documentation "Signalled when an rcParams value fails validation.")
  (:report (lambda (c stream)
             (format stream "Key ~S: ~A"
                     (rc-validation-error-key c)
                     (apply #'format nil
                            (simple-condition-format-control c)
                            (simple-condition-format-arguments c))))))

(define-condition rc-key-error (simple-error)
  ()
  (:documentation "Signalled when an rcParams key is not recognized."))

;;; ============================================================
;;; Validator functions (ported from rcsetup.py)
;;; ============================================================

(defun validate-any (value)
  "Accept any value."
  value)

(defun validate-bool (value)
  "Convert VALUE to boolean or signal error."
  (cond
    ((member value '(t :true) :test #'eq) t)
    ((member value '(nil :false) :test #'eq) nil)
    ((stringp value)
     (let ((lower (string-downcase value)))
       (cond
         ((member lower '("t" "y" "yes" "on" "true" "1") :test #'string=) t)
         ((member lower '("f" "n" "no" "off" "false" "0") :test #'string=) nil)
         (t (error 'rc-validation-error
                   :format-control "Cannot convert ~S to bool"
                   :format-arguments (list value))))))
    ((eql value 1) t)
    ((eql value 0) nil)
    (t (error 'rc-validation-error
              :format-control "Cannot convert ~S to bool"
              :format-arguments (list value)))))

(defun validate-float (value)
  "Convert VALUE to a float or signal error."
  (cond
    ((floatp value) value)
    ((numberp value) (float value 1.0d0))
    ((stringp value)
     (let ((parsed (ignore-errors (read-from-string value))))
       (if (numberp parsed)
           (float parsed 1.0d0)
           (error 'rc-validation-error
                  :format-control "Could not convert ~S to float"
                  :format-arguments (list value)))))
    (t (error 'rc-validation-error
              :format-control "Could not convert ~S to float"
              :format-arguments (list value)))))

(defun validate-float-or-none (value)
  "Convert VALUE to float or NIL."
  (if (or (null value) (and (stringp value) (string-equal value "None")))
      nil
      (validate-float value)))

(defun validate-int (value)
  "Convert VALUE to an integer or signal error."
  (cond
    ((integerp value) value)
    ((numberp value) (round value))
    ((stringp value)
     (let ((parsed (ignore-errors (read-from-string value))))
       (if (integerp parsed)
           parsed
           (error 'rc-validation-error
                  :format-control "Could not convert ~S to int"
                  :format-arguments (list value)))))
    (t (error 'rc-validation-error
              :format-control "Could not convert ~S to int"
              :format-arguments (list value)))))

(defun validate-int-or-none (value)
  "Convert VALUE to int or NIL."
  (if (or (null value) (and (stringp value) (string-equal value "None")))
      nil
      (validate-int value)))

(defun validate-string (value)
  "Ensure VALUE is a string."
  (cond
    ((stringp value) value)
    (t (error 'rc-validation-error
              :format-control "Could not convert ~S to string"
              :format-arguments (list value)))))

(defun validate-string-or-none (value)
  "Convert VALUE to string or NIL."
  (if (or (null value) (and (stringp value) (string-equal value "None")))
      nil
      (validate-string value)))

(defun validate-positive-float (value)
  "Validate that VALUE is a positive float."
  (let ((f (validate-float value)))
    (if (> f 0.0d0)
        f
        (error 'rc-validation-error
               :format-control "Value must be positive; got ~S"
               :format-arguments (list f)))))

(defun validate-non-negative-float (value)
  "Validate that VALUE is a non-negative float."
  (let ((f (validate-float value)))
    (if (>= f 0.0d0)
        f
        (error 'rc-validation-error
               :format-control "Value must be >= 0; got ~S"
               :format-arguments (list f)))))

(defun validate-float-0-to-1 (value)
  "Validate that VALUE is a float in [0, 1]."
  (let ((f (validate-float value)))
    (if (<= 0.0d0 f 1.0d0)
        f
        (error 'rc-validation-error
               :format-control "Value must be >= 0 and <= 1; got ~S"
               :format-arguments (list f)))))

(defun validate-non-negative-int (value)
  "Validate that VALUE is a non-negative integer."
  (let ((i (validate-int value)))
    (if (>= i 0)
        i
        (error 'rc-validation-error
               :format-control "Value must be >= 0; got ~S"
               :format-arguments (list i)))))

(defun validate-dpi (value)
  "Validate DPI: either the string \"figure\" or a positive float."
  (if (and (stringp value) (string-equal value "figure"))
      "figure"
      (validate-positive-float value)))

(defun validate-fontsize (value)
  "Validate font size: named size or float."
  (let ((named-sizes '("xx-small" "x-small" "small" "medium"
                        "large" "x-large" "xx-large" "smaller" "larger")))
    (if (and (stringp value) (member (string-downcase value) named-sizes :test #'string=))
        (string-downcase value)
        (validate-float value))))

(defun validate-fontsize-or-none (value)
  "Validate font size or None."
  (if (or (null value) (and (stringp value) (string-equal value "None")))
      nil
      (validate-fontsize value)))

(defun validate-fontweight (value)
  "Validate font weight: named weight or integer 100-900."
  (let ((named '("ultralight" "light" "normal" "regular" "book" "medium"
                 "roman" "semibold" "demibold" "demi" "bold" "heavy"
                 "extra bold" "black")))
    (cond
      ((and (stringp value) (member value named :test #'string-equal))
       value)
      ((integerp value) value)
      ((stringp value)
       (handler-case (validate-int value)
         (rc-validation-error ()
           (error 'rc-validation-error
                  :format-control "~S is not a valid font weight"
                  :format-arguments (list value)))))
      (t (error 'rc-validation-error
                :format-control "~S is not a valid font weight"
                :format-arguments (list value))))))

(defun validate-fontstretch (value)
  "Validate font stretch: named stretch or integer."
  (let ((stretches '("ultra-condensed" "extra-condensed" "condensed"
                      "semi-condensed" "normal" "semi-expanded" "expanded"
                      "extra-expanded" "ultra-expanded")))
    (cond
      ((and (stringp value) (member value stretches :test #'string-equal))
       value)
      ((integerp value) value)
      (t (error 'rc-validation-error
                :format-control "~S is not a valid font stretch"
                :format-arguments (list value))))))

(defun validate-color (value)
  "Validate a color value. Accepts named colors, hex strings, or RGBA vectors."
  (cond
    ;; NIL / "none"
    ((null value) "none")
    ((and (stringp value) (string-equal value "none")) "none")
    ;; Hex string #RRGGBB or #RRGGBBAA
    ((and (stringp value) (> (length value) 0) (char= (char value 0) #\#)
          (member (length value) '(7 9)))
     value)
    ;; 6 or 8 char hex without #
    ((and (stringp value) (member (length value) '(6 8))
          (every (lambda (c) (digit-char-p c 16)) value))
     (concatenate 'string "#" value))
    ;; Named color string (pass through; actual resolution done in colors module)
    ((stringp value) value)
    ;; RGBA vector
    ((and (vectorp value) (member (length value) '(3 4)))
     value)
    ;; RGB/RGBA list
    ((and (listp value) (member (length value) '(3 4))
          (every #'numberp value))
     (coerce value 'vector))
    (t (error 'rc-validation-error
              :format-control "~S does not look like a color arg"
              :format-arguments (list value)))))

(defun validate-color-or-auto (value)
  "Validate color or the string \"auto\"."
  (if (and (stringp value) (string-equal value "auto"))
      "auto"
      (validate-color value)))

(defun validate-color-or-inherit (value)
  "Validate color or the string \"inherit\"."
  (if (and (stringp value) (string-equal value "inherit"))
      "inherit"
      (validate-color value)))

(defun validate-color-or-none (value)
  "Validate color or None."
  (if (or (null value) (and (stringp value) (string-equal value "None")))
      nil
      (validate-color value)))

(defun validate-linestyle (value)
  "Validate a line style. Returns keyword symbol."
  (cond
    ((keywordp value)
     (unless (member value '(:solid :dashed :dashdot :dotted))
       (error 'rc-validation-error
              :format-control "~S is not a valid linestyle keyword"
              :format-arguments (list value)))
     value)
    ((stringp value)
     (let ((ls (cl-matplotlib.cbook:ls-mapper value)))
       (or ls
           (cond
             ((string-equal value "none") :none)
             ((string= value "") :none)
             ((string= value " ") :none)
             (t (error 'rc-validation-error
                       :format-control "~S is not a valid linestyle"
                       :format-arguments (list value)))))))
    (t (error 'rc-validation-error
              :format-control "~S is not a valid linestyle"
              :format-arguments (list value)))))

(defun validate-linestyle-or-none (value)
  "Validate linestyle or None."
  (if (or (null value) (and (stringp value) (string-equal value "None")))
      nil
      (validate-linestyle value)))

(defun validate-joinstyle (value)
  "Validate a join style. Returns keyword symbol."
  (let ((valid '(:miter :round :bevel)))
    (cond
      ((and (keywordp value) (member value valid)) value)
      ((stringp value)
       (let ((kw (intern (string-upcase value) :keyword)))
         (if (member kw valid)
             kw
             (error 'rc-validation-error
                    :format-control "~S is not a valid join style; use ~S"
                    :format-arguments (list value valid)))))
      (t (error 'rc-validation-error
                :format-control "~S is not a valid join style"
                :format-arguments (list value))))))

(defun validate-capstyle (value)
  "Validate a cap style. Returns keyword symbol."
  (let ((valid '(:butt :round :projecting)))
    (cond
      ((and (keywordp value) (member value valid)) value)
      ((stringp value)
       (let ((kw (intern (string-upcase value) :keyword)))
         (if (member kw valid)
             kw
             (error 'rc-validation-error
                    :format-control "~S is not a valid cap style; use ~S"
                    :format-arguments (list value valid)))))
      (t (error 'rc-validation-error
                :format-control "~S is not a valid cap style"
                :format-arguments (list value))))))

(defun validate-aspect (value)
  "Validate aspect ratio: 'auto', 'equal', or a number."
  (cond
    ((and (stringp value) (member value '("auto" "equal") :test #'string-equal))
     value)
    ((numberp value) (float value 1.0d0))
    ((stringp value)
     (handler-case (validate-float value)
       (rc-validation-error ()
         (error 'rc-validation-error
                :format-control "~S is not a valid aspect specification"
                :format-arguments (list value)))))
    (t (error 'rc-validation-error
              :format-control "~S is not a valid aspect specification"
              :format-arguments (list value)))))

(defun validate-bbox (value)
  "Validate bbox: 'tight', 'standard' (= nil), or nil."
  (cond
    ((null value) nil)
    ((and (stringp value) (string-equal value "tight")) "tight")
    ((and (stringp value) (string-equal value "standard")) nil)
    (t (error 'rc-validation-error
              :format-control "bbox should be 'tight' or 'standard'"
              :format-arguments nil))))

(defun validate-fonttype (value)
  "Validate PS/PDF font type: 3 (Type3) or 42 (TrueType)."
  (let ((fonttypes '(("type3" . 3) ("truetype" . 42))))
    (cond
      ((and (integerp value) (member value '(3 42))) value)
      ((stringp value)
       (let ((entry (assoc (string-downcase value) fonttypes :test #'string=)))
         (if entry
             (cdr entry)
             (handler-case
                 (let ((i (validate-int value)))
                   (if (member i '(3 42))
                       i
                       (error 'rc-validation-error
                              :format-control "Supported font types are 3 and 42"
                              :format-arguments nil)))
               (rc-validation-error ()
                 (error 'rc-validation-error
                        :format-control "Supported font types are 3 and 42"
                        :format-arguments nil))))))
      (t (error 'rc-validation-error
                :format-control "Supported font types are 3 and 42"
                :format-arguments nil)))))

(defun validate-stringlist (value)
  "Validate and return a list of strings. If VALUE is a string, split by commas."
  (cond
    ((listp value) (mapcar #'validate-string value))
    ((stringp value)
     (mapcar (lambda (s) (string-trim '(#\Space #\Tab) s))
             (remove "" (uiop:split-string value :separator ",") :test #'string=)))
    (t (error 'rc-validation-error
              :format-control "Expected string or list of strings, got ~S"
              :format-arguments (list value)))))

(defun validate-floatlist (value)
  "Validate and return a list of floats."
  (cond
    ((listp value) (mapcar #'validate-float value))
    ((stringp value)
     (mapcar #'validate-float
             (remove "" (mapcar (lambda (s) (string-trim '(#\Space #\Tab) s))
                                (uiop:split-string value :separator ","))
                     :test #'string=)))
    (t (error 'rc-validation-error
              :format-control "Expected list of floats, got ~S"
              :format-arguments (list value)))))

(defun validate-intlist (value)
  "Validate and return a list of ints (exactly 2)."
  (let ((result (cond
                  ((listp value) (mapcar #'validate-int value))
                  ((stringp value)
                   (mapcar #'validate-int
                           (remove "" (mapcar (lambda (s) (string-trim '(#\Space #\Tab) s))
                                              (uiop:split-string value :separator ","))
                                   :test #'string=)))
                  (t (error 'rc-validation-error
                            :format-control "Expected list of ints, got ~S"
                            :format-arguments (list value))))))
    (unless (= (length result) 2)
      (error 'rc-validation-error
             :format-control "Expected 2 values, got ~D"
             :format-arguments (list (length result))))
    result))

(defun make-validate-in-strings (key valid-values &key (ignorecase nil))
  "Create a validator that accepts only strings in VALID-VALUES."
  (lambda (value)
    (let* ((s (if (stringp value) value (format nil "~A" value)))
           (test-val (if ignorecase (string-downcase s) s))
           (valid-map (mapcar (lambda (v)
                                (cons (if ignorecase (string-downcase v) v) v))
                              valid-values)))
      (let ((entry (assoc test-val valid-map :test #'string=)))
        (if entry
            (cdr entry)
            (error 'rc-validation-error
                   :format-control "~S is not a valid value for ~A; supported values are ~S"
                   :format-arguments (list value key valid-values)))))))

(defun validate-axisbelow (value)
  "Validate axisbelow: True, False, or 'line'."
  (handler-case (validate-bool value)
    (rc-validation-error ()
      (if (and (stringp value) (string-equal value "line"))
          "line"
          (error 'rc-validation-error
                 :format-control "~S cannot be interpreted as True, False, or \"line\""
                 :format-arguments (list value))))))

(defun validate-sketch (value)
  "Validate sketch: None or (scale length randomness) tuple."
  (cond
    ((null value) nil)
    ((and (stringp value)
          (or (string-equal value "none") (string= value "")))
     nil)
    ((and (listp value) (= (length value) 3)
          (every #'numberp value))
     (mapcar (lambda (v) (float v 1.0d0)) value))
    ((stringp value)
     ;; Try parsing as a tuple-like string
     (let ((cleaned (string-trim '(#\Space #\Tab #\( #\)) value)))
       (handler-case
           (let ((floats (validate-floatlist cleaned)))
             (unless (= (length floats) 3)
               (error 'rc-validation-error
                      :format-control "Expected (scale, length, randomness) tuple"
                      :format-arguments nil))
             floats)
         (rc-validation-error ()
           (error 'rc-validation-error
                  :format-control "Expected a (scale, length, randomness) tuple"
                  :format-arguments nil)))))
    (t (error 'rc-validation-error
              :format-control "Expected None or (scale, length, randomness) tuple"
              :format-arguments (list value)))))

(defun validate-marker (value)
  "Validate a marker specification."
  (cond
    ((or (null value) (and (stringp value) (string-equal value "None"))) nil)
    ((integerp value) value)
    ((stringp value) value)
    ((keywordp value) value)
    (t (error 'rc-validation-error
              :format-control "~S is not a valid marker"
              :format-arguments (list value)))))

(defun validate-fillstyle (value)
  "Validate a fill style."
  (let ((valid '("full" "left" "right" "bottom" "top" "none")))
    (if (and (stringp value) (member value valid :test #'string-equal))
        value
        (error 'rc-validation-error
               :format-control "~S is not a valid fillstyle; use ~S"
               :format-arguments (list value valid)))))

(defun validate-pathlike (value)
  "Validate a path-like value."
  (cond
    ((stringp value) value)
    ((pathnamep value) (namestring value))
    (t (validate-string value))))

(defun validate-hatch (value)
  "Validate a hatch pattern string."
  (unless (stringp value)
    (error 'rc-validation-error
           :format-control "Hatch pattern must be a string"
           :format-arguments nil))
  value)

;;; ============================================================
;;; RC Parameter Store
;;; ============================================================

(defvar *rc-validators* (make-hash-table :test 'equal)
  "Hash table mapping parameter name (string) to validator function.")

(defvar *rc-params* (make-hash-table :test 'equal)
  "Hash table storing current rcParams values. Key = string, Value = validated value.")

(defvar *rc-defaults* (make-hash-table :test 'equal)
  "Hash table storing default rcParams values.")

(defun register-rc-param (name default-value validator)
  "Register an RC parameter with its default value and validator function."
  (setf (gethash name *rc-validators*) validator)
  (let ((validated (funcall validator default-value)))
    (setf (gethash name *rc-defaults*) validated)
    (setf (gethash name *rc-params*) validated)))

(defmacro define-rc-param (name default-value validator &optional documentation)
  "Macro to register an rc parameter with name, default, and validator.
NAME is a string like \"lines.linewidth\".
DEFAULT-VALUE is the default.
VALIDATOR is a function designator."
  (declare (ignore documentation))
  `(register-rc-param ,name ,default-value ,validator))

;;; ============================================================
;;; RC Accessor (setf-able)
;;; ============================================================

(defun rc (key)
  "Get the current value of rcParam KEY (a string).
Signals RC-KEY-ERROR if key is not recognized."
  (multiple-value-bind (value found) (gethash key *rc-params*)
    (unless found
      (error 'rc-key-error
             :format-control "~S is not a valid rcParam key"
             :format-arguments (list key)))
    value))

(defun (setf rc) (value key)
  "Set the rcParam KEY to VALUE after validation.
Signals RC-VALIDATION-ERROR if validation fails."
  (multiple-value-bind (validator found) (gethash key *rc-validators*)
    (unless found
      (error 'rc-key-error
             :format-control "~S is not a valid rcParam key"
             :format-arguments (list key)))
    (handler-case
        (let ((validated (funcall validator value)))
          (setf (gethash key *rc-params*) validated)
          validated)
      (rc-validation-error (e)
        (error 'rc-validation-error
               :key key
               :value value
               :format-control "~A"
               :format-arguments (list (format nil "~A" e)))))))

;;; ============================================================
;;; with-rc — Dynamic rebinding of rcParams
;;; ============================================================

(defmacro with-rc (bindings &body body)
  "Temporarily rebind rcParams for the duration of BODY.
BINDINGS is a list of (key value) pairs where key is a string.
Restores original values on exit, even on non-local exit.

Example:
  (with-rc ((\"lines.linewidth\" 3.0)
            (\"lines.color\" \"blue\"))
    (rc \"lines.linewidth\"))  ; → 3.0"
  (let ((saved (gensym "SAVED")))
    `(let ((,saved (list ,@(loop for (key _val) in bindings
                                 collect `(cons ,key (rc ,key))))))
       (unwind-protect
            (progn
              ,@(loop for (key val) in bindings
                      collect `(setf (rc ,key) ,val))
              ,@body)
         (dolist (pair ,saved)
           (setf (gethash (car pair) *rc-params*) (cdr pair)))))))

;;; ============================================================
;;; Utility functions
;;; ============================================================

(defun rc-reset ()
  "Reset all rcParams to their default values."
  (maphash (lambda (key value)
             (setf (gethash key *rc-params*) value))
           *rc-defaults*))

(defun rc-defaults ()
  "Reset all rcParams to their default values. Alias for rc-reset."
  (rc-reset))

(defun rc-update (alist)
  "Update rcParams from an alist of (key . value) pairs, validating each."
  (dolist (pair alist)
    (setf (rc (car pair)) (cdr pair))))

(defun rc-find-all (pattern)
  "Return an alist of rcParams whose keys match PATTERN (a string, matched with search)."
  (let ((results '()))
    (maphash (lambda (key value)
               (when (search pattern key :test #'char-equal)
                 (push (cons key value) results)))
             *rc-params*)
    (sort results #'string< :key #'car)))

;;; ============================================================
;;; rc-context — Temporary parameter override
;;; ============================================================

(defmacro rc-context (bindings &body body)
  "Temporarily override rcParams for the duration of BODY.
BINDINGS is a list of (key value) pairs where key is a string.
Restores original values on exit, even on non-local exit.

Example:
  (rc-context ((\"lines.linewidth\" 3.0)
               (\"lines.color\" \"blue\"))
    (plot x y))  ; Uses linewidth=3.0, color=blue
  ;; Restored to original after"
  (let ((saved (gensym "SAVED")))
    `(let ((,saved (list ,@(loop for (key _val) in bindings
                                 collect `(cons ,key (rc ,key))))))
       (unwind-protect
            (progn
              ,@(loop for (key val) in bindings
                      collect `(setf (rc ,key) ,val))
              ,@body)
         (dolist (pair ,saved)
           (setf (gethash (car pair) *rc-params*) (cdr pair)))))))

;;; ============================================================
;;; File I/O functions
;;; ============================================================

(defun rc-from-file (filename)
  "Load rcParams from a matplotlibrc file.
Returns (values applied-count skipped-count).
Uses the parser from matplotlibrc-parser.lisp."
  (let ((pairs (parse-matplotlibrc filename))
        (applied 0)
        (skipped 0))
    (dolist (pair pairs)
      (let ((key (car pair))
            (val (cdr pair)))
        (if (gethash key *rc-validators*)
            (handler-case
                (progn
                  (setf (rc key) val)
                  (incf applied))
              (error (e)
                (warn "Could not set ~S to ~S: ~A" key val e)
                (incf skipped)))
            (progn
              ;; Unknown key, skip silently
              (incf skipped)))))
    (values applied skipped)))

(defun rc-params-to-file (filename)
  "Write current rcParams to a matplotlibrc file.
Organizes params by category with comments."
  (with-open-file (stream filename :direction :output
                                   :if-exists :supersede
                                   :if-does-not-exist :create)
    (format stream "#### MATPLOTLIBRC FORMAT~%")
    (format stream "## Generated by cl-matplotlib~%")
    (format stream "## Format: key : value~%~%")
    
    ;; Collect all params and sort by key
    (let ((params '()))
      (maphash (lambda (key value)
                 (push (cons key value) params))
               *rc-params*)
      (setf params (sort params #'string< :key #'car))
      
      ;; Group by category (prefix before first dot)
      (let ((current-category nil))
        (dolist (pair params)
          (let* ((key (car pair))
                 (value (cdr pair))
                 (category (subseq key 0 (or (position #\. key) (length key)))))
            ;; Print category header if changed
            (unless (string= category (or current-category ""))
              (format stream "~%## ~A~%" (string-upcase category))
              (setf current-category category))
            ;; Print param
            (format stream "~A: ~A~%" key (format-rc-value value))))))
    (truename filename)))

(defun format-rc-value (value)
  "Format an rcParam value for writing to file."
  (cond
    ((null value) "None")
    ((eq value t) "True")
    ((eq value nil) "False")
    ((stringp value) value)
    ((numberp value) (format nil "~A" value))
    ((listp value)
     ;; Format list as comma-separated
     (format nil "~{~A~^, ~}" (mapcar #'format-rc-value value)))
    ((vectorp value)
     ;; Format vector as comma-separated
     (format nil "~{~A~^, ~}" (coerce value 'list)))
    ((keywordp value) (string-downcase (symbol-name value)))
    (t (format nil "~A" value))))
