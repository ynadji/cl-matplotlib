;;;; matplotlibrc-parser.lisp — Parser for matplotlibrc configuration files
;;;; Format: key : value  # optional comment
;;;; Lines starting with # are comments. Blank lines are ignored.

(in-package #:cl-matplotlib.rc)

;;; ============================================================
;;; matplotlibrc file parser (~50 LOC)
;;; ============================================================

(defun strip-comment (line)
  "Remove trailing comment from LINE. Handles quoted strings containing #.
Returns the content before any unquoted # character."
  (let ((in-quote nil)
        (result (make-array 0 :element-type 'character :adjustable t :fill-pointer 0)))
    (loop for ch across line do
      (cond
        ((char= ch #\") (setf in-quote (not in-quote))
                         (vector-push-extend ch result))
        ((and (char= ch #\#) (not in-quote))
         (return))
        (t (vector-push-extend ch result))))
    (string-trim '(#\Space #\Tab) result)))

(defun parse-rc-line (line)
  "Parse a single matplotlibrc line. Returns (KEY . VALUE) or NIL if not a param line.
Format expected: key : value  OR  key: value"
  (let ((stripped (strip-comment line)))
    (when (and (> (length stripped) 0)
               (not (char= (char stripped 0) #\#)))
      (let ((colon-pos (position #\: stripped)))
        (when colon-pos
          (let ((key (string-trim '(#\Space #\Tab) (subseq stripped 0 colon-pos)))
                (val (string-trim '(#\Space #\Tab) (subseq stripped (1+ colon-pos)))))
            (when (> (length key) 0)
              (cons key val))))))))

(defun parse-matplotlibrc (stream-or-pathname)
  "Parse a matplotlibrc file and return an alist of (key . value) string pairs.
STREAM-OR-PATHNAME can be a stream, pathname, or string (file path)."
  (flet ((parse-from-stream (stream)
           (loop for line = (read-line stream nil nil)
                 while line
                 for pair = (parse-rc-line line)
                 when pair collect pair)))
    (etypecase stream-or-pathname
      (stream (parse-from-stream stream-or-pathname))
      (pathname (with-open-file (s stream-or-pathname :direction :input
                                                       :if-does-not-exist nil)
                  (when s (parse-from-stream s))))
      (string (with-open-file (s stream-or-pathname :direction :input
                                                     :if-does-not-exist nil)
                (when s (parse-from-stream s)))))))

(defun load-matplotlibrc (path)
  "Load a matplotlibrc file and apply its settings to the current rc-params.
Only applies settings for known rc parameter keys; unknown keys are silently skipped."
  (let ((pairs (parse-matplotlibrc path))
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
                (format *error-output*
                        "~&; Warning: Could not set ~S to ~S: ~A~%"
                        key val e)
                (incf skipped)))
            (incf skipped))))
    (values applied skipped)))
