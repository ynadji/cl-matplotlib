;;;; test-colorbar-ported.lisp — Image comparison tests for Colorbar
;;;; Ported from matplotlib's test_colorbar.py using def-image-test
;;;; Phase 8a: Visual regression tests

(defpackage #:cl-matplotlib.tests.colorbar-ported
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.testing
                #:def-image-test
                #:*image-tolerance*
                #:output-file)
  (:import-from #:cl-matplotlib.containers
                #:mpl-colorbar #:colorbar-mappable #:colorbar-cax #:colorbar-ax
                #:colorbar-orientation #:colorbar-label #:colorbar-ticks
                #:colorbar-n-levels #:make-colorbar
                #:axes-base #:mpl-axes
                #:make-figure #:add-subplot #:plot #:scatter
                #:figure-axes #:savefig)
  (:export #:run-colorbar-ported-tests))

(in-package #:cl-matplotlib.tests.colorbar-ported)

(def-suite colorbar-ported-suite
  :description "Image comparison tests for colorbar (ported from matplotlib)")
(in-suite colorbar-ported-suite)

;;; ============================================================
;;; Basic colorbar rendering
;;; ============================================================

(def-image-test colorbar-vertical-default
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Vertical colorbar with default settings."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 100))))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (make-colorbar ax sm)
    (savefig fig output-file)))

(def-image-test colorbar-horizontal
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Horizontal colorbar."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 50))))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (make-colorbar ax sm :orientation :horizontal)
    (savefig fig output-file)))

(def-image-test colorbar-with-label
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Colorbar with label text."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 100))))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (make-colorbar ax sm :label "Temperature (K)")
    (savefig fig output-file)))

(def-image-test colorbar-custom-ticks
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Colorbar with custom tick locations."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 1))))
    (plot ax '(1 2 3) '(1 4 9))
    (make-colorbar ax sm :ticks '(0.0d0 0.25d0 0.5d0 0.75d0 1.0d0))
    (savefig fig output-file)))

(def-image-test colorbar-narrow-range
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Colorbar with narrow data range."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0.48 :vmax 0.52))))
    (plot ax '(1 2 3) '(1 4 9))
    (make-colorbar ax sm)
    (savefig fig output-file)))

(def-image-test colorbar-wide-range
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Colorbar with wide data range."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin -1000 :vmax 1000))))
    (plot ax '(1 2 3) '(1 4 9))
    (make-colorbar ax sm)
    (savefig fig output-file)))

(def-image-test colorbar-high-n-levels
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Colorbar with high number of color levels."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 100))))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (make-colorbar ax sm :n-levels 64)
    (savefig fig output-file)))

;;; ============================================================
;;; Colorbar with different plot types
;;; ============================================================

(def-image-test colorbar-with-scatter
    (:suite colorbar-ported-suite :tolerance 5.0 :save-baseline t)
  "Colorbar alongside a scatter plot."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 10))))
    (scatter ax '(1 2 3 4 5) '(2 4 1 5 3))
    (make-colorbar ax sm :label "Intensity")
    (savefig fig output-file)))

;;; ============================================================
;;; Parametrized: orientation variants
;;; ============================================================

(fiveam:test (colorbar-orientations-render :suite colorbar-ported-suite)
  "Parametrized: both orientations render without error."
  (dolist (orient '(:vertical :horizontal))
    (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 72))
           (ax (add-subplot fig 1 1 1))
           (sm (mpl.primitives:make-scalar-mappable
                :norm (mpl.primitives:make-normalize :vmin 0 :vmax 1)))
           (path (format nil "/tmp/cl-mpl-colorbar-ported-~A-~A.png"
                         (string-downcase (string orient)) (get-universal-time))))
      (plot ax '(1 2 3) '(1 2 3))
      (make-colorbar ax sm :orientation orient)
      (savefig fig path)
      (is (probe-file path))
      (when (probe-file path) (delete-file path)))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-colorbar-ported-tests ()
  "Run all ported colorbar tests and return results."
  (let ((results (run 'colorbar-ported-suite)))
    (explain! results)
    (results-status results)))
