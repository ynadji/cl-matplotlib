;;;; style.lisp — Style sheet system for easy plot styling
;;;; Ported from matplotlib.style.core

(in-package #:cl-matplotlib.rc)

;;; ============================================================
;;; Style sheet management
;;; ============================================================

(defvar *style-cache* (make-hash-table :test #'equal)
  "Cache of loaded style sheets (name -> params alist).")

(defvar *stylelib-path* nil
  "Path to stylelib directory. Set during initialization.")

(defun initialize-stylelib-path ()
  "Initialize the stylelib path relative to the library root."
  (unless *stylelib-path*
    (let* ((asdf-system (asdf:find-system :cl-matplotlib-foundation))
           (system-root (asdf:system-source-directory asdf-system))
           (stylelib (merge-pathnames "data/stylelib/" system-root)))
      (setf *stylelib-path* stylelib))))

(defun available-styles ()
  "Return a list of available style names (as keywords).
Scans the stylelib directory for .mplstyle files."
  (initialize-stylelib-path)
  (let ((styles nil))
    (when (probe-file *stylelib-path*)
      (dolist (file (uiop:directory-files *stylelib-path*))
        (let ((name (pathname-name file)))
          (when (and name (string-equal (pathname-type file) "mplstyle"))
            ;; Convert filename to keyword (e.g., "ggplot.mplstyle" -> :ggplot)
            (push (intern (string-upcase name) :keyword) styles)))))
    (sort styles #'string< :key #'symbol-name)))

(defun reload-styles ()
  "Clear the style cache and rescan the stylelib directory.
Useful for development when style files change."
  (clrhash *style-cache*)
  (available-styles))

(defun style-filename (style-name)
  "Convert a style name (keyword or string) to a filename.
Example: :ggplot -> \"ggplot.mplstyle\"
         :dark-background -> \"dark_background.mplstyle\""
  (let ((name (if (keywordp style-name)
                  (string-downcase (symbol-name style-name))
                  (string-downcase style-name))))
    ;; Replace hyphens with underscores for filename
    (setf name (substitute #\_ #\- name))
    (format nil "~A.mplstyle" name)))

(defun load-style (style-name)
  "Load a single style sheet by name.
Returns an alist of (key . value) pairs.
Caches the result for subsequent calls."
  (initialize-stylelib-path)
  
  ;; Check cache first
  (let ((cache-key (if (keywordp style-name)
                       (string-downcase (symbol-name style-name))
                       (string-downcase style-name))))
    (or (gethash cache-key *style-cache*)
        (let* ((filename (style-filename style-name))
               (filepath (merge-pathnames filename *stylelib-path*)))
          (if (probe-file filepath)
              (let ((params (parse-matplotlibrc filepath)))
                ;; Cache the result
                (setf (gethash cache-key *style-cache*) params)
                params)
              (error "Style file not found: ~A" filepath))))))

(defun use-style (style-names)
  "Apply one or more style sheets globally.
STYLE-NAMES can be a single style name (keyword/string) or a list of names.
Later styles override earlier ones.
Example: (use-style :ggplot)
         (use-style '(:seaborn :dark-background))"
  (let ((names (if (listp style-names) style-names (list style-names))))
    (dolist (name names)
      (let ((params (load-style name)))
        (dolist (pair params)
          (let ((key (car pair))
                (val (cdr pair)))
            (if (gethash key *rc-validators*)
                (handler-case
                    (setf (rc key) val)
                  (error (e)
                    (warn "Could not set ~S to ~S: ~A" key val e)))
                ;; Unknown key, skip silently
                nil)))))))

(defmacro with-style (style-names &body body)
  "Temporarily apply one or more style sheets for the duration of BODY.
STYLE-NAMES can be a single style name or a list of names.
Restores original rcParams on exit, even on non-local exit.

Example:
  (with-style (:ggplot)
    (plot x y))  ; Uses ggplot style
  ;; Restored to original after"
  (let ((names (if (listp style-names) style-names (list style-names))))
    ;; Collect all keys that will be modified
    (let ((all-keys nil))
      (dolist (name names)
        (let ((params (load-style name)))
          (dolist (pair params)
            (pushnew (car pair) all-keys :test #'string=))))
      
      ;; Generate the macro expansion
      (let ((saved (gensym "SAVED")))
        `(let ((,saved (list ,@(loop for key in all-keys
                                     collect `(cons ,key (rc ,key))))))
           (unwind-protect
                (progn
                  (use-style ',style-names)
                  ,@body)
             (dolist (pair ,saved)
               (setf (gethash (car pair) *rc-params*) (cdr pair)))))))))

;;; ============================================================
;;; Initialization
;;; ============================================================

(defun initialize-styles ()
  "Initialize the style system.
Called automatically when the system loads."
  (initialize-stylelib-path))
