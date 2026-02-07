;;;; test-legend-ported.lisp — Image comparison tests for Legend functionality
;;;; Ported from matplotlib's test_legend.py using def-image-test
;;;; Phase 8a: Visual regression tests

(defpackage #:cl-matplotlib.tests.legend-ported
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.testing
                #:def-image-test
                #:*image-tolerance*
                #:output-file)
  (:import-from #:cl-matplotlib.containers
                #:mpl-legend #:legend-handles #:legend-labels #:legend-loc
                #:legend-frameon-p #:legend-facecolor #:legend-edgecolor
                #:legend-title #:legend-fontsize
                #:axes-legend
                #:mpl-axes #:axes-base-lines #:axes-base-artists
                #:make-figure #:add-subplot #:plot #:scatter #:bar
                #:figure-axes #:savefig)
  (:export #:run-legend-ported-tests))

(in-package #:cl-matplotlib.tests.legend-ported)

(def-suite legend-ported-suite
  :description "Image comparison tests for legend functionality (ported from matplotlib)")
(in-suite legend-ported-suite)

;;; ============================================================
;;; Single line + legend
;;; ============================================================

(def-image-test legend-single-line
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with a single line entry."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Quadratic" :color "blue")
    (axes-legend ax)
    (savefig fig output-file)))

(def-image-test legend-multiple-lines
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with multiple line entries."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Quadratic" :color "C0")
    (plot ax '(1 2 3 4) '(2 4 6 8) :label "Linear" :color "C1")
    (plot ax '(1 2 3 4) '(1 2 3 4) :label "Identity" :color "C2")
    (axes-legend ax)
    (savefig fig output-file)))

;;; ============================================================
;;; Legend position tests
;;; ============================================================

(def-image-test legend-upper-right
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend at upper-right position."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data" :color "blue")
    (axes-legend ax :loc :upper-right)
    (savefig fig output-file)))

(def-image-test legend-upper-left
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend at upper-left position."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data" :color "blue")
    (axes-legend ax :loc :upper-left)
    (savefig fig output-file)))

(def-image-test legend-lower-left
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend at lower-left position."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data" :color "blue")
    (axes-legend ax :loc :lower-left)
    (savefig fig output-file)))

(def-image-test legend-lower-right
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend at lower-right position."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data" :color "blue")
    (axes-legend ax :loc :lower-right)
    (savefig fig output-file)))

(def-image-test legend-center
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend at center position."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data" :color "blue")
    (axes-legend ax :loc :center)
    (savefig fig output-file)))

;;; ============================================================
;;; Legend frame tests
;;; ============================================================

(def-image-test legend-with-frame
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with frame (default)."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data")
    (axes-legend ax :frameon t)
    (savefig fig output-file)))

(def-image-test legend-without-frame
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend without frame."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data")
    (axes-legend ax :frameon nil)
    (savefig fig output-file)))

;;; ============================================================
;;; Legend with different artist types
;;; ============================================================

(def-image-test legend-scatter
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with scatter plot entries."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (scatter ax '(1 2 3 4 5) '(2 4 1 5 3) :label "Points" :color "red")
    (axes-legend ax)
    (savefig fig output-file)))

(def-image-test legend-mixed-artists
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with mixed line + bar entries."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Line" :color "blue")
    (bar ax '(1 2 3 4) '(3 5 2 7) :label "Bars" :color "orange")
    (axes-legend ax)
    (savefig fig output-file)))

(def-image-test legend-line-styles
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with different line styles."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 1 2 3 4) '(0 1 2 3 4) :label "Solid" :linestyle :solid :color "blue")
    (plot ax '(0 1 2 3 4) '(0 2 4 6 8) :label "Dashed" :linestyle :dashed :color "red")
    (plot ax '(0 1 2 3 4) '(0 3 6 9 12) :label "Dotted" :linestyle :dotted :color "green")
    (axes-legend ax)
    (savefig fig output-file)))

;;; ============================================================
;;; Legend with title
;;; ============================================================

(def-image-test legend-with-title
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with a title."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Series A" :color "C0")
    (plot ax '(1 2 3 4) '(2 4 6 8) :label "Series B" :color "C1")
    (axes-legend ax :title "My Legend")
    (savefig fig output-file)))

;;; ============================================================
;;; Legend font size
;;; ============================================================

(def-image-test legend-small-fontsize
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with small font size."
  (let* ((fig (make-figure :figsize '(4.0d0 3.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data")
    (axes-legend ax :fontsize 7.0)
    (savefig fig output-file)))

(def-image-test legend-large-fontsize
    (:suite legend-ported-suite :tolerance 5.0 :save-baseline t)
  "Legend with large font size."
  (let* ((fig (make-figure :figsize '(5.0d0 4.0d0) :dpi 100))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Data")
    (axes-legend ax :fontsize 16.0)
    (savefig fig output-file)))

;;; ============================================================
;;; Parametrized: all legend positions
;;; ============================================================

(fiveam:test (legend-all-positions-render :suite legend-ported-suite)
  "Parametrized: all 10 legend positions render without error."
  (dolist (loc '(:upper-right :upper-left :lower-left :lower-right
                 :right :center-left :center-right
                 :lower-center :upper-center :center))
    (let* ((fig (make-figure :figsize '(3.0d0 2.0d0) :dpi 72))
           (ax (add-subplot fig 1 1 1))
           (path (format nil "/tmp/cl-mpl-legend-ported-~A-~A.png"
                         (string-downcase (string loc)) (get-universal-time))))
      (plot ax '(1 2 3) '(1 4 9) :label "Test")
      (axes-legend ax :loc loc)
      (savefig fig path)
      (is (probe-file path))
      (when (probe-file path) (delete-file path)))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-legend-ported-tests ()
  "Run all ported legend tests and return results."
  (let ((results (run 'legend-ported-suite)))
    (explain! results)
    (results-status results)))
