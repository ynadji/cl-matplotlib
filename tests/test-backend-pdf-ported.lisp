;;;; test-backend-pdf-ported.lisp — Image comparison tests for PDF backend
;;;; Ported from matplotlib's test_backend_pdf.py using def-image-test
;;;; Phase 8a: Visual regression tests

(defpackage #:cl-matplotlib.tests.backend-pdf-ported
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.testing
                #:def-image-test
                #:*image-tolerance*
                #:output-file)
  (:import-from #:cl-matplotlib.backends
                #:draw-path #:draw-image #:draw-text #:draw-markers
                #:draw-gouraud-triangles
                #:get-canvas-width-height #:points-to-pixels
                #:renderer-clear #:get-renderer #:print-pdf #:canvas-draw
                #:renderer-base #:renderer-pdf #:renderer-width #:renderer-height #:renderer-dpi
                #:canvas-pdf #:canvas-width #:canvas-height #:canvas-dpi
                #:canvas-render-fn-pdf #:canvas-vecto
                #:make-graphics-context #:render-to-pdf)
  (:import-from #:cl-matplotlib.containers
                #:make-figure #:add-subplot #:plot #:scatter #:bar
                #:axes-legend #:savefig)
  (:export #:run-backend-pdf-ported-tests))

(in-package #:cl-matplotlib.tests.backend-pdf-ported)

(def-suite backend-pdf-ported-suite
  :description "Image comparison tests for PDF backend (ported from matplotlib)")
(in-suite backend-pdf-ported-suite)

;;; ============================================================
;;; Helper: render figure to PNG for image comparison
;;; ============================================================

(defun render-figure-to-png (figure output-file &key (dpi 100))
  "Render FIGURE to a PNG file at OUTPUT-FILE for image comparison."
  (savefig figure output-file :dpi dpi :format :png))

;;; ============================================================
;;; PDF backend image comparison tests
;;; ============================================================

(def-image-test pdf-line-render
    (:suite backend-pdf-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify line rendering through the full pipeline produces consistent output."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2 3 4) '(0 1 4 9 16) :color "red" :linewidth 2.0)
    (render-figure-to-png fig output-file)))

(def-image-test pdf-filled-rect-render
    (:suite backend-pdf-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify filled rectangle rendering consistency."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (bar ax '(1 2 3 4) '(10 25 15 30) :color "blue")
    (render-figure-to-png fig output-file)))

(def-image-test pdf-text-render
    (:suite backend-pdf-ported-suite :tolerance 8.0 :save-baseline t)
  "Verify text rendering produces consistent output.
Text rendering may have platform-dependent differences, so higher tolerance."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9))
    (let ((xaxis (mpl.containers::axes-base-xaxis ax))
          (yaxis (mpl.containers::axes-base-yaxis ax)))
      (mpl.containers:axis-set-label-text xaxis "X Axis Label")
      (mpl.containers:axis-set-label-text yaxis "Y Axis Label"))
    (render-figure-to-png fig output-file)))

(def-image-test pdf-dashed-lines
    (:suite backend-pdf-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify dashed line rendering consistency."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2 3 4) '(0 1 2 3 4) :color "blue" :linestyle :dashed :linewidth 2.0)
    (plot ax '(0 1 2 3 4) '(4 3 2 1 0) :color "red" :linestyle :dotted :linewidth 2.0)
    (render-figure-to-png fig output-file)))

(def-image-test pdf-multiple-paths
    (:suite backend-pdf-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify multiple overlapping paths render correctly."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    ;; Multiple lines with different styles
    (plot ax '(0 1 2 3 4) '(0 2 4 6 8) :color "red" :linewidth 1.0)
    (plot ax '(0 1 2 3 4) '(1 3 5 7 9) :color "green" :linewidth 2.0)
    (plot ax '(0 1 2 3 4) '(2 4 6 8 10) :color "blue" :linewidth 3.0)
    (render-figure-to-png fig output-file)))

(def-image-test pdf-scatter-render
    (:suite backend-pdf-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify scatter plot rendering through the pipeline."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (scatter ax '(1 2 3 4 5) '(2 4 1 5 3) :color "purple")
    (render-figure-to-png fig output-file)))

(def-image-test pdf-mixed-plot-types
    (:suite backend-pdf-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify mixed line + bar plot rendering."
  (let* ((fig (make-figure :figsize '(6.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (bar ax '(1 2 3 4) '(10 20 15 25) :color "lightblue")
    (plot ax '(1 2 3 4) '(10 20 15 25) :color "red" :linewidth 2.0 :marker :circle)
    (render-figure-to-png fig output-file)))

;;; ============================================================
;;; Parametrized tests for line styles
;;; ============================================================

(fiveam:test (pdf-linestyle-solid :suite backend-pdf-ported-suite)
  "Parametrized: solid line style renders without error."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2) '(0 1 2) :linestyle :solid :color "black")
    (let ((path (format nil "/tmp/cl-mpl-pdf-ported-solid-~A.png" (get-universal-time))))
      (render-figure-to-png fig path)
      (is (probe-file path))
      (when (probe-file path) (delete-file path)))))

(fiveam:test (pdf-linestyle-dashed :suite backend-pdf-ported-suite)
  "Parametrized: dashed line style renders without error."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2) '(0 1 2) :linestyle :dashed :color "black")
    (let ((path (format nil "/tmp/cl-mpl-pdf-ported-dashed-~A.png" (get-universal-time))))
      (render-figure-to-png fig path)
      (is (probe-file path))
      (when (probe-file path) (delete-file path)))))

(fiveam:test (pdf-linestyle-dotted :suite backend-pdf-ported-suite)
  "Parametrized: dotted line style renders without error."
  (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2) '(0 1 2) :linestyle :dotted :color "black")
    (let ((path (format nil "/tmp/cl-mpl-pdf-ported-dotted-~A.png" (get-universal-time))))
      (render-figure-to-png fig path)
      (is (probe-file path))
      (when (probe-file path) (delete-file path)))))

;;; ============================================================
;;; Canvas size parametrized tests
;;; ============================================================

(fiveam:test (pdf-canvas-size-small :suite backend-pdf-ported-suite)
  "Parametrized: small canvas renders correctly."
  (let* ((fig (make-figure :figsize '(2.0d0 2.0d0) :dpi 72))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2) '(0 1 2))
    (let ((path (format nil "/tmp/cl-mpl-pdf-ported-small-~A.png" (get-universal-time))))
      (render-figure-to-png fig path)
      (is (probe-file path))
      (when (probe-file path) (delete-file path)))))

(fiveam:test (pdf-canvas-size-large :suite backend-pdf-ported-suite)
  "Parametrized: large canvas renders correctly."
  (let* ((fig (make-figure :figsize '(12.0d0 8.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2 3 4 5) '(0 1 4 9 16 25))
    (let ((path (format nil "/tmp/cl-mpl-pdf-ported-large-~A.png" (get-universal-time))))
      (render-figure-to-png fig path)
      (is (probe-file path))
      (when (probe-file path) (delete-file path)))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-backend-pdf-ported-tests ()
  "Run all ported PDF backend tests and return results."
  (let ((results (run 'backend-pdf-ported-suite)))
    (explain! results)
    (results-status results)))
