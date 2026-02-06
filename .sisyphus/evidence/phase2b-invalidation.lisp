;;;; Phase 2b Acceptance Scenario 2: Invalidation caching works
(ql:quickload :cl-matplotlib-primitives)
(in-package #:cl-matplotlib.primitives)

(format t "~%=== Scenario 2: Invalidation caching works ===~%")

;; Create parent and child transforms
(let* ((parent (make-affine-2d :translate '(10.0 20.0)))
       (child (make-affine-2d :scale '(2.0 3.0)))
       (composed (compose parent child)))
  ;; Read composed matrix (should be cached)
  (let ((matrix1 (copy-matrix (get-matrix composed))))
    (format t "Matrix before: [~{~,1f~^ ~}]~%" (coerce matrix1 'list))
    ;; Modify parent
    (set-translate parent '(5.0 10.0))
    ;; Read composed matrix again (should recompute)
    (let ((matrix2 (get-matrix composed)))
      (format t "Matrix after:  [~{~,1f~^ ~}]~%" (coerce matrix2 'list))
      ;; Assert matrices differ
      (let ((differ (not (matrix-equal-p matrix1 matrix2))))
        (format t "Matrices differ: ~A [expected: T]~%" differ)
        (assert differ)))))

(format t "~%SCENARIO 2: PASS~%")
