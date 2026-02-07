;;;; decorators.lisp — FiveAM macros for image comparison tests
;;;; Phase 8a: Test infrastructure for visual regression testing
;;;;
;;;; Port of matplotlib.testing.decorators, adapted for FiveAM.

(in-package #:cl-matplotlib.testing)

;;; ============================================================
;;; Result directory management
;;; ============================================================

(defparameter *result-dir* nil
  "Directory for storing test output images. If NIL, uses /tmp/cl-matplotlib-test-results/.")

(defun result-dir ()
  "Return the result images directory path, creating it if needed."
  (let ((dir (or *result-dir*
                 (merge-pathnames #P"cl-matplotlib-test-results/"
                                  (uiop:temporary-directory)))))
    (ensure-directories-exist dir)
    dir))

(defun result-path (suite-name test-name &key (extension "png"))
  "Return the output path for a test's generated image."
  (let ((path (merge-pathnames
               (make-pathname :directory (list :relative (string-downcase (string suite-name)))
                              :name (string-downcase (string test-name))
                              :type extension)
               (result-dir))))
    (ensure-directories-exist path)
    path))

;;; ============================================================
;;; def-image-test macro
;;; ============================================================

(defmacro def-image-test (name (&key (suite nil suite-p)
                                     (tolerance '*image-tolerance*)
                                     (baseline-suite nil)
                                     (save-baseline nil))
                          &body body)
  "Define a FiveAM image comparison test.

NAME is the test name (a symbol).
SUITE is the FiveAM suite (defaults to current suite).
TOLERANCE is the max RMS difference allowed (default: *image-tolerance*).
BASELINE-SUITE overrides the suite name used for baseline lookup.
SAVE-BASELINE when T, if no baseline exists, saves the output as baseline.

BODY should generate a PNG image. It receives OUTPUT-FILE as the path
where the image should be written.

Example:
  (def-image-test my-plot-test (:suite my-suite :tolerance 1.0)
    ;; OUTPUT-FILE is bound to the path where you should save your image
    (let ((fig (make-figure ...)))
      (savefig fig output-file)))

The macro:
1. Binds OUTPUT-FILE to a temporary result path
2. Executes BODY (which should create the image at OUTPUT-FILE)
3. Looks up the baseline image
4. If no baseline: optionally saves current as baseline, or skips
5. Compares output against baseline
6. Asserts RMS <= tolerance"
  (let ((test-name name)
        (suite-for-baseline (or baseline-suite
                                (if suite-p suite nil))))
    `(fiveam:test ,@(if suite-p
                        `((,test-name :suite ,suite))
                        `(,test-name))
       (let* ((%suite-name ,(if suite-for-baseline
                                `',suite-for-baseline
                                `(or fiveam::*suite* 'default)))
              (%test-name ',test-name)
              (output-file (namestring (result-path %suite-name %test-name)))
              (%tolerance ,tolerance))
         ;; Execute body to generate image
         ,@body
         ;; Verify output was created
         (fiveam:is (probe-file output-file)
                    "Test ~A did not generate output image at ~A"
                    %test-name output-file)
         ;; Find or create baseline
         (let ((baseline (find-baseline %suite-name %test-name)))
           (cond
             ;; Baseline exists — compare
             (baseline
              (let ((result (compare-images (namestring baseline) output-file
                                            :tolerance %tolerance)))
                (fiveam:is (getf result :passed)
                           "Image comparison failed for ~A: RMS=~,4F (tolerance=~,4F)"
                           %test-name (getf result :rms) %tolerance)))
             ;; No baseline, save-baseline mode — save and pass
             (,save-baseline
              (let ((bp (baseline-path %suite-name %test-name)))
                (uiop:copy-file output-file bp)
                (fiveam:pass "Saved new baseline for ~A at ~A" %test-name bp)))
             ;; No baseline, no save — skip with warning
             (t
              (fiveam:skip "No baseline image for ~A (suite ~A). Generate baselines first."
                           %test-name %suite-name))))))))

;;; ============================================================
;;; def-figures-equal macro
;;; ============================================================

(defmacro def-figures-equal (name (&key (suite nil suite-p)
                                        (tolerance '*image-tolerance*))
                             &body body)
  "Define a FiveAM test that compares two generated figures.
Port of matplotlib's check_figures_equal decorator.

BODY receives FIG-TEST and FIG-REF bindings. Draw the test image
on FIG-TEST and the reference image on FIG-REF. After BODY, both
are saved and compared.

Example:
  (def-figures-equal my-test (:tolerance 0.5)
    ;; FIG-TEST and FIG-REF are bound
    (draw-something fig-test)
    (draw-reference fig-ref))"
  `(fiveam:test ,@(if suite-p
                      `((,name :suite ,suite))
                      `(,name))
     (let* ((%test-name ',name)
            (test-path (namestring (result-path
                                    ,(if suite-p `',suite `'default)
                                    (intern (format nil "~A-TEST" %test-name)
                                            :keyword))))
            (ref-path (namestring (result-path
                                   ,(if suite-p `',suite `'default)
                                   (intern (format nil "~A-REF" %test-name)
                                           :keyword))))
            (fig-test test-path)
            (fig-ref ref-path)
            (%tolerance ,tolerance))
       ;; Execute body with fig-test and fig-ref bound
       ,@body
       ;; Verify both images were created
       (fiveam:is (probe-file test-path)
                  "Test figure not generated at ~A" test-path)
       (fiveam:is (probe-file ref-path)
                  "Reference figure not generated at ~A" ref-path)
       ;; Compare
       (when (and (probe-file test-path) (probe-file ref-path))
         (let ((result (compare-images ref-path test-path :tolerance %tolerance)))
           (fiveam:is (getf result :passed)
                      "Figures not equal for ~A: RMS=~,4F (tolerance=~,4F)"
                      %test-name (getf result :rms) %tolerance))))))

;;; ============================================================
;;; Utility: generate and update baselines
;;; ============================================================

(defun update-baseline (suite-name test-name source-path)
  "Copy a test output image as the new baseline for the given test."
  (let ((bp (baseline-path suite-name test-name)))
    (uiop:copy-file source-path bp)
    (format t "Updated baseline: ~A~%" bp)
    bp))

(defun list-missing-baselines (suite-name test-names)
  "Return a list of test names that have no baseline image."
  (remove-if (lambda (name)
               (find-baseline suite-name name))
             test-names))
