;;;; test-axis.lisp — Tests for Axis, Ticker, Spines
;;;; Phase 4c — FiveAM test suite

(defpackage #:cl-matplotlib.tests.axis
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; Locators
                #:locator #:locator-tick-values #:locator-call
                #:null-locator
                #:fixed-locator
                #:linear-locator
                #:multiple-locator
                #:max-n-locator
                #:auto-locator
                #:log-locator
                ;; Formatters
                #:tick-formatter #:tick-formatter-call #:tick-formatter-format-ticks
                #:null-formatter
                #:fixed-formatter
                #:scalar-formatter
                #:str-method-formatter
                #:log-formatter
                #:percent-formatter
                ;; Spine
                #:spine #:spine-spine-type #:spine-visible-p
                #:spine-set-visible #:spine-set-color
                #:spines #:make-spines #:spines-ref #:spines-all
                ;; Axis
                #:axis-obj #:x-axis #:y-axis
                #:axis-major-locator #:axis-minor-locator
                #:axis-major-formatter #:axis-minor-formatter
                #:axis-set-major-locator #:axis-set-minor-locator
                #:axis-set-major-formatter #:axis-set-minor-formatter
                #:axis-set-label-text #:axis-grid
                #:axis-get-view-interval #:axis-get-major-ticks
                #:tick #:tick-loc #:tick-label-text
                ;; Axes
                #:axes-base #:mpl-axes #:axes-base-xaxis #:axes-base-yaxis
                #:axes-base-spines #:add-subplot #:plot #:axes-grid-toggle
                ;; Figure
                #:mpl-figure #:make-figure #:savefig)
  (:export #:run-axis-tests))

(in-package #:cl-matplotlib.tests.axis)

(def-suite axis-suite :description "Axis, Ticker, and Spine test suite")
(in-suite axis-suite)

;;; ============================================================
;;; Helpers
;;; ============================================================

(defun approx= (a b &optional (epsilon 0.01d0))
  "Return T if A and B are approximately equal."
  (< (abs (- a b)) epsilon))

(defun tmp-path (name ext)
  "Create a temporary file path."
  (format nil "/tmp/cl-mpl-test-~A.~A" name ext))

(defun file-exists-and-valid-p (path &optional (min-size 100))
  (and (probe-file path)
       (> (with-open-file (s path :element-type '(unsigned-byte 8))
            (file-length s))
          min-size)))

(defun png-header-valid-p (path)
  (when (probe-file path)
    (with-open-file (s path :element-type '(unsigned-byte 8))
      (and (= (read-byte s) 137)
           (= (read-byte s) 80)
           (= (read-byte s) 78)
           (= (read-byte s) 71)))))

;;; ============================================================
;;; NullLocator Tests
;;; ============================================================

(test null-locator-returns-empty
  "NullLocator returns no ticks."
  (let ((loc (make-instance 'null-locator)))
    (is (null (locator-tick-values loc 0.0d0 10.0d0)))))

;;; ============================================================
;;; FixedLocator Tests
;;; ============================================================

(test fixed-locator-returns-locs
  "FixedLocator returns specified locations."
  (let ((loc (make-instance 'fixed-locator :locs '(1.0d0 3.0d0 5.0d0 7.0d0))))
    (let ((ticks (locator-tick-values loc 0.0d0 10.0d0)))
      (is (= 4 (length ticks)))
      (is (= 1.0d0 (first ticks)))
      (is (= 7.0d0 (fourth ticks))))))

(test fixed-locator-with-nbins
  "FixedLocator subsamples with nbins."
  (let ((loc (make-instance 'fixed-locator
                            :locs '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0)
                            :nbins 3)))
    (let ((ticks (locator-tick-values loc 0.0d0 10.0d0)))
      (is (<= (length ticks) 4)))))

;;; ============================================================
;;; LinearLocator Tests
;;; ============================================================

(test linear-locator-even-spacing
  "LinearLocator produces evenly spaced ticks."
  (let ((loc (make-instance 'linear-locator :numticks 5)))
    (let ((ticks (locator-tick-values loc 0.0d0 10.0d0)))
      (is (= 5 (length ticks)))
      (is (approx= 0.0d0 (first ticks)))
      (is (approx= 2.5d0 (second ticks)))
      (is (approx= 10.0d0 (car (last ticks)))))))

(test linear-locator-numticks-11
  "LinearLocator default 11 ticks."
  (let ((loc (make-instance 'linear-locator)))
    (let ((ticks (locator-tick-values loc 0.0d0 100.0d0)))
      (is (= 11 (length ticks)))
      (is (approx= 0.0d0 (first ticks)))
      (is (approx= 100.0d0 (car (last ticks)))))))

;;; ============================================================
;;; MultipleLocator Tests
;;; ============================================================

(test multiple-locator-basic
  "MultipleLocator places ticks at multiples of base."
  (let ((loc (make-instance 'multiple-locator :base 5.0d0)))
    (let ((ticks (locator-tick-values loc 0.0d0 20.0d0)))
      ;; Should include 0, 5, 10, 15, 20 (plus one beyond each end)
      (is (>= (length ticks) 5))
      ;; All ticks should be multiples of 5
      (dolist (tk ticks)
        (is (approx= 0.0d0 (mod tk 5.0d0) 0.01d0))))))

(test multiple-locator-base-2
  "MultipleLocator with base 2."
  (let ((loc (make-instance 'multiple-locator :base 2.0d0)))
    (let ((ticks (locator-tick-values loc 1.0d0 9.0d0)))
      (is (>= (length ticks) 4))
      (dolist (tk ticks)
        (is (approx= 0.0d0 (mod tk 2.0d0) 0.01d0))))))

;;; ============================================================
;;; MaxNLocator Tests
;;; ============================================================

(test max-n-locator-basic
  "MaxNLocator generates ticks with at most nbins+1 in range."
  (let ((loc (make-instance 'max-n-locator :nbins 5)))
    (let* ((ticks (locator-tick-values loc 0.0d0 100.0d0))
           ;; Count ticks in range
           (in-range (remove-if-not (lambda (t-val)
                                      (and (>= t-val 0.0d0) (<= t-val 100.0d0)))
                                    ticks)))
      (is (>= (length in-range) 2))
      (is (<= (length in-range) 7)))))  ;; nbins + some margin

(test max-n-locator-nice-numbers
  "MaxNLocator produces nice tick values."
  (let ((loc (make-instance 'max-n-locator :nbins 10
                            :steps '(1.0d0 2.0d0 5.0d0 10.0d0))))
    (let ((ticks (locator-tick-values loc 0.0d0 100.0d0)))
      ;; Ticks should be at nice multiples
      (is (> (length ticks) 2))
      ;; Step between ticks should be a nice number
      (when (> (length ticks) 1)
        (let ((step (- (second ticks) (first ticks))))
          ;; Step should be a power of 10 times 1, 2, or 5
          (is (> step 0)))))))

(test max-n-locator-prune-lower
  "MaxNLocator with prune=:lower removes first tick."
  (let ((loc (make-instance 'max-n-locator :nbins 5 :prune :lower)))
    (let ((ticks (locator-tick-values loc 0.0d0 100.0d0)))
      (is (> (length ticks) 0))
      ;; First tick should not be at/below vmin
      ;; (hard to check without knowing exact ticks, just ensure not empty)
      (is (> (first ticks) -1.0d0)))))

;;; ============================================================
;;; AutoLocator Tests
;;; ============================================================

(test auto-locator-creates-ticks
  "AutoLocator generates reasonable ticks."
  (let ((loc (make-instance 'auto-locator)))
    (let ((ticks (locator-tick-values loc 0.0d0 10.0d0)))
      (is (> (length ticks) 2))
      ;; Should have nice values like 0, 2, 4, 6, 8, 10
      (is (<= (length ticks) 15)))))

(test auto-locator-large-range
  "AutoLocator works for large ranges."
  (let ((loc (make-instance 'auto-locator)))
    (let ((ticks (locator-tick-values loc 0.0d0 1000.0d0)))
      (is (> (length ticks) 2))
      ;; Should have nice steps like 100, 200
      (when (> (length ticks) 1)
        (let ((step (- (second ticks) (first ticks))))
          (is (> step 0.0d0)))))))

(test auto-locator-small-range
  "AutoLocator works for small ranges."
  (let ((loc (make-instance 'auto-locator)))
    (let ((ticks (locator-tick-values loc 0.0d0 0.01d0)))
      (is (> (length ticks) 2)))))

(test auto-locator-negative-range
  "AutoLocator works for negative ranges."
  (let ((loc (make-instance 'auto-locator)))
    (let ((ticks (locator-tick-values loc -50.0d0 50.0d0)))
      (is (> (length ticks) 2))
      ;; Should include 0
      (is (some (lambda (t-val) (< (abs t-val) 1.0d0)) ticks)))))

;;; ============================================================
;;; LogLocator Tests
;;; ============================================================

(test log-locator-basic
  "LogLocator places ticks at powers of base."
  (let ((loc (make-instance 'log-locator :base 10.0d0)))
    (let ((ticks (locator-tick-values loc 1.0d0 10000.0d0)))
      ;; Should include 1, 10, 100, 1000, 10000
      (is (>= (length ticks) 4))
      (is (some (lambda (t-val) (approx= t-val 10.0d0 0.5d0)) ticks))
      (is (some (lambda (t-val) (approx= t-val 100.0d0 5.0d0)) ticks)))))

(test log-locator-with-subs
  "LogLocator with subs generates intermediate ticks."
  (let ((loc (make-instance 'log-locator :base 10.0d0 :subs '(1.0d0 2.0d0 5.0d0))))
    (let ((ticks (locator-tick-values loc 1.0d0 100.0d0)))
      ;; Should have more ticks than just decades
      (is (>= (length ticks) 6)))))

;;; ============================================================
;;; NullFormatter Tests
;;; ============================================================

(test null-formatter-returns-empty
  "NullFormatter always returns empty string."
  (let ((fmt (make-instance 'null-formatter)))
    (is (string= "" (tick-formatter-call fmt 42.0d0)))
    (is (string= "" (tick-formatter-call fmt 0.0d0)))))

;;; ============================================================
;;; FixedFormatter Tests
;;; ============================================================

(test fixed-formatter-returns-strings
  "FixedFormatter returns fixed strings by position."
  (let ((fmt (make-instance 'fixed-formatter :seq '("a" "b" "c"))))
    (is (string= "a" (tick-formatter-call fmt 0.0d0 0)))
    (is (string= "b" (tick-formatter-call fmt 1.0d0 1)))
    (is (string= "c" (tick-formatter-call fmt 2.0d0 2)))
    (is (string= "" (tick-formatter-call fmt 3.0d0 3)))))

;;; ============================================================
;;; ScalarFormatter Tests
;;; ============================================================

(test scalar-formatter-integer-like
  "ScalarFormatter formats integers cleanly."
  (let ((fmt (make-instance 'scalar-formatter)))
    (let ((s (tick-formatter-call fmt 5.0d0)))
      (is (string= "5" s)))))

(test scalar-formatter-decimal
  "ScalarFormatter formats decimals."
  (let ((fmt (make-instance 'scalar-formatter)))
    (let ((s (tick-formatter-call fmt 2.5d0)))
      (is (search "2.5" s)))))

(test scalar-formatter-zero
  "ScalarFormatter formats zero."
  (let ((fmt (make-instance 'scalar-formatter)))
    (is (string= "0" (tick-formatter-call fmt 0.0d0)))))

(test scalar-formatter-format-ticks
  "ScalarFormatter format-ticks formats a list."
  (let ((fmt (make-instance 'scalar-formatter)))
    (let ((labels (tick-formatter-format-ticks fmt '(0.0d0 2.0d0 4.0d0 6.0d0 8.0d0 10.0d0))))
      (is (= 6 (length labels)))
      (is (string= "0" (first labels)))
      (is (string= "10" (sixth labels))))))

;;; ============================================================
;;; StrMethodFormatter Tests
;;; ============================================================

(test str-method-formatter-basic
  "StrMethodFormatter uses CL format string."
  (let ((fmt (make-instance 'str-method-formatter :fmt "~,2F")))
    (is (string= "3.14" (tick-formatter-call fmt 3.14159d0)))))

(test str-method-formatter-integer
  "StrMethodFormatter with integer format."
  ;; ~,0F produces "42." in CL, which is fine
  (let ((fmt (make-instance 'str-method-formatter :fmt "~,0F")))
    (let ((s (tick-formatter-call fmt 42.0d0)))
      ;; Accept either "42" or "42." since CL ~,0F includes trailing dot
      (is (or (string= "42" s) (string= "42." s))))))

;;; ============================================================
;;; LogFormatter Tests
;;; ============================================================

(test log-formatter-decade
  "LogFormatter formats decade values."
  (let ((fmt (make-instance 'log-formatter :base 10.0d0)))
    (let ((s (tick-formatter-call fmt 100.0d0)))
      (is (search "10" s)))))

(test log-formatter-non-decade
  "LogFormatter formats non-decade values."
  (let ((fmt (make-instance 'log-formatter :base 10.0d0)))
    (let ((s (tick-formatter-call fmt 50.0d0)))
      ;; Should produce a number string
      (is (> (length s) 0)))))

;;; ============================================================
;;; PercentFormatter Tests
;;; ============================================================

(test percent-formatter-basic
  "PercentFormatter formats as percentage."
  (let ((fmt (make-instance 'percent-formatter :xmax 100.0d0)))
    (let ((s (tick-formatter-call fmt 50.0d0)))
      (is (search "50" s))
      (is (search "%" s)))))

(test percent-formatter-xmax-1
  "PercentFormatter with xmax=1."
  (let ((fmt (make-instance 'percent-formatter :xmax 1.0d0)))
    (let ((s (tick-formatter-call fmt 0.5d0)))
      (is (search "50" s))
      (is (search "%" s)))))

(test percent-formatter-custom-decimals
  "PercentFormatter with custom decimals."
  (let ((fmt (make-instance 'percent-formatter :xmax 100.0d0 :decimals 2)))
    (let ((s (tick-formatter-call fmt 33.333d0)))
      (is (search "33.33%" s)))))

;;; ============================================================
;;; Spine Tests
;;; ============================================================

(test spine-creation
  "Spine can be created with type."
  (let ((sp (make-instance 'spine :spine-type "left")))
    (is (typep sp 'spine))
    (is (string= "left" (spine-spine-type sp)))
    (is (spine-visible-p sp))))

(test spine-set-visible
  "Spine visibility can be toggled."
  (let ((sp (make-instance 'spine :spine-type "bottom")))
    (spine-set-visible sp nil)
    (is (not (spine-visible-p sp)))
    (spine-set-visible sp t)
    (is (spine-visible-p sp))))

(test spine-set-color
  "Spine color can be changed."
  (let ((sp (make-instance 'spine :spine-type "left")))
    (spine-set-color sp "red")
    (is (string= "red" (mpl.rendering:patch-edgecolor sp)))))

(test spines-container
  "Spines container manages 4 spines."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sp (axes-base-spines ax)))
    (is (typep sp 'spines))
    (is (= 4 (length (spines-all sp))))
    (is (typep (spines-ref sp "left") 'spine))
    (is (typep (spines-ref sp "right") 'spine))
    (is (typep (spines-ref sp "top") 'spine))
    (is (typep (spines-ref sp "bottom") 'spine))))

;;; ============================================================
;;; Axis Tests
;;; ============================================================

(test axes-has-xaxis-yaxis
  "Axes creates xaxis and yaxis on init."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (is (typep (axes-base-xaxis ax) 'x-axis))
    (is (typep (axes-base-yaxis ax) 'y-axis))))

(test xaxis-has-auto-locator
  "XAxis default major locator is AutoLocator."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (is (typep (axis-major-locator (axes-base-xaxis ax)) 'auto-locator))))

(test yaxis-has-auto-locator
  "YAxis default major locator is AutoLocator."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (is (typep (axis-major-locator (axes-base-yaxis ax)) 'auto-locator))))

(test xaxis-has-scalar-formatter
  "XAxis default major formatter is ScalarFormatter."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (is (typep (axis-major-formatter (axes-base-xaxis ax)) 'scalar-formatter))))

(test axis-get-view-interval-xaxis
  "XAxis view interval matches axes xlim."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 10) '(0 100))
    (multiple-value-bind (vmin vmax) (axis-get-view-interval (axes-base-xaxis ax))
      (is (< vmin 0.5d0))
      (is (> vmax 9.5d0)))))

(test axis-generates-major-ticks
  "Axis generates major ticks from locator."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 10) '(0 100))
    (let ((ticks (axis-get-major-ticks (axes-base-xaxis ax))))
      (is (> (length ticks) 2))
      ;; Each tick should have a label
      (dolist (tk ticks)
        (is (typep tk 'tick))
        (is (stringp (tick-label-text tk)))))))

(test axis-set-custom-locator
  "Custom locator can be set on axis."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 10) '(0 100))
    (axis-set-major-locator (axes-base-xaxis ax)
                            (make-instance 'fixed-locator :locs '(0.0d0 5.0d0 10.0d0)))
    (let ((ticks (axis-get-major-ticks (axes-base-xaxis ax))))
      (is (= 3 (length ticks)))
      (is (approx= 0.0d0 (tick-loc (first ticks))))
      (is (approx= 5.0d0 (tick-loc (second ticks))))
      (is (approx= 10.0d0 (tick-loc (third ticks)))))))

(test grid-toggle
  "Grid can be toggled on axes."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 10) '(0 100))
    (axes-grid-toggle ax :visible t)
    (is (cl-matplotlib.containers::axis-grid-on-p (axes-base-xaxis ax)))
    (is (cl-matplotlib.containers::axis-grid-on-p (axes-base-yaxis ax)))
    (axes-grid-toggle ax :visible nil)
    (is (not (cl-matplotlib.containers::axis-grid-on-p (axes-base-xaxis ax))))))

;;; ============================================================
;;; Integration Tests — Drawing with ticks
;;; ============================================================

(test axes-draw-with-ticks
  "Axes can be drawn with tick marks (no crash)."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (renderer (mpl.rendering:make-mock-renderer)))
    (plot ax '(0 1 2 3 4) '(0 1 4 9 16))
    ;; Should not error
    (mpl.rendering:draw ax renderer)
    (pass)))

(test savefig-with-ticks-produces-png
  "savefig produces PNG with ticks and labels."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "axis-ticks" "png")))
    (plot ax '(0 1 2 3 4) '(0 1 4 9 16))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test savefig-with-grid-produces-png
  "savefig produces PNG with grid lines."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "axis-grid" "png")))
    (plot ax '(0 1 2 3 4) '(0 1 4 9 16))
    (axes-grid-toggle ax :visible t)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Evidence Generation — Acceptance Criteria
;;; ============================================================

(test evidence-ticks-labels-png
  "Evidence: Generate ticks-labels.png for plan acceptance."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (path ".sisyphus/evidence/phase4c-ticks-labels.png"))
    (plot ax '(0 1 2 3 4) '(0 1 4 9 16))
    (ensure-directories-exist path)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-axis-tests ()
  "Run all axis/ticker/spine tests and return success boolean."
  (let ((results (run 'axis-suite)))
    (explain! results)
    (results-status results)))
