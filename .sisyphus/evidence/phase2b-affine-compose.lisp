;;;; Phase 2b Acceptance Scenario 1: Affine transform composition
(ql:quickload :cl-matplotlib-primitives)
(in-package #:cl-matplotlib.primitives)

(format t "~%=== Scenario 1: Affine transform composition ===~%")

;; Create scale(2, 3) and translate(10, 20) transforms
(let* ((scale (make-affine-2d :scale '(2.0 3.0)))
       (translate (make-affine-2d :translate '(10.0 20.0))))
  ;; Compose them: scale first, then translate
  (let ((composed (compose scale translate)))
    ;; Transform point (1, 1): scale → (2, 3) → translate → (12, 23)
    (let ((result (transform-point composed #(1.0d0 1.0d0))))
      (format t "Transform (1, 1) → (~,1f, ~,1f) [expected: (12.0, 23.0)]~%"
              (aref result 0) (aref result 1))
      (assert (< (abs (- (aref result 0) 12.0d0)) 1d-10))
      (assert (< (abs (- (aref result 1) 23.0d0)) 1d-10)))
    
    ;; Get inverse, transform (12, 23) → (1, 1)
    (let* ((inv (invert composed))
           (back (transform-point inv #(12.0d0 23.0d0))))
      (format t "Inverse (12, 23) → (~,1f, ~,1f) [expected: (1.0, 1.0)]~%"
              (aref back 0) (aref back 1))
      (assert (< (abs (- (aref back 0) 1.0d0)) 1d-10))
      (assert (< (abs (- (aref back 1) 1.0d0)) 1d-10)))))

(format t "~%SCENARIO 1: PASS~%")
