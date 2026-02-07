;;;; test-rcparams.lisp — Tests for rcParams configuration system
;;;; Phase 7b — FiveAM test suite

(defpackage #:cl-matplotlib.tests.rcparams
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rc
                ;; Core functions
                #:rc #:rc-reset #:rc-defaults #:rc-update #:rc-find-all
                ;; Context management
                #:rc-context
                ;; File I/O
                #:rc-from-file #:rc-params-to-file
                ;; Validators
                #:validate-bool #:validate-float #:validate-int
                #:validate-color #:validate-linestyle
                #:validate-fontsize #:validate-fontweight
                ;; Conditions
                #:rc-validation-error #:rc-key-error
                ;; Internal
                #:*rc-params* #:*rc-defaults*)
  (:export #:run-rcparams-tests))

(in-package #:cl-matplotlib.tests.rcparams)

(def-suite rcparams-suite :description "rcParams configuration system tests")
(in-suite rcparams-suite)

;;; ============================================================
;;; Basic rcParams access tests
;;; ============================================================

(test rc-get-basic
  "Test basic rcParam retrieval"
  (is (numberp (rc "lines.linewidth")))
  (is (stringp (rc "lines.color")))
  (is (or (eq (rc "lines.antialiased") t)
          (eq (rc "lines.antialiased") nil))))

(test rc-set-basic
  "Test basic rcParam setting with validation"
  (let ((orig (rc "lines.linewidth")))
    (unwind-protect
         (progn
           (setf (rc "lines.linewidth") 3.0)
           (is (= (rc "lines.linewidth") 3.0d0))
           (setf (rc "lines.linewidth") "5.5")
           (is (= (rc "lines.linewidth") 5.5d0)))
      (setf (rc "lines.linewidth") orig))))

(test rc-invalid-key
  "Test that invalid keys signal rc-key-error"
  (signals rc-key-error
    (rc "invalid.key.that.does.not.exist"))
  (signals rc-key-error
    (setf (rc "invalid.key") 42)))

(test rc-validation-error
  "Test that invalid values signal rc-validation-error"
  (signals rc-validation-error
    (setf (rc "lines.linewidth") "not-a-number"))
  (signals rc-validation-error
    (setf (rc "lines.antialiased") "not-a-bool")))

;;; ============================================================
;;; Validator tests
;;; ============================================================

(test validate-bool-test
  "Test boolean validator"
  (is (eq (validate-bool t) t))
  (is (eq (validate-bool nil) nil))
  (is (eq (validate-bool "true") t))
  (is (eq (validate-bool "false") nil))
  (is (eq (validate-bool "yes") t))
  (is (eq (validate-bool "no") nil))
  (is (eq (validate-bool 1) t))
  (is (eq (validate-bool 0) nil))
  (signals rc-validation-error
    (validate-bool "invalid")))

(test validate-float-test
  "Test float validator"
  (is (= (validate-float 3.14d0) 3.14d0))
  (is (= (validate-float 42) 42.0d0))
  (is (= (validate-float "2.5") 2.5d0))
  (signals rc-validation-error
    (validate-float "not-a-number")))

(test validate-int-test
  "Test integer validator"
  (is (= (validate-int 42) 42))
  (is (= (validate-int 3.7) 4))  ; rounds
  (is (= (validate-int "10") 10))
  (signals rc-validation-error
    (validate-int "not-an-int")))

(test validate-color-test
  "Test color validator"
  (is (stringp (validate-color "red")))
  (is (stringp (validate-color "#ff0000")))
  (is (stringp (validate-color "ff0000")))  ; adds #
  (is (vectorp (validate-color '(1.0 0.0 0.0))))
  (is (string= (validate-color "none") "none"))
  (is (string= (validate-color nil) "none")))

(test validate-linestyle-test
  "Test linestyle validator"
  (is (keywordp (validate-linestyle "-")))
  (is (keywordp (validate-linestyle "--")))
  (is (keywordp (validate-linestyle ":")))
  (is (keywordp (validate-linestyle "-.")))
  (is (eq (validate-linestyle :solid) :solid))
  (signals rc-validation-error
    (validate-linestyle "invalid-style")))

(test validate-fontsize-test
  "Test fontsize validator"
  (is (stringp (validate-fontsize "small")))
  (is (stringp (validate-fontsize "medium")))
  (is (stringp (validate-fontsize "large")))
  (is (numberp (validate-fontsize 12.0)))
  (is (numberp (validate-fontsize "14"))))

(test validate-fontweight-test
  "Test fontweight validator"
  (is (stringp (validate-fontweight "normal")))
  (is (stringp (validate-fontweight "bold")))
  (is (integerp (validate-fontweight 400)))
  (is (integerp (validate-fontweight "700"))))

;;; ============================================================
;;; rc-defaults and rc-reset tests
;;; ============================================================

(test rc-defaults-test
  "Test rc-defaults resets all params to defaults"
  (let ((orig-linewidth (rc "lines.linewidth"))
        (orig-color (rc "lines.color")))
    (unwind-protect
         (progn
           ;; Modify some params
           (setf (rc "lines.linewidth") 10.0)
           (setf (rc "lines.color") "red")
           (is (= (rc "lines.linewidth") 10.0d0))
           (is (string= (rc "lines.color") "red"))
           ;; Reset to defaults
           (rc-defaults)
           ;; Should be back to defaults
           (is (= (rc "lines.linewidth") orig-linewidth))
           (is (string= (rc "lines.color") orig-color)))
      ;; Cleanup
      (rc-defaults))))

(test rc-reset-test
  "Test rc-reset is same as rc-defaults"
  (let ((orig (rc "lines.linewidth")))
    (unwind-protect
         (progn
           (setf (rc "lines.linewidth") 99.0)
           (rc-reset)
           (is (= (rc "lines.linewidth") orig)))
      (rc-defaults))))

;;; ============================================================
;;; rc-update tests
;;; ============================================================

(test rc-update-test
  "Test rc-update with alist"
  (let ((orig-lw (rc "lines.linewidth"))
        (orig-color (rc "lines.color")))
    (unwind-protect
         (progn
           (rc-update '(("lines.linewidth" . 5.0)
                        ("lines.color" . "blue")))
           (is (= (rc "lines.linewidth") 5.0d0))
           (is (string= (rc "lines.color") "blue")))
      (setf (rc "lines.linewidth") orig-lw)
      (setf (rc "lines.color") orig-color))))

;;; ============================================================
;;; rc-find-all tests
;;; ============================================================

(test rc-find-all-test
  "Test rc-find-all pattern matching"
  (let ((lines-params (rc-find-all "lines.")))
    (is (> (length lines-params) 0))
    (is (every (lambda (pair) (search "lines." (car pair))) lines-params)))
  (let ((font-params (rc-find-all "font.")))
    (is (> (length font-params) 0))
    (is (every (lambda (pair) (search "font." (car pair))) font-params))))

;;; ============================================================
;;; rc-context tests
;;; ============================================================

(test rc-context-basic
  "Test rc-context temporarily overrides params"
  (let ((orig-lw (rc "lines.linewidth"))
        (orig-color (rc "lines.color")))
    (rc-context (("lines.linewidth" 7.0)
                 ("lines.color" "green"))
      (is (= (rc "lines.linewidth") 7.0d0))
      (is (string= (rc "lines.color") "green")))
    ;; Should be restored after context
    (is (= (rc "lines.linewidth") orig-lw))
    (is (string= (rc "lines.color") orig-color))))

(test rc-context-nested
  "Test nested rc-context calls"
  (let ((orig (rc "lines.linewidth")))
    (rc-context (("lines.linewidth" 2.0))
      (is (= (rc "lines.linewidth") 2.0d0))
      (rc-context (("lines.linewidth" 4.0))
        (is (= (rc "lines.linewidth") 4.0d0)))
      ;; Should restore to outer context
      (is (= (rc "lines.linewidth") 2.0d0)))
    ;; Should restore to original
    (is (= (rc "lines.linewidth") orig))))

(test rc-context-unwind-protect
  "Test rc-context restores on non-local exit"
  (let ((orig (rc "lines.linewidth")))
    (ignore-errors
      (rc-context (("lines.linewidth" 99.0))
        (is (= (rc "lines.linewidth") 99.0d0))
        (error "Simulated error")))
    ;; Should still be restored despite error
    (is (= (rc "lines.linewidth") orig))))

(test rc-context-multiple-params
  "Test rc-context with many params"
  (let ((orig-lw (rc "lines.linewidth"))
        (orig-ls (rc "lines.linestyle"))
        (orig-color (rc "lines.color"))
        (orig-aa (rc "lines.antialiased")))
    (rc-context (("lines.linewidth" 3.5)
                 ("lines.linestyle" "--")
                 ("lines.color" "purple")
                 ("lines.antialiased" nil))
      (is (= (rc "lines.linewidth") 3.5d0))
      (is (eq (rc "lines.linestyle") :dashed))
      (is (string= (rc "lines.color") "purple"))
      (is (eq (rc "lines.antialiased") nil)))
    ;; All should be restored
    (is (= (rc "lines.linewidth") orig-lw))
    (is (eq (rc "lines.linestyle") orig-ls))
    (is (string= (rc "lines.color") orig-color))
    (is (eq (rc "lines.antialiased") orig-aa))))

;;; ============================================================
;;; File I/O tests
;;; ============================================================

(test rc-from-file-default
  "Test loading default matplotlibrc file"
  (let ((orig-lw (rc "lines.linewidth")))
    (unwind-protect
         (progn
           ;; Modify a param
           (setf (rc "lines.linewidth") 99.0)
           ;; Load from default file
           (multiple-value-bind (applied skipped)
               (rc-from-file "data/matplotlibrc")
             (is (> applied 0))
             (is (>= skipped 0)))
           ;; Should be reset to default from file
           (is (/= (rc "lines.linewidth") 99.0d0)))
      (setf (rc "lines.linewidth") orig-lw))))

(test rc-params-to-file-test
  "Test writing rcParams to file"
  (let ((temp-file (format nil "/tmp/test-rcparams-~A.txt" (get-universal-time))))
    (unwind-protect
         (progn
           ;; Write current params to file
           (rc-params-to-file temp-file)
           ;; File should exist
           (is (probe-file temp-file))
           ;; File should contain some params
           (with-open-file (stream temp-file :direction :input)
             (let ((content (make-string (file-length stream))))
               (read-sequence content stream)
               (is (search "lines.linewidth" content))
               (is (search "font.size" content)))))
      ;; Cleanup
      (when (probe-file temp-file)
        (delete-file temp-file)))))

(test rc-from-file-roundtrip
  "Test writing and reading rcParams"
  (let ((temp-file (format nil "/tmp/test-rcparams-roundtrip-~A.txt" (get-universal-time)))
        (orig-lw (rc "lines.linewidth"))
        (orig-color (rc "lines.color")))
    (unwind-protect
         (progn
           ;; Set some specific values
           (setf (rc "lines.linewidth") 2.5)
           (setf (rc "lines.color") "cyan")
           ;; Write to file
           (rc-params-to-file temp-file)
           ;; Change values
           (setf (rc "lines.linewidth") 99.0)
           (setf (rc "lines.color") "magenta")
           ;; Read from file
           (rc-from-file temp-file)
           ;; Should match what we wrote
           (is (= (rc "lines.linewidth") 2.5d0))
           (is (string= (rc "lines.color") "cyan")))
      ;; Cleanup
      (setf (rc "lines.linewidth") orig-lw)
      (setf (rc "lines.color") orig-color)
      (when (probe-file temp-file)
        (delete-file temp-file)))))

;;; ============================================================
;;; Comprehensive param coverage tests
;;; ============================================================

(test rc-all-params-accessible
  "Test that all registered params are accessible"
  (let ((count 0))
    (maphash (lambda (key value)
               (declare (ignore value))
               ;; Just check that we can access it without error
               ;; (some params have NIL as valid value)
               (finishes (rc key))
               (incf count))
             *rc-params*)
    (is (> count 200))  ; Should have ~265 params
    (format t "~&; Tested ~D rcParams~%" count)))

(test rc-lines-params
  "Test lines.* parameters"
  (is (numberp (rc "lines.linewidth")))
  (is (keywordp (rc "lines.linestyle")))
  (is (stringp (rc "lines.color")))
  (is (or (stringp (rc "lines.marker")) (null (rc "lines.marker"))))
  (is (numberp (rc "lines.markersize")))
  (is (or (eq (rc "lines.antialiased") t) (eq (rc "lines.antialiased") nil))))

(test rc-font-params
  "Test font.* parameters"
  (is (listp (rc "font.family")))
  (is (stringp (rc "font.style")))
  (is (numberp (rc "font.size")))
  (is (listp (rc "font.serif")))
  (is (listp (rc "font.sans-serif"))))

(test rc-axes-params
  "Test axes.* parameters"
  (is (stringp (rc "axes.facecolor")))
  (is (stringp (rc "axes.edgecolor")))
  (is (numberp (rc "axes.linewidth")))
  (is (or (eq (rc "axes.grid") t) (eq (rc "axes.grid") nil)))
  (is (numberp (rc "axes.titlepad"))))

(test rc-figure-params
  "Test figure.* parameters"
  (is (listp (rc "figure.figsize")))
  (is (numberp (rc "figure.dpi")))
  (is (stringp (rc "figure.facecolor")))
  (is (or (eq (rc "figure.frameon") t) (eq (rc "figure.frameon") nil))))

(test rc-savefig-params
  "Test savefig.* parameters"
  (is (or (stringp (rc "savefig.dpi")) (numberp (rc "savefig.dpi"))))
  (is (stringp (rc "savefig.format")))
  (is (numberp (rc "savefig.pad_inches")))
  (is (or (eq (rc "savefig.transparent") t) (eq (rc "savefig.transparent") nil))))

(test rc-legend-params
  "Test legend.* parameters"
  (is (stringp (rc "legend.loc")))
  (is (or (eq (rc "legend.frameon") t) (eq (rc "legend.frameon") nil)))
  (is (numberp (rc "legend.borderpad")))
  (is (numberp (rc "legend.handlelength"))))

(test rc-grid-params
  "Test grid.* parameters"
  (is (stringp (rc "grid.color")))
  (is (keywordp (rc "grid.linestyle")))
  (is (numberp (rc "grid.linewidth")))
  (is (numberp (rc "grid.alpha"))))

;;; ============================================================
;;; Test runner
;;; ============================================================

(defun run-rcparams-tests ()
  "Run all rcParams tests and return T if all pass, NIL otherwise."
  (let ((results (run 'rcparams-suite)))
    (explain! results)
    (results-status results)))
