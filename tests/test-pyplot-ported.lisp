;;;; test-pyplot-ported.lisp — Image comparison tests for pyplot interface
;;;; Ported from matplotlib's test_pyplot.py using def-image-test
;;;; Phase 8a: Visual regression tests

(defpackage #:cl-matplotlib.tests.pyplot-ported
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.testing
                #:def-image-test
                #:*image-tolerance*
                #:output-file)
  (:import-from #:cl-matplotlib.pyplot
                #:figure #:gcf #:gca #:close-figure #:clf #:cla
                #:subplots
                #:plot #:scatter #:bar #:hist #:imshow #:contour #:contourf
                #:pie #:errorbar #:stem #:step-plot #:stackplot #:barh #:boxplot
                #:fill-between
                #:xlabel #:ylabel #:title #:xlim #:ylim #:grid #:legend
                #:colorbar #:annotate
                #:savefig #:show
                #:*figures* #:*current-figure* #:*figure-counter*)
  (:export #:run-pyplot-ported-tests))

(in-package #:cl-matplotlib.tests.pyplot-ported)

(def-suite pyplot-ported-suite
  :description "Image comparison tests for pyplot interface (ported from matplotlib)")
(in-suite pyplot-ported-suite)

;;; ============================================================
;;; Helper
;;; ============================================================

(defun reset-pyplot-state ()
  "Reset all pyplot global state for clean test isolation."
  (clrhash cl-matplotlib.pyplot::*figures*)
  (setf cl-matplotlib.pyplot::*current-figure* nil)
  (setf cl-matplotlib.pyplot::*figure-counter* 0))

;;; ============================================================
;;; Basic plot type image tests
;;; ============================================================

(def-image-test pyplot-line-plot
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify basic line plot produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (plot '(1 2 3 4 5) '(1 4 9 16 25) :color "blue" :linewidth 2.0)
  (xlabel "X")
  (ylabel "Y")
  (title "Line Plot")
  (savefig output-file))

(def-image-test pyplot-scatter-plot
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify scatter plot produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (scatter '(1 2 3 4 5) '(2 4 1 5 3) :color "red")
  (xlabel "X")
  (ylabel "Y")
  (title "Scatter Plot")
  (savefig output-file))

(def-image-test pyplot-bar-chart
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify bar chart produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (bar '(1 2 3 4) '(10 25 15 30) :color "green")
  (xlabel "Categories")
  (ylabel "Values")
  (title "Bar Chart")
  (savefig output-file))

(def-image-test pyplot-histogram
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify histogram produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (hist '(1.0 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0
          1.5 2.2 3.3 4.4 5.5 6.6 7.0 8.0 9.0 10.0) :bins 8)
  (xlabel "Value")
  (ylabel "Frequency")
  (title "Histogram")
  (savefig output-file))

(def-image-test pyplot-pie-chart
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify pie chart produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 4.0d0) :dpi 100)
  (pie '(30 20 50) :labels '("A" "B" "C"))
  (title "Pie Chart")
  (savefig output-file))

(def-image-test pyplot-errorbar-plot
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify errorbar plot produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (errorbar '(1 2 3 4) '(10 20 15 25) :yerr 2.0)
  (xlabel "X")
  (ylabel "Y")
  (title "Error Bars")
  (savefig output-file))

(def-image-test pyplot-step-plot
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify step plot produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (step-plot '(1 2 3 4 5) '(1 3 2 5 4))
  (xlabel "X")
  (ylabel "Y")
  (title "Step Plot")
  (savefig output-file))

(def-image-test pyplot-fill-between
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify fill-between produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (fill-between '(1 2 3 4 5) '(1 2 3 4 5) '(2 4 6 8 10))
  (xlabel "X")
  (ylabel "Y")
  (title "Fill Between")
  (savefig output-file))

;;; ============================================================
;;; Styling and configuration image tests
;;; ============================================================

(def-image-test pyplot-grid-visible
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify grid rendering produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (plot '(0 1 2 3 4) '(0 1 4 9 16))
  (grid :visible t)
  (title "With Grid")
  (savefig output-file))

(def-image-test pyplot-multi-line
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify multiple lines with different styles."
  (reset-pyplot-state)
  (figure :figsize '(5.0d0 4.0d0) :dpi 100)
  (plot '(0 1 2 3 4) '(0 1 4 9 16) :color "blue" :label "Quadratic")
  (plot '(0 1 2 3 4) '(0 2 4 6 8) :color "red" :linestyle :dashed :label "Linear")
  (plot '(0 1 2 3 4) '(0 1 2 3 4) :color "green" :linestyle :dotted :label "Identity")
  (xlabel "X")
  (ylabel "Y")
  (title "Multiple Lines")
  (legend)
  (savefig output-file))

(def-image-test pyplot-axis-limits
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify axis limits are applied correctly."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (plot '(0 1 2 3 4 5 6 7 8 9 10) '(0 1 4 9 16 25 36 49 64 81 100))
  (xlim 2 8)
  (ylim 0 50)
  (title "Custom Limits")
  (savefig output-file))

;;; ============================================================
;;; Subplots image tests
;;; ============================================================

(def-image-test pyplot-subplots-2x1
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify 2x1 subplots layout."
  (reset-pyplot-state)
  (multiple-value-bind (fig axes) (subplots 2 1)
    (let ((ax1 (if (arrayp axes) (aref axes 0) axes))
          (ax2 (if (arrayp axes) (aref axes 1) axes)))
      (mpl.containers:plot ax1 '(1 2 3) '(1 4 9))
      (mpl.containers:plot ax2 '(1 2 3) '(9 4 1)))
    (savefig output-file)))

(def-image-test pyplot-subplots-2x2
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify 2x2 subplots layout."
  (reset-pyplot-state)
  (multiple-value-bind (fig axes) (subplots 2 2)
    (declare (ignore fig))
    (mpl.containers:plot (aref axes 0 0) '(1 2 3) '(1 2 3))
    (mpl.containers:scatter (aref axes 0 1) '(1 2 3) '(3 2 1))
    (mpl.containers:bar (aref axes 1 0) '(1 2 3) '(5 10 15))
    (mpl.containers:plot (aref axes 1 1) '(1 2 3) '(2 1 3))
    (savefig output-file)))

;;; ============================================================
;;; Integration / workflow image tests
;;; ============================================================

(def-image-test pyplot-full-workflow
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Full workflow: figure → plot → style → legend → save."
  (reset-pyplot-state)
  (figure :figsize '(6.0d0 4.0d0) :dpi 100)
  (plot '(1 2 3 4 5) '(1 4 9 16 25) :color "blue" :linewidth 2.0 :label "y=x²")
  (scatter '(1 2 3 4 5) '(1 4 9 16 25) :color "red" :label "data points")
  (xlabel "X axis")
  (ylabel "Y axis")
  (title "Complete Workflow Test")
  (grid :visible t)
  (legend)
  (savefig output-file))

(def-image-test pyplot-contour-plot
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify contour plot via pyplot produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (let* ((nx 10) (ny 10)
         (x (loop for i below nx collect (float i 1.0d0)))
         (y (loop for j below ny collect (float j 1.0d0)))
         (z (make-array (list ny nx) :element-type 'double-float)))
    (dotimes (j ny)
      (dotimes (i nx)
        (setf (aref z j i) (+ (float i 1.0d0) (float j 1.0d0)))))
    (contour x y z :levels '(3.0d0 6.0d0 9.0d0 12.0d0)))
  (title "Contour Plot")
  (savefig output-file))

(def-image-test pyplot-imshow-plot
    (:suite pyplot-ported-suite :tolerance 5.0 :save-baseline t)
  "Verify imshow produces consistent image."
  (reset-pyplot-state)
  (figure :figsize '(4.0d0 3.0d0) :dpi 100)
  (let ((data (make-array '(10 10) :element-type 'double-float)))
    ;; Create a gradient pattern
    (dotimes (j 10)
      (dotimes (i 10)
        (setf (aref data j i) (/ (+ (float i 1.0d0) (float j 1.0d0)) 20.0d0))))
    (imshow data))
  (title "Image Show")
  (savefig output-file))

;;; ============================================================
;;; Parametrized tests: figure sizes
;;; ============================================================

(fiveam:test (pyplot-figsize-small :suite pyplot-ported-suite)
  "Parametrized: small figure size renders correctly."
  (reset-pyplot-state)
  (figure :figsize '(2.0d0 1.5d0) :dpi 72)
  (plot '(0 1 2) '(0 1 4))
  (let ((path (format nil "/tmp/cl-mpl-pyplot-ported-small-~A.png" (get-universal-time))))
    (savefig path)
    (is (probe-file path))
    (when (probe-file path) (delete-file path))))

(fiveam:test (pyplot-figsize-large :suite pyplot-ported-suite)
  "Parametrized: large figure size renders correctly."
  (reset-pyplot-state)
  (figure :figsize '(10.0d0 8.0d0) :dpi 100)
  (plot '(0 1 2 3 4 5) '(0 1 4 9 16 25))
  (let ((path (format nil "/tmp/cl-mpl-pyplot-ported-large-~A.png" (get-universal-time))))
    (savefig path)
    (is (probe-file path))
    (when (probe-file path) (delete-file path))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-pyplot-ported-tests ()
  "Run all ported pyplot tests and return results."
  (let ((results (run 'pyplot-ported-suite)))
    (explain! results)
    (results-status results)))
