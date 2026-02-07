;;;; test-scale.lisp — Tests for scale system (Phase 5a)

(defpackage #:cl-matplotlib.tests.scale
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.primitives
                #:log-transform #:inverted-log-transform
                #:symlog-transform #:inverted-symlog-transform
                #:logit-transform #:logistic-transform
                #:func-transform
                #:transform-point #:invert)
  (:import-from #:cl-matplotlib.containers
                #:scale-base #:linear-scale #:log-scale #:symlog-scale
                #:logit-scale #:func-scale
                #:make-scale #:scale-get-transform
                #:scale-set-default-locators-and-formatters
                #:scale-limit-range-for-scale
                #:make-figure #:add-subplot
                #:plot #:axes-set-xscale #:axes-set-yscale
                #:savefig
                #:axis-scale #:axis-major-locator #:axis-major-formatter
                #:log-locator #:log-formatter)
  (:export #:run-scale-tests))

(in-package #:cl-matplotlib.tests.scale)

(def-suite scale-tests
  :description "Tests for scale system (Phase 5a)")

(in-suite scale-tests)

;;; ============================================================
;;; Transform tests
;;; ============================================================

(test log-transform-forward
  "Test LogTransform forward transformation"
  (let ((tr (make-instance 'log-transform :base 10.0d0)))
    ;; log10(10) = 1
    (let ((result (transform-point tr '(10.0d0 5.0d0))))
      (is (< (abs (- (aref result 0) 1.0d0)) 1.0d-6))
      (is (= (aref result 1) 5.0d0)))
    ;; log10(100) = 2
    (let ((result (transform-point tr '(100.0d0 0.0d0))))
      (is (< (abs (- (aref result 0) 2.0d0)) 1.0d-6)))
    ;; log10(1) = 0
    (let ((result (transform-point tr '(1.0d0 0.0d0))))
      (is (< (abs (aref result 0)) 1.0d-6)))))

(test log-transform-inverse
  "Test LogTransform inversion"
  (let* ((tr (make-instance 'log-transform :base 10.0d0))
         (inv (invert tr)))
    (is (typep inv 'inverted-log-transform))
    ;; 10^2 = 100
    (let ((result (transform-point inv '(2.0d0 0.0d0))))
      (is (< (abs (- (aref result 0) 100.0d0)) 1.0d-6)))
    ;; 10^0 = 1
    (let ((result (transform-point inv '(0.0d0 0.0d0))))
      (is (< (abs (- (aref result 0) 1.0d0)) 1.0d-6)))))

(test log-transform-roundtrip
  "Test LogTransform round-trip"
  (let* ((tr (make-instance 'log-transform :base 10.0d0))
         (inv (invert tr)))
    (loop for x in '(1.0d0 10.0d0 100.0d0 1000.0d0) do
      (let* ((fwd (transform-point tr (list x 0.0d0)))
             (back (transform-point inv (list (aref fwd 0) 0.0d0))))
        (is (< (abs (- (aref back 0) x)) 1.0d-5))))))

(test symlog-transform-linear-region
  "Test SymLogTransform in linear region"
  (let ((tr (make-instance 'symlog-transform :base 10.0d0 :linthresh 2.0d0 :linscale 1.0d0)))
    ;; Values within [-2, 2] should be approximately linear
    (let ((result1 (transform-point tr '(0.0d0 0.0d0)))
          (result2 (transform-point tr '(1.0d0 0.0d0))))
      (is (< (abs (aref result1 0)) 1.0d-6))
      (is (> (aref result2 0) 0.0d0)))))

(test symlog-transform-log-region
  "Test SymLogTransform in log region"
  (let ((tr (make-instance 'symlog-transform :base 10.0d0 :linthresh 2.0d0 :linscale 1.0d0)))
    ;; Values outside [-2, 2] should be logarithmic
    (let ((result (transform-point tr '(100.0d0 0.0d0))))
      (is (> (aref result 0) 0.0d0)))))

(test symlog-transform-symmetric
  "Test SymLogTransform symmetry"
  (let ((tr (make-instance 'symlog-transform :base 10.0d0 :linthresh 2.0d0 :linscale 1.0d0)))
    (let ((pos (transform-point tr '(100.0d0 0.0d0)))
          (neg (transform-point tr '(-100.0d0 0.0d0))))
      ;; Should be symmetric: f(-x) = -f(x)
      (is (< (abs (+ (aref pos 0) (aref neg 0))) 1.0d-5)))))

(test logit-transform-forward
  "Test LogitTransform forward transformation"
  (let ((tr (make-instance 'logit-transform)))
    ;; logit(0.5) = log10(0.5 / 0.5) = log10(1) = 0
    (let ((result (transform-point tr '(0.5d0 0.0d0))))
      (is (< (abs (aref result 0)) 1.0d-6)))
    ;; logit(0.9) should be positive
    (let ((result (transform-point tr '(0.9d0 0.0d0))))
      (is (> (aref result 0) 0.0d0)))
    ;; logit(0.1) should be negative
    (let ((result (transform-point tr '(0.1d0 0.0d0))))
      (is (< (aref result 0) 0.0d0)))))

(test logit-transform-roundtrip
  "Test LogitTransform round-trip"
  (let* ((tr (make-instance 'logit-transform))
         (inv (invert tr)))
    (is (typep inv 'logistic-transform))
    (loop for x in '(0.1d0 0.3d0 0.5d0 0.7d0 0.9d0) do
      (let* ((fwd (transform-point tr (list x 0.0d0)))
             (back (transform-point inv (list (aref fwd 0) 0.0d0))))
        (is (< (abs (- (aref back 0) x)) 1.0d-5))))))

(test func-transform-custom
  "Test FuncTransform with custom functions"
  (let ((tr (make-instance 'func-transform
                           :forward (lambda (x) (* x x))
                           :inverse (lambda (x) (sqrt x)))))
    ;; Forward: x^2
    (let ((result (transform-point tr '(3.0d0 0.0d0))))
      (is (< (abs (- (aref result 0) 9.0d0)) 1.0d-6)))
    ;; Inverse: sqrt(x)
    (let* ((inv (invert tr))
           (result (transform-point inv '(9.0d0 0.0d0))))
      (is (< (abs (- (aref result 0) 3.0d0)) 1.0d-6)))))

;;; ============================================================
;;; Scale class tests
;;; ============================================================

(test linear-scale-creation
  "Test LinearScale creation and transform"
  (let ((scale (make-instance 'linear-scale)))
    (is (typep scale 'linear-scale))
    (let ((tr (scale-get-transform scale)))
      (is (typep tr 'mpl.primitives:identity-transform)))))

(test log-scale-creation
  "Test LogScale creation and transform"
  (let ((scale (make-instance 'log-scale :base 10.0d0)))
    (is (typep scale 'log-scale))
    (let ((tr (scale-get-transform scale)))
      (is (typep tr 'log-transform)))))

(test log-scale-limit-range
  "Test LogScale limit-range-for-scale"
  (let ((scale (make-instance 'log-scale)))
    ;; Negative values should be replaced with minpos
    (multiple-value-bind (vmin vmax)
        (scale-limit-range-for-scale scale -10.0d0 100.0d0 1.0d0)
      (is (= vmin 1.0d0))
      (is (= vmax 100.0d0)))
    ;; Both negative should use fallback
    (multiple-value-bind (vmin vmax)
        (scale-limit-range-for-scale scale -10.0d0 -5.0d0 nil)
      (is (> vmin 0.0d0))
      (is (> vmax 0.0d0)))))

(test symlog-scale-creation
  "Test SymLogScale creation"
  (let ((scale (make-instance 'symlog-scale :base 10.0d0 :linthresh 2.0d0)))
    (is (typep scale 'symlog-scale))
    (let ((tr (scale-get-transform scale)))
      (is (typep tr 'symlog-transform)))))

(test logit-scale-creation
  "Test LogitScale creation"
  (let ((scale (make-instance 'logit-scale)))
    (is (typep scale 'logit-scale))
    (let ((tr (scale-get-transform scale)))
      (is (typep tr 'logit-transform)))))

(test logit-scale-limit-range
  "Test LogitScale limit-range-for-scale"
  (let ((scale (make-instance 'logit-scale)))
    ;; Values outside (0, 1) should be clamped
    (multiple-value-bind (vmin vmax)
        (scale-limit-range-for-scale scale -0.5d0 1.5d0 0.01d0)
      (is (> vmin 0.0d0))
      (is (< vmax 1.0d0)))))

(test func-scale-creation
  "Test FuncScale creation"
  (let ((scale (make-instance 'func-scale
                              :functions (list (lambda (x) (* x 2.0d0))
                                               (lambda (x) (/ x 2.0d0))))))
    (is (typep scale 'func-scale))
    (let ((tr (scale-get-transform scale)))
      (is (typep tr 'func-transform)))))

(test make-scale-factory
  "Test make-scale factory function"
  (is (typep (make-scale :linear) 'linear-scale))
  (is (typep (make-scale :log :base 10.0d0) 'log-scale))
  (is (typep (make-scale :symlog :linthresh 2.0d0) 'symlog-scale))
  (is (typep (make-scale :logit) 'logit-scale))
  (is (typep (make-scale :function
                         :functions (list #'identity #'identity))
             'func-scale)))

;;; ============================================================
;;; Axis integration tests
;;; ============================================================

(test axis-set-scale-linear
  "Test setting linear scale on axis"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (xaxis (cl-matplotlib.containers::axes-base-xaxis ax))
         (scale (make-instance 'linear-scale)))
    (cl-matplotlib.containers::axis-set-scale xaxis scale)
    (is (eq (axis-scale xaxis) scale))))

(test axis-set-scale-log
  "Test setting log scale on axis"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (xaxis (cl-matplotlib.containers::axes-base-xaxis ax))
         (scale (make-instance 'log-scale :base 10.0d0)))
    (cl-matplotlib.containers::axis-set-scale xaxis scale)
    (is (eq (axis-scale xaxis) scale))
    ;; Check that locator and formatter were set
    (is (typep (axis-major-locator xaxis) 'log-locator))
    (is (typep (axis-major-formatter xaxis) 'log-formatter))))

;;; ============================================================
;;; Axes integration tests
;;; ============================================================

(test axes-set-xscale-linear
  "Test set-xscale with linear scale"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (axes-set-xscale ax :linear)
    (let ((xaxis (cl-matplotlib.containers::axes-base-xaxis ax)))
      (is (typep (axis-scale xaxis) 'linear-scale)))))

(test axes-set-xscale-log
  "Test set-xscale with log scale"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (axes-set-xscale ax :log)
    (let ((xaxis (cl-matplotlib.containers::axes-base-xaxis ax)))
      (is (typep (axis-scale xaxis) 'log-scale))
      (is (typep (axis-major-locator xaxis) 'log-locator)))))

(test axes-set-yscale-log
  "Test set-yscale with log scale"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (axes-set-yscale ax :log :base 10.0d0)
    (let ((yaxis (cl-matplotlib.containers::axes-base-yaxis ax)))
      (is (typep (axis-scale yaxis) 'log-scale)))))

(test axes-set-xscale-symlog
  "Test set-xscale with symlog scale"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (axes-set-xscale ax :symlog :linthresh 2.0d0)
    (let ((xaxis (cl-matplotlib.containers::axes-base-xaxis ax)))
      (is (typep (axis-scale xaxis) 'symlog-scale)))))

(test axes-set-xscale-logit
  "Test set-xscale with logit scale"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (axes-set-xscale ax :logit)
    (let ((xaxis (cl-matplotlib.containers::axes-base-xaxis ax)))
      (is (typep (axis-scale xaxis) 'logit-scale)))))

(test axes-set-xscale-function
  "Test set-xscale with function scale"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (axes-set-xscale ax :function
                     :functions (list (lambda (x) (* x 2.0d0))
                                      (lambda (x) (/ x 2.0d0))))
    (let ((xaxis (cl-matplotlib.containers::axes-base-xaxis ax)))
      (is (typep (axis-scale xaxis) 'func-scale)))))

;;; ============================================================
;;; Integration test with plotting
;;; ============================================================

(test plot-with-log-scale
  "Test plotting with log scale"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    ;; Plot some data
    (plot ax '(1 10 100 1000) '(1 2 3 4))
    ;; Set log scale
    (axes-set-xscale ax :log)
    ;; Verify scale was set
    (let ((xaxis (cl-matplotlib.containers::axes-base-xaxis ax)))
      (is (typep (axis-scale xaxis) 'log-scale)))))

;;; ============================================================
;;; Test runner
;;; ============================================================

(defun run-scale-tests ()
  "Run all scale tests and return T if all pass, NIL otherwise."
  (let ((results (run 'scale-tests)))
    (explain! results)
    (results-status results)))
