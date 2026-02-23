;;;; test-pyplot.lisp — Tests for pyplot procedural interface
;;;; Phase 7a — FiveAM test suite

(defpackage #:cl-matplotlib.tests.pyplot
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.pyplot
                ;; Figure management
                #:figure #:gcf #:gca #:close-figure #:clf #:cla
                ;; Subplot creation
                #:subplots
                ;; Plot functions
                #:plot #:scatter #:bar #:hist #:imshow #:contour #:contourf
                #:pie #:errorbar #:stem #:step-plot #:stackplot #:barh #:boxplot
                 #:fill-between #:pcolormesh
                 ;; Axes configuration
                #:xlabel #:ylabel #:title #:xlim #:ylim #:grid #:legend
                #:colorbar #:annotate #:text
                #:suptitle #:supxlabel #:supylabel
                #:invert-xaxis #:invert-yaxis
                #:axhline #:axvline #:hlines #:vlines
                 #:axhspan #:axvspan
                 #:twinx #:twiny
                 #:set-xticks #:set-xticklabels #:set-yticks #:set-yticklabels
                ;; Output
                #:savefig #:show
                ;; State management
                #:*figures* #:*current-figure* #:*figure-counter*)
  (:export #:run-pyplot-tests))

(in-package #:cl-matplotlib.tests.pyplot)

(def-suite pyplot-suite :description "pyplot procedural interface test suite")
(in-suite pyplot-suite)

;;; ============================================================
;;; Helpers
;;; ============================================================

(defun reset-pyplot-state ()
  "Reset all pyplot global state for clean test isolation."
  (clrhash cl-matplotlib.pyplot::*figures*)
  (setf cl-matplotlib.pyplot::*current-figure* nil)
  (setf cl-matplotlib.pyplot::*figure-counter* 0))

(defun tmp-path (name ext)
  "Create a temporary file path."
  (format nil "/tmp/cl-mpl-pyplot-test-~A.~A" name ext))

(defun file-exists-and-valid-p (path &optional (min-size 100))
  "Check that PATH exists and is larger than MIN-SIZE bytes."
  (and (probe-file path)
       (> (with-open-file (s path :element-type '(unsigned-byte 8))
            (file-length s))
          min-size)))

(defun png-header-valid-p (path)
  "Check that the file at PATH starts with the PNG magic bytes."
  (when (probe-file path)
    (with-open-file (s path :element-type '(unsigned-byte 8))
      (and (= (read-byte s) 137)   ; PNG signature
           (= (read-byte s) 80)    ; P
           (= (read-byte s) 78)    ; N
           (= (read-byte s) 71))))) ; G

;;; ============================================================
;;; Figure management tests
;;; ============================================================

(test figure-creation
  "Test basic figure creation."
  (reset-pyplot-state)
  (let ((fig (figure)))
    (is (typep fig 'mpl.containers:mpl-figure))
    (is (= 1 *current-figure*))
    (is (= 1 (hash-table-count *figures*)))))

(test figure-auto-numbering
  "Test that figures get auto-numbered sequentially."
  (reset-pyplot-state)
  (let ((fig1 (figure))
        (fig2 (figure))
        (fig3 (figure)))
    (declare (ignore fig1 fig2 fig3))
    (is (= 3 *current-figure*))
    (is (= 3 (hash-table-count *figures*)))))

(test figure-explicit-number
  "Test creating figures with explicit numbers."
  (reset-pyplot-state)
  (let ((fig1 (figure :num 5))
        (fig2 (figure :num 10)))
    (declare (ignore fig1 fig2))
    (is (= 10 *current-figure*))
    (is (= 2 (hash-table-count *figures*)))
    ;; Switching to existing figure
    (let ((fig-again (figure :num 5)))
      (declare (ignore fig-again))
      (is (= 5 *current-figure*))
      (is (= 2 (hash-table-count *figures*))))))

(test figure-with-params
  "Test figure creation with custom parameters."
  (reset-pyplot-state)
  (let ((fig (figure :figsize '(10.0d0 8.0d0) :dpi 150 :facecolor "gray")))
    (is (= 10.0d0 (first (mpl.containers:figure-figsize fig))))
    (is (= 8.0d0 (second (mpl.containers:figure-figsize fig))))
    (is (= 150.0d0 (mpl.containers:figure-dpi fig)))))

(test gcf-auto-creates
  "Test that gcf auto-creates a figure when none exists."
  (reset-pyplot-state)
  (is (null *current-figure*))
  (let ((fig (gcf)))
    (is (typep fig 'mpl.containers:mpl-figure))
    (is (not (null *current-figure*)))))

(test gcf-returns-current
  "Test that gcf returns the current figure."
  (reset-pyplot-state)
  (let ((fig (figure)))
    (is (eq fig (gcf)))))

(test gca-auto-creates
  "Test that gca auto-creates figure and axes when needed."
  (reset-pyplot-state)
  (let ((ax (gca)))
    (is (typep ax 'mpl.containers:mpl-axes))
    ;; Figure should have been created too
    (is (not (null *current-figure*)))
    ;; Axes should be in the figure
    (is (= 1 (length (mpl.containers:figure-axes (gcf)))))))

(test gca-returns-existing
  "Test that gca returns existing axes."
  (reset-pyplot-state)
  (let* ((ax1 (gca))
         (ax2 (gca)))
    (is (eq ax1 ax2))))

;;; ============================================================
;;; Close/clear tests
;;; ============================================================

(test close-current-figure
  "Test closing the current figure."
  (reset-pyplot-state)
  (figure)
  (figure)
  (is (= 2 *current-figure*))
  (close-figure)
  (is (= 1 *current-figure*))
  (is (= 1 (hash-table-count *figures*))))

(test close-specific-figure
  "Test closing a specific figure by number."
  (reset-pyplot-state)
  (figure)
  (figure)
  (close-figure 1)
  (is (= 2 *current-figure*))
  (is (= 1 (hash-table-count *figures*))))

(test close-all-figures
  "Test closing all figures."
  (reset-pyplot-state)
  (figure)
  (figure)
  (figure)
  (close-figure :all)
  (is (null *current-figure*))
  (is (= 0 (hash-table-count *figures*))))

(test clf-clears-figure
  "Test that clf clears the current figure."
  (reset-pyplot-state)
  (figure)
  (gca) ; creates axes
  (plot '(1 2 3) '(4 5 6))
  (is (not (null (mpl.containers:figure-axes (gcf)))))
  (clf)
  (is (null (mpl.containers:figure-axes (gcf)))))

(test cla-clears-axes
  "Test that cla clears the current axes."
  (reset-pyplot-state)
  (plot '(1 2 3) '(4 5 6))
  (is (not (null (mpl.containers:axes-base-lines (gca)))))
  (cla)
  (is (null (mpl.containers:axes-base-lines (gca)))))

;;; ============================================================
;;; Subplot tests
;;; ============================================================

(test subplots-default
  "Test subplots with default 1x1."
  (reset-pyplot-state)
  (multiple-value-bind (fig axes) (subplots)
    (is (typep fig 'mpl.containers:mpl-figure))
    ;; 1x1 squeezed → single axes
    (is (typep axes 'mpl.containers:mpl-axes))))

(test subplots-2x2
  "Test subplots with 2x2 grid."
  (reset-pyplot-state)
  (multiple-value-bind (fig axes) (subplots 2 2)
    (declare (ignore fig))
    ;; 2x2 → 2D array
    (is (arrayp axes))
    (is (equal '(2 2) (array-dimensions axes)))
    ;; Each element is an axes
    (is (typep (aref axes 0 0) 'mpl.containers:mpl-axes))
    (is (typep (aref axes 1 1) 'mpl.containers:mpl-axes))))

(test subplots-1xn
  "Test subplots with 1xN grid (squeezed to 1D)."
  (reset-pyplot-state)
  (multiple-value-bind (fig axes) (subplots 1 3)
    (declare (ignore fig))
    ;; 1x3 squeezed → 1D array of 3
    (is (arrayp axes))
    (is (= 3 (length axes)))))

;;; ============================================================
;;; Plot function tests
;;; ============================================================

(test plot-basic
  "Test basic line plot."
  (reset-pyplot-state)
  (let ((result (plot '(1 2 3 4) '(1 4 9 16))))
    (is (listp result))
    (is (typep (first result) 'mpl.rendering:line-2d))
    ;; Should have created figure and axes
    (is (not (null *current-figure*)))
    ;; Axes should have lines
    (is (not (null (mpl.containers:axes-base-lines (gca)))))))

(test plot-with-options
  "Test plot with styling options."
  (reset-pyplot-state)
  (let ((result (plot '(1 2 3) '(1 2 3)
                      :color "red" :linewidth 2.0 :linestyle :dashed
                      :marker :circle :label "test")))
    (is (listp result))
    (let ((line (first result)))
      (is (string= "red" (mpl.rendering:line-2d-color line)))
      (is (= 2.0 (mpl.rendering:line-2d-linewidth line))))))

(test scatter-basic
  "Test basic scatter plot."
  (reset-pyplot-state)
  (let ((pc (scatter '(1 2 3) '(4 5 6))))
    (is (typep pc 'mpl.rendering:path-collection))))

(test bar-basic
  "Test basic bar chart."
  (reset-pyplot-state)
  (let ((rects (bar '(1 2 3) '(10 20 30))))
    (is (= 3 (length rects)))
    (is (typep (first rects) 'mpl.rendering:rectangle))))

(test hist-basic
  "Test basic histogram."
  (reset-pyplot-state)
  (let ((data '(1.0 2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0
                1.5 2.2 3.3 4.4 5.5 6.6 7.0 8.0 9.0 10.0)))
    ;; hist should not error
    (finishes (hist data :bins 5))))

(test pie-basic
  "Test basic pie chart."
  (reset-pyplot-state)
  (multiple-value-bind (patches texts autotexts)
      (pie '(30 20 50) :labels '("A" "B" "C"))
    (is (= 3 (length patches)))
    (is (= 3 (length texts)))
    (is (null autotexts))))

(test errorbar-basic
  "Test basic error bar plot."
  (reset-pyplot-state)
  (finishes (errorbar '(1 2 3) '(4 5 6) :yerr 0.5)))

(test stem-basic
  "Test basic stem plot."
  (reset-pyplot-state)
  (finishes (stem '(1 2 3 4) '(2 4 1 3))))

(test step-plot-basic
  "Test basic step plot."
  (reset-pyplot-state)
  (let ((line (step-plot '(1 2 3 4) '(1 4 2 3))))
    (is (typep line 'mpl.rendering:line-2d))))

(test stackplot-basic
  "Test basic stacked area plot."
  (reset-pyplot-state)
  (let ((polys (stackplot '(1 2 3 4)
                          '((1 2 3 4) (2 3 4 5)))))
    (is (= 2 (length polys)))))

(test barh-basic
  "Test basic horizontal bar plot."
  (reset-pyplot-state)
  (let ((rects (barh '(1 2 3) '(10 20 30))))
    (is (= 3 (length rects)))))

(test boxplot-basic
  "Test basic box plot."
  (reset-pyplot-state)
  (finishes (boxplot '((1 2 3 4 5) (2 3 4 5 6)))))

(test fill-between-basic
  "Test basic fill-between."
  (reset-pyplot-state)
  (let ((poly (fill-between '(1 2 3 4) '(1 2 3 4) '(2 4 6 8))))
    (is (typep poly 'mpl.rendering:polygon))))

;;; ============================================================
;;; Axes configuration tests
;;; ============================================================

(test xlabel-ylabel
  "Test setting axis labels."
  (reset-pyplot-state)
  (gca) ; ensure axes exist
  (xlabel "X Axis")
  (ylabel "Y Axis")
  (let ((ax (gca)))
    (is (string= "X Axis"
                  (mpl.containers:axis-label-text
                   (mpl.containers:axes-base-xaxis ax))))
    (is (string= "Y Axis"
                  (mpl.containers:axis-label-text
                   (mpl.containers:axes-base-yaxis ax))))))

(test title-setting
  "Test setting axes title."
  (reset-pyplot-state)
  (let ((txt (title "My Plot")))
    (is (typep txt 'mpl.rendering:text-artist))
    (is (string= "My Plot" (mpl.rendering:text-text txt)))))

(test xlim-ylim-set
  "Test setting axis limits."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (xlim 0 10)
  (ylim -5 5)
  (multiple-value-bind (xmin xmax) (xlim)
    (is (= 0.0d0 xmin))
    (is (= 10.0d0 xmax)))
  (multiple-value-bind (ymin ymax) (ylim)
    (is (= -5.0d0 ymin))
    (is (= 5.0d0 ymax))))

(test grid-toggle
  "Test grid toggle."
  (reset-pyplot-state)
  (gca)
  ;; Should not error
  (finishes (grid :visible t))
  (finishes (grid :visible nil)))

(test legend-creation
  "Test legend creation."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 4 9) :label "Squared")
  (let ((leg (legend)))
    (is (typep leg 'mpl.containers:mpl-legend))))

(test annotate-basic
  "Test basic annotation."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 4 9))
  (let ((ann (annotate "peak" '(3.0d0 9.0d0))))
    (is (typep ann 'mpl.rendering:annotation))))

(test text-basic
  "Test basic text placement returns a text-artist."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 4 9))
  (let ((txt (text 0.5 0.5 "Hello")))
    (is (typep txt 'mpl.rendering:text-artist))
    (is (string= "Hello" (mpl.rendering:text-text txt)))))

(test text-with-kwargs
  "Test text with fontsize, color, alignment, rotation, and alpha."
  (reset-pyplot-state)
  (figure)
  (let ((txt (text 1.0 2.0 "Styled"
                   :fontsize 14 :color "red"
                   :ha :center :va :top
                   :rotation 45.0 :alpha 0.7d0)))
    (is (typep txt 'mpl.rendering:text-artist))
    (is (string= "Styled" (mpl.rendering:text-text txt)))
    (is (= 14.0d0 (mpl.rendering:text-fontsize txt)))
    (is (string= "red" (mpl.rendering:text-color txt)))
    (is (eq :center (mpl.rendering:text-horizontalalignment txt)))
    (is (eq :top (mpl.rendering:text-verticalalignment txt)))
    (is (= 45.0d0 (mpl.rendering:text-rotation txt)))
    (is (= 0.7d0 (mpl.rendering:artist-alpha txt)))))

;;; ============================================================
;;; Output tests
;;; ============================================================

(test savefig-creates-png
  "Test that savefig creates a valid PNG file."
  (reset-pyplot-state)
  (let ((path (tmp-path "savefig-test" "png")))
    ;; Clean up
    (when (probe-file path) (delete-file path))
    ;; Create plot and save
    (plot '(1 2 3 4) '(1 4 9 16))
    (xlabel "X")
    (ylabel "Y")
    (title "Test")
    (savefig path)
    ;; Verify
    (is-true (file-exists-and-valid-p path))
    (is-true (png-header-valid-p path))
    ;; Clean up
    (when (probe-file path) (delete-file path))))

(test show-no-error
  "Test that show doesn't error (no-op for non-interactive)."
  (reset-pyplot-state)
  (figure)
  (finishes (show)))

;;; ============================================================
;;; State isolation tests
;;; ============================================================

(test multiple-figures-independent
  "Test that multiple figures maintain independent state."
  (reset-pyplot-state)
  (figure :num 1)
  (plot '(1 2 3) '(1 2 3))
  (figure :num 2)
  (scatter '(4 5 6) '(4 5 6))
  ;; Figure 1 should have lines, no artists (scatter creates artist)
  (figure :num 1)
  (let ((ax1 (gca)))
    (is (not (null (mpl.containers:axes-base-lines ax1)))))
  ;; Figure 2 should have artists (scatter), no direct lines
  (figure :num 2)
  (let ((ax2 (gca)))
    (is (not (null (mpl.containers:axes-base-artists ax2))))))

(test gca-after-clf
  "Test that gca creates new axes after clf."
  (reset-pyplot-state)
  (let ((ax1 (gca)))
    (clf)
    (let ((ax2 (gca)))
      (is (not (eq ax1 ax2))))))

;;; ============================================================
;;; Integration tests
;;; ============================================================

(test full-plot-workflow
  "Test complete plot workflow: figure → plot → labels → save."
  (reset-pyplot-state)
  (let ((path (tmp-path "workflow" "png")))
    (when (probe-file path) (delete-file path))
    ;; Full workflow
    (figure :figsize '(8.0d0 6.0d0) :dpi 100)
    (plot '(1 2 3 4 5) '(1 4 9 16 25) :color "blue" :label "y=x²")
    (scatter '(1 2 3 4 5) '(1 4 9 16 25) :color "red" :label "data points")
    (xlabel "X axis")
    (ylabel "Y axis")
    (title "Complete Test")
    (grid :visible t)
    (legend)
    (savefig path)
    ;; Verify
    (is-true (file-exists-and-valid-p path))
    (is-true (png-header-valid-p path))
    ;; Clean up
    (when (probe-file path) (delete-file path))))

(test subplots-workflow
  "Test subplots workflow."
  (reset-pyplot-state)
  (multiple-value-bind (fig axes) (subplots 2 1)
    (declare (ignore fig))
    ;; Plot on first axes
    (let ((ax1 (if (arrayp axes) (aref axes 0) axes)))
      (mpl.containers:plot ax1 '(1 2 3) '(1 2 3)))
    ;; Plot on second axes
    (let ((ax2 (if (arrayp axes) (aref axes 1) axes)))
      (mpl.containers:scatter ax2 '(1 2 3) '(3 2 1)))
    ;; Should have 2 axes (but reversed due to push)
    (is (>= (length (mpl.containers:figure-axes (gcf))) 2))))

;;; ============================================================
;;; Edge case tests
;;; ============================================================

(test close-with-no-figures
  "Test close-figure with no figures does not error."
  (reset-pyplot-state)
  (finishes (close-figure)))

(test figure-counter-tracks-explicit
  "Test that figure counter advances past explicit numbers."
  (reset-pyplot-state)
  (figure :num 100)
  ;; Next auto-number should be 101
  (let ((fig (figure)))
    (declare (ignore fig))
    (is (= 101 *current-figure*))))

(test xlim-ylim-get-returns-values
  "Test xlim/ylim with no args returns current limits."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (multiple-value-bind (xmin xmax) (xlim)
    (is (numberp xmin))
    (is (numberp xmax))
    (is (< xmin xmax)))
  (multiple-value-bind (ymin ymax) (ylim)
    (is (numberp ymin))
    (is (numberp ymax))
    (is (< ymin ymax))))

;;; ============================================================
;;; Contour tests
;;; ============================================================

(test contour-basic
  "Test basic contour plot via pyplot."
  (reset-pyplot-state)
  (let* ((nx 10) (ny 10)
         (x (loop for i below nx collect (float i 1.0d0)))
         (y (loop for j below ny collect (float j 1.0d0)))
         (z (make-array (list ny nx) :element-type 'double-float)))
    ;; Fill z = x + y
    (dotimes (j ny)
      (dotimes (i nx)
        (setf (aref z j i) (+ (float i 1.0d0) (float j 1.0d0)))))
    (finishes (contour x y z :levels '(3.0d0 6.0d0 9.0d0 12.0d0)))))

(test imshow-basic
  "Test basic imshow via pyplot."
  (reset-pyplot-state)
  (let ((data (make-array '(10 10) :element-type 'double-float
                                    :initial-element 0.5d0)))
    (let ((img (imshow data)))
      (is (typep img 'mpl.rendering:axes-image)))))

;;; ============================================================
;;; Reference line tests
;;; ============================================================

(test axhline-basic
  "Test axhline draws a horizontal line and returns Line2D."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((line (axhline 5.0)))
    (is (typep line 'mpl.rendering:line-2d))
    ;; Y data should be (5.0 5.0) — stored as vector
    (is (= 2 (length (mpl.rendering:line-2d-ydata line))))
    (is (= 5.0d0 (elt (mpl.rendering:line-2d-ydata line) 0)))
    (is (= 5.0d0 (elt (mpl.rendering:line-2d-ydata line) 1)))))

(test axhline-kwargs
  "Test axhline accepts color, linestyle, linewidth, alpha kwargs."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((line (axhline 3.0 :color "red" :linestyle :dashed :linewidth 2.0 :alpha 0.5)))
    (is (typep line 'mpl.rendering:line-2d))
    (is (string= "red" (mpl.rendering:line-2d-color line)))
    (is (eq :dashed (mpl.rendering:line-2d-linestyle line)))
    (is (= 2.0 (mpl.rendering:line-2d-linewidth line)))
    (is (= 0.5d0 (mpl.rendering:artist-alpha line)))))

(test axvline-basic
  "Test axvline draws a vertical line and returns Line2D."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((line (axvline 2.0)))
    (is (typep line 'mpl.rendering:line-2d))
    ;; X data should be (2.0 2.0) — stored as vector
    (is (= 2 (length (mpl.rendering:line-2d-xdata line))))
    (is (= 2.0d0 (elt (mpl.rendering:line-2d-xdata line) 0)))
    (is (= 2.0d0 (elt (mpl.rendering:line-2d-xdata line) 1)))))

(test axvline-kwargs
  "Test axvline accepts color, linestyle, linewidth kwargs."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((line (axvline 7.0 :color "blue" :linestyle :dotted :linewidth 3.0)))
    (is (typep line 'mpl.rendering:line-2d))
    (is (string= "blue" (mpl.rendering:line-2d-color line)))
    (is (eq :dotted (mpl.rendering:line-2d-linestyle line)))
    (is (= 3.0 (mpl.rendering:line-2d-linewidth line)))))

(test hlines-scalar
  "Test hlines with a single y value."
  (reset-pyplot-state)
  (figure)
  (let ((lines (hlines 5 0 10)))
    (is (listp lines))
    (is (= 1 (length lines)))
    (is (typep (first lines) 'mpl.rendering:line-2d))))

(test hlines-list
  "Test hlines with a list of y values."
  (reset-pyplot-state)
  (figure)
  (let ((lines (hlines '(1 2 3) 0 10)))
    (is (listp lines))
    (is (= 3 (length lines)))
    (dolist (line lines)
      (is (typep line 'mpl.rendering:line-2d)))))

(test hlines-kwargs
  "Test hlines with color and linestyle kwargs."
  (reset-pyplot-state)
  (figure)
  (let ((lines (hlines '(1 2) 0 5 :colors "red" :linestyles :dashed :linewidth 2.0 :alpha 0.7)))
    (is (= 2 (length lines)))
    (is (string= "red" (mpl.rendering:line-2d-color (first lines))))
    (is (eq :dashed (mpl.rendering:line-2d-linestyle (first lines))))
    (is (= 2.0 (mpl.rendering:line-2d-linewidth (first lines))))))

(test vlines-scalar
  "Test vlines with a single x value."
  (reset-pyplot-state)
  (figure)
  (let ((lines (vlines 5 0 10)))
    (is (listp lines))
    (is (= 1 (length lines)))
    (is (typep (first lines) 'mpl.rendering:line-2d))))

(test vlines-list
  "Test vlines with a list of x values."
  (reset-pyplot-state)
  (figure)
  (let ((lines (vlines '(1 2 3) 0 5)))
    (is (listp lines))
    (is (= 3 (length lines)))
    (dolist (line lines)
      (is (typep line 'mpl.rendering:line-2d)))))

(test vlines-kwargs
  "Test vlines with color and linestyle kwargs."
  (reset-pyplot-state)
  (figure)
  (let ((lines (vlines '(1 2) 0 5 :colors "green" :linestyles :dashdot :linewidth 1.0)))
    (is (= 2 (length lines)))
    (is (string= "green" (mpl.rendering:line-2d-color (first lines))))
    (is (eq :dashdot (mpl.rendering:line-2d-linestyle (first lines))))))

;;; ============================================================
;;; Figure-level title/label tests
;;; ============================================================

(test suptitle-basic
  "Test suptitle creates a text-artist and stores it on the figure."
  (reset-pyplot-state)
  (figure)
  (let ((txt (suptitle "Main Title")))
    (is (typep txt 'mpl.rendering:text-artist))
    (is (string= "Main Title" (mpl.rendering:text-text txt)))
    ;; Should be stored in figure's suptitle slot
    (is (eq txt (mpl.containers:figure-suptitle-artist (gcf))))
    ;; Should be in fig-texts
    (is (member txt (mpl.containers:figure-texts (gcf))))))

(test suptitle-with-fontsize
  "Test suptitle with custom fontsize."
  (reset-pyplot-state)
  (figure)
  (let ((txt (suptitle "Big Title" :fontsize 20.0)))
    (is (= 20.0d0 (mpl.rendering:text-fontsize txt)))))

(test supxlabel-basic
  "Test supxlabel creates a text-artist at the bottom of the figure."
  (reset-pyplot-state)
  (figure)
  (let ((txt (supxlabel "X Label")))
    (is (typep txt 'mpl.rendering:text-artist))
    (is (string= "X Label" (mpl.rendering:text-text txt)))
    ;; Should be in fig-texts
    (is (member txt (mpl.containers:figure-texts (gcf))))))

(test supylabel-basic
  "Test supylabel creates a rotated text-artist at the left of the figure."
  (reset-pyplot-state)
  (figure)
  (let ((txt (supylabel "Y Label")))
    (is (typep txt 'mpl.rendering:text-artist))
    (is (string= "Y Label" (mpl.rendering:text-text txt)))
    ;; Should be rotated 90 degrees
    (is (= 90.0d0 (mpl.rendering:text-rotation txt)))
    ;; Should be in fig-texts
    (is (member txt (mpl.containers:figure-texts (gcf))))))

;;; ============================================================
;;; Axis inversion tests
;;; ============================================================

(test invert-xaxis-basic
  "Test invert-xaxis swaps x-axis limits."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (xlim 0 10)
  (invert-xaxis)
  (multiple-value-bind (xmin xmax) (xlim)
    ;; After inversion, old max is now min and old min is now max
    (is (= 10.0d0 xmin))
    (is (= 0.0d0 xmax))))

(test invert-yaxis-basic
  "Test invert-yaxis swaps y-axis limits."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (ylim 0 20)
  (invert-yaxis)
  (multiple-value-bind (ymin ymax) (ylim)
    ;; After inversion, old max is now min and old min is now max
    (is (= 20.0d0 ymin))
    (is (= 0.0d0 ymax))))

(test invert-xaxis-double-restores
  "Test that inverting x-axis twice restores original limits."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (xlim 0 10)
  (invert-xaxis)
  (invert-xaxis)
  (multiple-value-bind (xmin xmax) (xlim)
    (is (= 0.0d0 xmin))
    (is (= 10.0d0 xmax))))

;;; ============================================================
;;; set-xticks / set-xticklabels / set-yticks / set-yticklabels
;;; ============================================================

(test set-xticks-basic
  "Test set-xticks places fixed tick positions on x-axis."
  (reset-pyplot-state)
  (plot '(1 2 3 4 5) '(1 2 3 4 5))
  (set-xticks '(1 2 3))
  (let* ((ax (gca))
         (xaxis (mpl.containers:axes-base-xaxis ax))
         (loc (mpl.containers:axis-major-locator xaxis)))
    (is (typep loc 'mpl.containers:fixed-locator))
    (is (equal '(1.0d0 2.0d0 3.0d0)
               (mpl.containers:fixed-locator-locs loc)))))

(test set-xticks-with-labels
  "Test set-xticks with :labels sets both locator and formatter."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (set-xticks '(1 2 3) :labels '("A" "B" "C"))
  (let* ((ax (gca))
         (xaxis (mpl.containers:axes-base-xaxis ax))
         (loc (mpl.containers:axis-major-locator xaxis))
         (fmt (mpl.containers:axis-major-formatter xaxis)))
    (is (typep loc 'mpl.containers:fixed-locator))
    (is (typep fmt 'mpl.containers:fixed-formatter))
    (is (equal '("A" "B" "C") (mpl.containers:fixed-formatter-seq fmt)))))

(test set-xticklabels-basic
  "Test set-xticklabels sets formatter only."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (set-xticklabels '("Mon" "Tue" "Wed"))
  (let* ((ax (gca))
         (xaxis (mpl.containers:axes-base-xaxis ax))
         (fmt (mpl.containers:axis-major-formatter xaxis)))
    (is (typep fmt 'mpl.containers:fixed-formatter))
    (is (equal '("Mon" "Tue" "Wed") (mpl.containers:fixed-formatter-seq fmt)))))

(test set-yticks-basic
  "Test set-yticks places fixed tick positions on y-axis."
  (reset-pyplot-state)
  (plot '(1 2 3) '(10 20 30))
  (set-yticks '(10 20 30))
  (let* ((ax (gca))
         (yaxis (mpl.containers:axes-base-yaxis ax))
         (loc (mpl.containers:axis-major-locator yaxis)))
    (is (typep loc 'mpl.containers:fixed-locator))
    (is (equal '(10.0d0 20.0d0 30.0d0)
               (mpl.containers:fixed-locator-locs loc)))))

(test set-yticks-with-labels
  "Test set-yticks with :labels sets both locator and formatter."
  (reset-pyplot-state)
  (plot '(1 2 3) '(10 20 30))
  (set-yticks '(10 20 30) :labels '("Low" "Mid" "High"))
  (let* ((ax (gca))
         (yaxis (mpl.containers:axes-base-yaxis ax))
         (loc (mpl.containers:axis-major-locator yaxis))
         (fmt (mpl.containers:axis-major-formatter yaxis)))
    (is (typep loc 'mpl.containers:fixed-locator))
    (is (typep fmt 'mpl.containers:fixed-formatter))
    (is (equal '("Low" "Mid" "High") (mpl.containers:fixed-formatter-seq fmt)))))

(test set-yticklabels-basic
  "Test set-yticklabels sets formatter only."
  (reset-pyplot-state)
  (plot '(1 2 3) '(10 20 30))
  (set-yticklabels '("X" "Y" "Z"))
  (let* ((ax (gca))
         (yaxis (mpl.containers:axes-base-yaxis ax))
         (fmt (mpl.containers:axis-major-formatter yaxis)))
    (is (typep fmt 'mpl.containers:fixed-formatter))
    (is (equal '("X" "Y" "Z") (mpl.containers:fixed-formatter-seq fmt)))))

(test set-xticks-returns-axes
  "Test set-xticks returns the axes object."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (let ((result (mpl.containers:axes-set-xticks (gca) '(1 2 3))))
    (is (typep result 'mpl.containers:axes-base))))

;;; ============================================================
;;; axhspan / axvspan tests
;;; ============================================================

(test axhspan-basic
  "Test axhspan draws a horizontal span and returns Polygon."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((poly (axhspan 2.0 4.0)))
    (is (typep poly 'mpl.rendering:polygon))))

(test axhspan-with-alpha
  "Test axhspan sets alpha correctly."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((poly (axhspan 2.0 4.0 :alpha 0.5d0 :color "yellow")))
    (is (typep poly 'mpl.rendering:polygon))
    (is (= 0.5d0 (mpl.rendering:artist-alpha poly)))))

(test axvspan-basic
  "Test axvspan draws a vertical span and returns Polygon."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((poly (axvspan 1.0 3.0)))
    (is (typep poly 'mpl.rendering:polygon))))

(test axvspan-with-alpha
  "Test axvspan sets alpha correctly."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((poly (axvspan 1.0 3.0 :alpha 0.5 :color "blue")))
    (is (typep poly 'mpl.rendering:polygon))
    (is (= 0.5d0 (mpl.rendering:artist-alpha poly)))))

(test axhspan-no-autoscale
  "Test that axhspan does not affect existing axes limits."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((ax (gca)))
    (multiple-value-bind (x0 x1) (mpl.containers:axes-get-xlim ax)
      (multiple-value-bind (y0 y1) (mpl.containers:axes-get-ylim ax)
        ;; Add a span far outside original data range
        (axhspan 100.0 200.0 :color "red")
        ;; Limits should NOT have changed
        (multiple-value-bind (nx0 nx1) (mpl.containers:axes-get-xlim ax)
          (multiple-value-bind (ny0 ny1) (mpl.containers:axes-get-ylim ax)
            (is (= x0 nx0))
            (is (= x1 nx1))
            (is (= y0 ny0))
            (is (= y1 ny1))))))))

;;; ============================================================
;;; pcolormesh tests
;;; ============================================================

(test pcolormesh-basic
  "Test pcolormesh creates a scalar-mappable from a 2D array."
  (reset-pyplot-state)
  (let* ((data (make-array '(3 4) :element-type 'double-float :initial-element 0.5d0))
         (sm (pcolormesh data)))
    (is (typep sm 'mpl.primitives:scalar-mappable))
    ;; Axes should have artists
    (is (not (null (mpl.containers:axes-base-artists (gca)))))))

(test pcolormesh-with-cmap
  "Test pcolormesh with explicit colormap."
  (reset-pyplot-state)
  (let* ((data (make-array '(5 5) :element-type 'double-float))
         (_ (dotimes (i 5)
              (dotimes (j 5)
                (setf (aref data i j) (float (* i j) 1.0d0)))))
         (sm (pcolormesh data :cmap "plasma")))
    (declare (ignore _))
    (is (typep sm 'mpl.primitives:scalar-mappable))
    (is (string= "plasma" (mpl.primitives:colormap-name (mpl.primitives:sm-cmap sm))))))

(test pcolormesh-with-xy-coords
  "Test pcolormesh with explicit X, Y grid coordinates."
  (reset-pyplot-state)
  (let* ((h 3) (w 4)
         (c (make-array (list h w) :element-type 'double-float))
         (x (make-array (list (1+ h) (1+ w)) :element-type 'double-float))
         (y (make-array (list (1+ h) (1+ w)) :element-type 'double-float)))
    ;; Fill C
    (dotimes (i h) (dotimes (j w) (setf (aref c i j) (float (+ i j) 1.0d0))))
    ;; Fill X, Y (uniform grid scaled by 2)
    (dotimes (i (1+ h))
      (dotimes (j (1+ w))
        (setf (aref x i j) (float (* j 2.0d0) 1.0d0))
        (setf (aref y i j) (float (* i 2.0d0) 1.0d0))))
    (let ((sm (pcolormesh c :x x :y y)))
      (is (typep sm 'mpl.primitives:scalar-mappable))
      ;; Check axes limits reflect the explicit coords
      (multiple-value-bind (xmin xmax) (mpl.containers:axes-get-xlim (gca))
        (is (<= xmin 0.0d0))
        (is (>= xmax 8.0d0))))))

(test pcolormesh-colorbar-integration
  "Test pcolormesh result works with colorbar."
  (reset-pyplot-state)
  (let* ((data (make-array '(4 4) :element-type 'double-float))
         (_ (dotimes (i 4) (dotimes (j 4) (setf (aref data i j) (float (+ i j) 1.0d0)))))
         (sm (pcolormesh data :cmap :viridis :vmin 0.0 :vmax 6.0)))
    (declare (ignore _))
    ;; colorbar should accept the scalar-mappable
    (let ((cb (colorbar sm)))
      (is (typep cb 'mpl.containers:mpl-colorbar))
      ;; Check that colorbar has correct vmin/vmax
      (let* ((mappable (mpl.containers:colorbar-mappable cb))
             (norm (mpl.primitives:sm-norm mappable)))
        (is (= 0.0d0 (mpl.primitives:norm-vmin norm)))
        (is (= 6.0d0 (mpl.primitives:norm-vmax norm)))))))

;;; ============================================================
;;; twinx / twiny tests
;;; ============================================================

(test twinx-creates-new-axes
  "Test that twinx creates a new mpl-axes object."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (let ((parent (gca)))
    (let ((twin (twinx)))
      (is (typep twin 'mpl.containers:mpl-axes))
      (is (not (eq twin parent)))
      ;; Twin should now be the current axes (gca)
      (is (eq twin (gca))))))

(test twinx-shares-xlim
  "Test that twinx shares x-axis limits with parent."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((parent (gca)))
    (xlim 0 10)
    (let ((twin (twinx)))
      ;; Twin should have same x-limits as parent
      (multiple-value-bind (tx0 tx1) (mpl.containers:axes-get-xlim twin)
        (multiple-value-bind (px0 px1) (mpl.containers:axes-get-xlim parent)
          (is (= px0 tx0))
          (is (= px1 tx1)))))))

(test twinx-independent-ylim
  "Test that twinx has independent y-axis limits."
  (reset-pyplot-state)
  (plot '(1 2 3) '(10 20 30))
  (let ((parent (gca)))
    (let ((twin (twinx)))
      ;; Plot different y-range data on twin
      (mpl.containers:plot twin '(1 2 3) '(100 200 300))
      ;; Twin y-limits should differ from parent
      (multiple-value-bind (ty0 ty1) (mpl.containers:axes-get-ylim twin)
        (multiple-value-bind (py0 py1) (mpl.containers:axes-get-ylim parent)
          (is (not (and (= py0 ty0) (= py1 ty1)))))))))

(test twiny-creates-new-axes
  "Test that twiny creates a new mpl-axes object."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (let ((parent (gca)))
    (let ((twin (twiny)))
      (is (typep twin 'mpl.containers:mpl-axes))
      (is (not (eq twin parent)))
      ;; Twin should now be the current axes (gca)
      (is (eq twin (gca))))))

(test twiny-shares-ylim
  "Test that twiny shares y-axis limits with parent."
  (reset-pyplot-state)
  (plot '(0 10) '(0 20))
  (let ((parent (gca)))
    (ylim 0 20)
    (let ((twin (twiny)))
      ;; Twin should have same y-limits as parent
      (multiple-value-bind (ty0 ty1) (mpl.containers:axes-get-ylim twin)
        (multiple-value-bind (py0 py1) (mpl.containers:axes-get-ylim parent)
          (is (= py0 ty0))
          (is (= py1 ty1)))))))

(test twinx-added-to-figure
  "Test that twinx axes is added to the figure's axes list."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (let ((fig (gcf))
        (n-before (length (mpl.containers:figure-axes (gcf)))))
    (twinx)
    (is (= (1+ n-before) (length (mpl.containers:figure-axes fig))))))

(test twinx-yaxis-on-right
  "Test that twinx y-axis is set to draw on the right side."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (let ((twin (twinx)))
    (is (eq :right (mpl.containers:axis-side
                     (mpl.containers:axes-base-yaxis twin))))))

(test twiny-xaxis-on-top
  "Test that twiny x-axis is set to draw on the top side."
  (reset-pyplot-state)
  (plot '(1 2 3) '(1 2 3))
  (let ((twin (twiny)))
    (is (eq :top (mpl.containers:axis-side
                   (mpl.containers:axes-base-xaxis twin))))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-pyplot-tests ()
  "Run all pyplot tests and report results."
  (let ((results (run 'pyplot-suite)))
    (explain! results)
    (unless (results-status results)
      (error "pyplot tests failed!"))))
