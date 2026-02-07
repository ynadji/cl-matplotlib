;;;; test-testing.lisp — Tests for the testing infrastructure itself
;;;; Phase 8a: Verify RMS, SSIM, compare-images, baseline management, macros

(defpackage #:cl-matplotlib.tests.testing
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.testing
                #:load-png-as-array
                #:calculate-rms
                #:calculate-ssim
                #:compare-images
                #:save-diff-image
                #:*image-tolerance*
                #:*baseline-dir*
                #:baseline-dir
                #:find-baseline
                #:baseline-path
                #:*result-dir*
                #:result-dir
                #:result-path
                #:def-image-test
                #:def-figures-equal
                #:update-baseline
                #:list-missing-baselines)
  (:export #:run-testing-tests))

(in-package #:cl-matplotlib.tests.testing)

(def-suite testing-infrastructure-suite
  :description "Tests for image comparison testing infrastructure")
(in-suite testing-infrastructure-suite)

;;; ============================================================
;;; Helper: create test PNG images programmatically
;;; ============================================================

(defun make-solid-png (path width height r g b &optional (a 255))
  "Create a solid-color PNG image at PATH."
  (let* ((png (make-instance 'zpng:png
                             :width width :height height
                             :color-type (if (= a 255) :truecolor :truecolor-alpha)))
         (data (zpng:image-data png))
         (channels (if (= a 255) 3 4)))
    (dotimes (j height)
      (dotimes (i width)
        (let ((offset (* (+ (* j width) i) channels)))
          (setf (aref data (+ offset 0)) r)
          (setf (aref data (+ offset 1)) g)
          (setf (aref data (+ offset 2)) b)
          (when (= channels 4)
            (setf (aref data (+ offset 3)) a)))))
    (zpng:write-png png path)
    path))

(defun make-gradient-png (path width height &key (direction :horizontal))
  "Create a gradient PNG image at PATH."
  (let* ((png (make-instance 'zpng:png
                             :width width :height height
                             :color-type :truecolor))
         (data (zpng:image-data png)))
    (dotimes (j height)
      (dotimes (i width)
        (let* ((offset (* (+ (* j width) i) 3))
               (v (case direction
                    (:horizontal (floor (* 255 i) width))
                    (:vertical (floor (* 255 j) height))
                    (t (floor (* 255 (+ i j)) (+ width height))))))
          (setf (aref data (+ offset 0)) v)
          (setf (aref data (+ offset 1)) v)
          (setf (aref data (+ offset 2)) v))))
    (zpng:write-png png path)
    path))

(defun make-checkerboard-png (path width height &key (cell-size 8))
  "Create a checkerboard PNG image at PATH."
  (let* ((png (make-instance 'zpng:png
                             :width width :height height
                             :color-type :truecolor))
         (data (zpng:image-data png)))
    (dotimes (j height)
      (dotimes (i width)
        (let* ((offset (* (+ (* j width) i) 3))
               (checker (if (evenp (+ (floor i cell-size) (floor j cell-size)))
                            255 0)))
          (setf (aref data (+ offset 0)) checker)
          (setf (aref data (+ offset 1)) checker)
          (setf (aref data (+ offset 2)) checker))))
    (zpng:write-png png path)
    path))

(defun tmp-png (name)
  "Generate a unique temporary PNG path."
  (format nil "/tmp/cl-mpl-test-infra-~A-~A.png" name (get-universal-time)))

;;; ============================================================
;;; PNG loading tests
;;; ============================================================

(test load-png-truecolor
  "Load a truecolor PNG and verify dimensions/channels."
  (let ((path (tmp-png "load-tc")))
    (make-solid-png path 10 8 128 64 32)
    (multiple-value-bind (data h w c) (load-png-as-array path)
      (is (= h 8))
      (is (= w 10))
      (is (= c 3))
      ;; Check pixel values
      (is (= (aref data 0 0 0) 128))
      (is (= (aref data 0 0 1) 64))
      (is (= (aref data 0 0 2) 32)))
    (delete-file path)))

(test load-png-truecolor-alpha
  "Load a truecolor-alpha PNG and verify dimensions/channels."
  (let ((path (tmp-png "load-tca")))
    (make-solid-png path 10 8 128 64 32 200)
    (multiple-value-bind (data h w c) (load-png-as-array path)
      (is (= h 8))
      (is (= w 10))
      (is (= c 4))
      (is (= (aref data 0 0 3) 200)))
    (delete-file path)))

;;; ============================================================
;;; RMS tests
;;; ============================================================

(test rms-identical-images
  "RMS of identical images should be 0."
  (let ((path (tmp-png "rms-id")))
    (make-solid-png path 20 20 100 100 100)
    (let ((data (load-png-as-array path)))
      (is (< (calculate-rms data data) 0.001d0)))
    (delete-file path)))

(test rms-different-images
  "RMS of completely different images should be high."
  (let ((path1 (tmp-png "rms-d1"))
        (path2 (tmp-png "rms-d2")))
    (make-solid-png path1 20 20 0 0 0)
    (make-solid-png path2 20 20 255 255 255)
    (let ((data1 (load-png-as-array path1))
          (data2 (load-png-as-array path2)))
      (let ((rms (calculate-rms data1 data2)))
        ;; Black vs white: each channel differs by 255
        ;; RMS = sqrt(sum(255^2 * 3 * 400) / (3 * 400)) = 255
        (is (> rms 254.0d0))
        (is (< rms 256.0d0))))
    (delete-file path1)
    (delete-file path2)))

(test rms-slightly-different
  "RMS of slightly different images should be small."
  (let ((path1 (tmp-png "rms-s1"))
        (path2 (tmp-png "rms-s2")))
    (make-solid-png path1 20 20 100 100 100)
    (make-solid-png path2 20 20 101 101 101)
    (let ((data1 (load-png-as-array path1))
          (data2 (load-png-as-array path2)))
      (let ((rms (calculate-rms data1 data2)))
        ;; Each channel differs by 1, RMS = sqrt(1^2) = 1.0
        (is (> rms 0.9d0))
        (is (< rms 1.1d0))))
    (delete-file path1)
    (delete-file path2)))

(test rms-dimension-mismatch
  "RMS should error on dimension mismatch."
  (let ((path1 (tmp-png "rms-m1"))
        (path2 (tmp-png "rms-m2")))
    (make-solid-png path1 20 20 100 100 100)
    (make-solid-png path2 30 30 100 100 100)
    (let ((data1 (load-png-as-array path1))
          (data2 (load-png-as-array path2)))
      (signals error (calculate-rms data1 data2)))
    (delete-file path1)
    (delete-file path2)))

;;; ============================================================
;;; SSIM tests
;;; ============================================================

(test ssim-identical-images
  "SSIM of identical images should be 1.0."
  (let ((path (tmp-png "ssim-id")))
    (make-gradient-png path 32 32 :direction :horizontal)
    (let ((data (load-png-as-array path)))
      (let ((ssim (calculate-ssim data data)))
        (is (> ssim 0.999d0))))
    (delete-file path)))

(test ssim-completely-different
  "SSIM of very different images should be low."
  (let ((path1 (tmp-png "ssim-d1"))
        (path2 (tmp-png "ssim-d2")))
    (make-solid-png path1 32 32 0 0 0)
    (make-solid-png path2 32 32 255 255 255)
    (let ((data1 (load-png-as-array path1))
          (data2 (load-png-as-array path2)))
      (let ((ssim (calculate-ssim data1 data2)))
        ;; SSIM should be very low for black vs white
        (is (< ssim 0.1d0))))
    (delete-file path1)
    (delete-file path2)))

(test ssim-similar-images
  "SSIM of similar images should be close to 1.0."
  (let ((path1 (tmp-png "ssim-s1"))
        (path2 (tmp-png "ssim-s2")))
    (make-solid-png path1 32 32 100 100 100)
    (make-solid-png path2 32 32 102 102 102)
    (let ((data1 (load-png-as-array path1))
          (data2 (load-png-as-array path2)))
      (let ((ssim (calculate-ssim data1 data2)))
        (is (> ssim 0.99d0))))
    (delete-file path1)
    (delete-file path2)))

(test ssim-range
  "SSIM should always be in [-1, 1] range."
  (let ((path1 (tmp-png "ssim-r1"))
        (path2 (tmp-png "ssim-r2")))
    (make-checkerboard-png path1 32 32)
    (make-gradient-png path2 32 32)
    (let ((data1 (load-png-as-array path1))
          (data2 (load-png-as-array path2)))
      (let ((ssim (calculate-ssim data1 data2)))
        (is (<= -1.0d0 ssim))
        (is (<= ssim 1.0d0))))
    (delete-file path1)
    (delete-file path2)))

;;; ============================================================
;;; compare-images tests
;;; ============================================================

(test compare-images-identical
  "compare-images should report pass for identical images."
  (let ((path1 (tmp-png "ci-id1"))
        (path2 (tmp-png "ci-id2")))
    (make-solid-png path1 20 20 128 128 128)
    (make-solid-png path2 20 20 128 128 128)
    (let ((result (compare-images path1 path2)))
      (is (getf result :passed))
      (is (< (getf result :rms) 0.001d0))
      (is (> (getf result :ssim) 0.999d0)))
    (delete-file path1)
    (delete-file path2)))

(test compare-images-different
  "compare-images should report fail for very different images."
  (let ((path1 (tmp-png "ci-df1"))
        (path2 (tmp-png "ci-df2")))
    (make-solid-png path1 20 20 0 0 0)
    (make-solid-png path2 20 20 255 255 255)
    (let ((result (compare-images path1 path2)))
      (is (not (getf result :passed)))
      (is (> (getf result :rms) 200.0d0)))
    (delete-file path1)
    (delete-file path2)))

(test compare-images-within-tolerance
  "compare-images should pass for images within tolerance."
  (let ((path1 (tmp-png "ci-tol1"))
        (path2 (tmp-png "ci-tol2")))
    (make-solid-png path1 20 20 100 100 100)
    (make-solid-png path2 20 20 102 102 102)
    ;; RMS will be ~2.0, so tolerance of 3 should pass
    (let ((result (compare-images path1 path2 :tolerance 3.0d0)))
      (is (getf result :passed)))
    ;; But tolerance of 0.5 should fail
    (let ((result (compare-images path1 path2 :tolerance 0.5d0)))
      (is (not (getf result :passed))))
    (delete-file path1)
    (delete-file path2)))

(test compare-images-missing-file
  "compare-images should error on missing files."
  (signals error (compare-images "/nonexistent/file.png" "/tmp/also-nonexistent.png")))

(test compare-images-result-keys
  "compare-images result should contain all expected keys."
  (let ((path1 (tmp-png "ci-keys1"))
        (path2 (tmp-png "ci-keys2")))
    (make-solid-png path1 10 10 100 100 100)
    (make-solid-png path2 10 10 100 100 100)
    (let ((result (compare-images path1 path2)))
      (is (not (null (getf result :rms))))
      (is (not (null (getf result :ssim))))
      (is (not (null (member :passed result))))
      (is (not (null (getf result :tolerance))))
      (is (not (null (getf result :expected))))
      (is (not (null (getf result :actual)))))
    (delete-file path1)
    (delete-file path2)))

;;; ============================================================
;;; Baseline directory management tests
;;; ============================================================

(test baseline-dir-creation
  "baseline-dir should create the directory if needed."
  (let ((*baseline-dir* (merge-pathnames
                          #P"test-bl-tmp/"
                          (uiop:temporary-directory))))
    (let ((dir (baseline-dir)))
      (is (uiop:directory-exists-p dir))
      ;; Cleanup
      (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore))))

(test baseline-path-creation
  "baseline-path should create intermediate directories."
  (let ((*baseline-dir* (merge-pathnames
                          #P"test-bp-tmp/"
                          (uiop:temporary-directory))))
    (let ((path (baseline-path "my-suite" "my-test")))
      (is (stringp (namestring path)))
      ;; Should contain suite name in path
      (is (search "my-suite" (namestring path)))
      ;; Cleanup
      (uiop:delete-directory-tree *baseline-dir* :validate t :if-does-not-exist :ignore))))

(test find-baseline-missing
  "find-baseline should return NIL for non-existent baselines."
  (let ((*baseline-dir* (merge-pathnames
                          #P"test-fb-tmp/"
                          (uiop:temporary-directory))))
    (is (null (find-baseline "nonexistent-suite" "nonexistent-test")))
    (uiop:delete-directory-tree *baseline-dir* :validate t :if-does-not-exist :ignore)))

(test find-baseline-existing
  "find-baseline should return path for existing baselines."
  (let ((*baseline-dir* (merge-pathnames
                          #P"test-fbe-tmp/"
                          (uiop:temporary-directory))))
    ;; Create a baseline
    (let ((bp (baseline-path "test-suite" "test-case")))
      (make-solid-png (namestring bp) 10 10 128 128 128)
      ;; Now find it
      (let ((found (find-baseline "test-suite" "test-case")))
        (is (not (null found)))
        (is (probe-file found))))
    (uiop:delete-directory-tree *baseline-dir* :validate t :if-does-not-exist :ignore)))

;;; ============================================================
;;; Result directory tests
;;; ============================================================

(test result-dir-creation
  "result-dir should create the directory if needed."
  (let ((*result-dir* (merge-pathnames
                        #P"test-rd-tmp/"
                        (uiop:temporary-directory))))
    (let ((dir (result-dir)))
      (is (uiop:directory-exists-p dir)))
    (uiop:delete-directory-tree *result-dir* :validate t :if-does-not-exist :ignore)))

(test result-path-format
  "result-path should create proper paths with suite/test structure."
  (let ((*result-dir* (merge-pathnames
                        #P"test-rp-tmp/"
                        (uiop:temporary-directory))))
    (let ((path (result-path "my-suite" "my-test")))
      (is (search "my-suite" (namestring path)))
      (is (search "my-test" (namestring path)))
      (is (search ".png" (namestring path))))
    (uiop:delete-directory-tree *result-dir* :validate t :if-does-not-exist :ignore)))

;;; ============================================================
;;; save-diff-image tests
;;; ============================================================

(test save-diff-image-creates-file
  "save-diff-image should create a valid PNG diff."
  (let ((path1 (tmp-png "diff1"))
        (path2 (tmp-png "diff2"))
        (diff-path (tmp-png "diff-out")))
    (make-solid-png path1 20 20 100 100 100)
    (make-solid-png path2 20 20 120 80 100)
    (save-diff-image path1 path2 diff-path)
    (is (probe-file diff-path))
    ;; Verify it's a valid PNG
    (multiple-value-bind (data h w c) (load-png-as-array diff-path)
      (declare (ignore c))
      (is (= h 20))
      (is (= w 20))
      ;; Red channel diff: |100-120|*10 = 200
      ;; Green channel diff: |100-80|*10 = 200
      ;; Blue channel diff: |100-100|*10 = 0
      (is (= (aref data 0 0 0) 200))
      (is (= (aref data 0 0 1) 200))
      (is (= (aref data 0 0 2) 0)))
    (delete-file path1)
    (delete-file path2)
    (delete-file diff-path)))

;;; ============================================================
;;; update-baseline tests
;;; ============================================================

(test update-baseline-copies-file
  "update-baseline should copy a file to the baseline location."
  (let ((*baseline-dir* (merge-pathnames
                          #P"test-ub-tmp/"
                          (uiop:temporary-directory))))
    (let ((source (tmp-png "ub-src")))
      (make-solid-png source 10 10 42 42 42)
      (update-baseline "my-suite" "my-test" source)
      (let ((bl (find-baseline "my-suite" "my-test")))
        (is (not (null bl)))
        (is (probe-file bl)))
      (delete-file source))
    (uiop:delete-directory-tree *baseline-dir* :validate t :if-does-not-exist :ignore)))

;;; ============================================================
;;; list-missing-baselines tests
;;; ============================================================

(test list-missing-baselines-all-missing
  "list-missing-baselines should return all when none exist."
  (let ((*baseline-dir* (merge-pathnames
                          #P"test-lmb-tmp/"
                          (uiop:temporary-directory))))
    (let ((missing (list-missing-baselines "suite" '("a" "b" "c"))))
      (is (= (length missing) 3)))
    (uiop:delete-directory-tree *baseline-dir* :validate t :if-does-not-exist :ignore)))

(test list-missing-baselines-some-present
  "list-missing-baselines should only return missing ones."
  (let ((*baseline-dir* (merge-pathnames
                          #P"test-lmb2-tmp/"
                          (uiop:temporary-directory))))
    ;; Create baseline for "b"
    (let ((bp (baseline-path "suite" "b")))
      (make-solid-png (namestring bp) 5 5 0 0 0))
    (let ((missing (list-missing-baselines "suite" '("a" "b" "c"))))
      (is (= (length missing) 2))
      (is (member "a" missing :test #'string=))
      (is (not (member "b" missing :test #'string=)))
      (is (member "c" missing :test #'string=)))
    (uiop:delete-directory-tree *baseline-dir* :validate t :if-does-not-exist :ignore)))

;;; ============================================================
;;; Image tolerance tests
;;; ============================================================

(test default-tolerance
  "*image-tolerance* should have a reasonable default."
  (is (numberp *image-tolerance*))
  (is (> *image-tolerance* 0))
  (is (< *image-tolerance* 50)))

(test custom-tolerance
  "compare-images should respect custom tolerance."
  (let ((path1 (tmp-png "tol1"))
        (path2 (tmp-png "tol2")))
    (make-solid-png path1 10 10 100 100 100)
    (make-solid-png path2 10 10 105 105 105)
    ;; RMS ~= 5.0
    (let ((strict (compare-images path1 path2 :tolerance 1.0d0))
          (lenient (compare-images path1 path2 :tolerance 10.0d0)))
      (is (not (getf strict :passed)))
      (is (getf lenient :passed)))
    (delete-file path1)
    (delete-file path2)))

;;; ============================================================
;;; Gradient image comparison (more realistic)
;;; ============================================================

(test gradient-rms-and-ssim
  "RMS and SSIM should correlate for gradient images."
  (let ((path1 (tmp-png "grad1"))
        (path2 (tmp-png "grad2")))
    (make-gradient-png path1 64 64 :direction :horizontal)
    (make-gradient-png path2 64 64 :direction :vertical)
    (let ((result (compare-images path1 path2 :tolerance 1000.0d0)))
      ;; Different gradients should have measurable RMS
      (is (> (getf result :rms) 0.0d0))
      ;; SSIM should be less than 1 but still positive
      (is (< (getf result :ssim) 1.0d0))
      (is (> (getf result :ssim) -1.0d0)))
    (delete-file path1)
    (delete-file path2)))

;;; ============================================================
;;; Checkerboard pattern tests
;;; ============================================================

(test checkerboard-self-comparison
  "Checkerboard compared to itself should be perfect."
  (let ((path (tmp-png "check-self")))
    (make-checkerboard-png path 32 32 :cell-size 4)
    (let ((result (compare-images path path)))
      (is (getf result :passed))
      (is (< (getf result :rms) 0.001d0))
      (is (> (getf result :ssim) 0.999d0)))
    (delete-file path)))

;;; ============================================================
;;; Run function
;;; ============================================================

(defun run-testing-tests ()
  "Run all testing infrastructure tests."
  (let ((results (run 'testing-infrastructure-suite)))
    (explain! results)
    (unless (results-status results)
      (error "Testing infrastructure tests failed!"))))
