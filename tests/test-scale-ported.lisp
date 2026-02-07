;;;; test-scale-ported.lisp — Image comparison tests for Scale system
;;;; Ported from matplotlib's test_scale.py using def-image-test
;;;; Phase 8a: Visual regression tests

(defpackage #:cl-matplotlib.tests.scale-ported
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.testing
                #:def-image-test
                #:*image-tolerance*
                #:output-file)
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
                #:scale-limit-range-for-scale
                #:make-figure #:add-subplot
                #:plot #:axes-set-xscale #:axes-set-yscale
                #:savefig)
  (:export #:run-scale-ported-tests))

(in-package #:cl-matplotlib.tests.scale-ported)

(def-suite scale-ported-suite
  :description "Image comparison tests for scale system (ported from matplotlib)")
(in-suite scale-ported-suite)

;;; ============================================================
;;; Linear scale image tests
;;; ============================================================

(def-image-test scale-linear-plot
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Linear scale plot (default)."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4 5) '(1 4 9 16 25))
    (axes-set-xscale ax :linear)
    (axes-set-yscale ax :linear)
    (savefig fig output-file)))

;;; ============================================================
;;; Log scale image tests
;;; ============================================================

(def-image-test scale-log-x
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Log scale on X axis."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 10 100) '(1 2 3))
    (axes-set-xscale ax :log)
    (savefig fig output-file)))

(def-image-test scale-log-y
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Log scale on Y axis."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 10 100))
    (axes-set-yscale ax :log)
    (savefig fig output-file)))

(def-image-test scale-log-both
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Log scale on both axes (log-log plot)."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 10 100) '(1 10 100))
    (axes-set-xscale ax :log)
    (axes-set-yscale ax :log)
    (savefig fig output-file)))

;;; ============================================================
;;; Symlog scale image tests
;;; ============================================================

(def-image-test scale-symlog-x
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Symlog scale on X axis."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -50 to 50 by 10 collect (float i 1.0d0)))
         (y (mapcar (lambda (v) (* v v)) x)))
    (plot ax x y)
    (axes-set-xscale ax :symlog :linthresh 10.0d0)
    (savefig fig output-file)))

(def-image-test scale-symlog-y
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Symlog scale on Y axis — handles negative values."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from 0 to 10 collect (float i 1.0d0)))
         (y (mapcar (lambda (v) (- (* v v) 50.0d0)) x)))
    (plot ax x y)
    (axes-set-yscale ax :symlog :linthresh 5.0d0)
    (savefig fig output-file)))

;;; ============================================================
;;; Logit scale image tests
;;; ============================================================

(def-image-test scale-logit
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Logit scale on Y axis for probability data."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from 1 to 9 collect (float i 1.0d0)))
         (y (mapcar (lambda (v) (/ v 10.0d0)) x)))
    (plot ax x y)
    (axes-set-yscale ax :logit)
    (savefig fig output-file)))

;;; ============================================================
;;; Function scale image tests
;;; ============================================================

(def-image-test scale-function-square
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Custom function scale (x^2 / sqrt)."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4 5) '(1 4 9 16 25))
    (axes-set-xscale ax :function
                     :functions (list (lambda (x) (* x x))
                                      (lambda (x) (sqrt (max 0.0d0 x)))))
    (savefig fig output-file)))

;;; ============================================================
;;; Scale switching
;;; ============================================================

(def-image-test scale-switch-linear-to-log
    (:suite scale-ported-suite :tolerance 5.0 :save-baseline t)
  "Switch from linear to log scale on existing plot."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    ;; Plot with linear scale first (small data)
    (plot ax '(1 10 100) '(1 2 3))
    ;; Then switch to log
    (axes-set-xscale ax :log)
    (savefig fig output-file)))

;;; ============================================================
;;; Transform accuracy tests (non-image, parametrized)
;;; ============================================================

(fiveam:test (scale-log-transform-accuracy :suite scale-ported-suite)
  "Parametrized: log transform accuracy for various bases."
  (dolist (base '(2.0d0 10.0d0))
    (let ((tr (make-instance 'log-transform :base base)))
      ;; Check roundtrip
      (dolist (x '(1.0d0 10.0d0 100.0d0))
        (let* ((fwd (transform-point tr (list x 0.0d0)))
               (inv (invert tr))
               (back (transform-point inv (list (aref fwd 0) 0.0d0))))
          (is (< (abs (- (aref back 0) x)) 1.0d-5)
              "Roundtrip failed for base ~A, x=~A" base x))))))

(fiveam:test (scale-symlog-symmetry :suite scale-ported-suite)
  "Parametrized: symlog transform is symmetric around zero."
  (dolist (linthresh '(1.0d0 2.0d0 10.0d0))
    (let ((tr (make-instance 'symlog-transform
                             :base 10.0d0 :linthresh linthresh :linscale 1.0d0)))
      (dolist (x '(0.5d0 5.0d0 50.0d0 500.0d0))
        (let ((pos (transform-point tr (list x 0.0d0)))
              (neg (transform-point tr (list (- x) 0.0d0))))
          (is (< (abs (+ (aref pos 0) (aref neg 0))) 1.0d-5)
              "Symmetry violated for linthresh=~A, x=~A" linthresh x))))))

(fiveam:test (scale-logit-roundtrip :suite scale-ported-suite)
  "Parametrized: logit transform roundtrip for various values."
  (let* ((tr (make-instance 'logit-transform))
         (inv (invert tr)))
    (dolist (x '(0.01d0 0.1d0 0.3d0 0.5d0 0.7d0 0.9d0 0.99d0))
      (let* ((fwd (transform-point tr (list x 0.0d0)))
             (back (transform-point inv (list (aref fwd 0) 0.0d0))))
        (is (< (abs (- (aref back 0) x)) 1.0d-4)
            "Roundtrip failed for logit x=~A" x)))))

(fiveam:test (scale-factory-types :suite scale-ported-suite)
  "Parametrized: make-scale factory returns correct types."
  (is (typep (make-scale :linear) 'linear-scale))
  (is (typep (make-scale :log :base 10.0d0) 'log-scale))
  (is (typep (make-scale :symlog :linthresh 2.0d0) 'symlog-scale))
  (is (typep (make-scale :logit) 'logit-scale))
  (is (typep (make-scale :function
                         :functions (list #'identity #'identity))
             'func-scale)))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-scale-ported-tests ()
  "Run all ported scale tests and return results."
  (let ((results (run 'scale-ported-suite)))
    (explain! results)
    (results-status results)))
