;;;; test-polar.lisp — Tests for PolarAxes
;;;; FiveAM test suite

(defpackage #:cl-matplotlib.tests.polar
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; AxesBase
                #:axes-base #:axes-base-figure #:axes-base-position
                #:axes-base-trans-data #:axes-base-trans-axes
                #:axes-base-data-lim #:axes-base-view-lim
                #:axes-base-lines #:axes-base-patches #:axes-base-artists
                ;; PolarAxes
                #:polar-axes
                ;; Plotting functions
                #:plot
                ;; Figure
                #:mpl-figure #:make-figure
                #:figure-axes
                #:savefig)
  (:export #:run-polar-tests))

(in-package #:cl-matplotlib.tests.polar)

(def-suite polar-suite :description "Polar axes test suite")
(in-suite polar-suite)

;;; ============================================================
;;; Creation Tests
;;; ============================================================

(test polar-axes-creation
  "polar-axes can be instantiated"
  (let* ((fig (make-figure))
         (ax (make-instance 'polar-axes :figure fig
                            :position '(0.125d0 0.11d0 0.775d0 0.77d0))))
    (is (typep ax 'polar-axes))
    (is (typep ax 'axes-base))
    (is (not (null (axes-base-trans-data ax))))))

(test polar-axes-transform-setup
  "polar-axes has polar transform pipeline"
  (let* ((fig (make-figure))
         (ax (make-instance 'polar-axes :figure fig
                            :position '(0.125d0 0.11d0 0.775d0 0.77d0))))
    (is (not (null (axes-base-trans-axes ax))))
    (is (not (null (axes-base-trans-data ax))))
    ;; View limits should be 0→2π for theta, 0→1 for r
    (let ((vlim (axes-base-view-lim ax)))
      (is (< (abs (- (mpl.primitives:bbox-x0 vlim) 0.0d0)) 0.001))
      (is (< (abs (- (mpl.primitives:bbox-x1 vlim) (* 2.0d0 pi))) 0.001))
      (is (< (abs (- (mpl.primitives:bbox-y0 vlim) 0.0d0)) 0.001))
      (is (< (abs (- (mpl.primitives:bbox-y1 vlim) 1.0d0)) 0.001)))))

;;; ============================================================
;;; Plot data tests
;;; ============================================================

(test polar-axes-plot
  "polar-axes accepts plot data"
  (let* ((fig (make-figure))
         (ax (make-instance 'polar-axes :figure fig
                            :position '(0.125d0 0.11d0 0.775d0 0.77d0))))
    (plot ax '(0.0d0 1.5707963d0 3.14159265d0) '(1.0d0 1.0d0 1.0d0))
    (is (not (null (axes-base-lines ax))))))

;;; ============================================================
;;; Savefig test
;;; ============================================================

(test polar-axes-savefig
  "polar-axes renders to PNG without error"
  (let* ((fig (make-figure))
         (ax (make-instance 'polar-axes :figure fig
                            :position '(0.125d0 0.11d0 0.775d0 0.77d0))))
    (push ax (figure-axes fig))
    (let ((theta (loop for i from 0 to 100
                       collect (* i (/ (* 2.0d0 pi) 100.0d0))))
          (r (loop for i from 0 to 100
                   collect (+ 1.0d0 (cos (* i (/ (* 2.0d0 pi) 100.0d0)))))))
      (plot ax theta r))
    (let ((path "/tmp/cl-mpl-test-polar.png"))
      (savefig fig path)
      (is (probe-file path)))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-polar-tests ()
  (run! 'polar-suite))
