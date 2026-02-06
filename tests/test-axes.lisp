;;;; test-axes.lisp — Tests for Axes, AxesBase, plot, scatter, bar
;;;; Phase 4b — FiveAM test suite

(defpackage #:cl-matplotlib.tests.axes
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; AxesBase
                #:axes-base #:axes-base-figure #:axes-base-position
                #:axes-base-facecolor #:axes-base-frameon-p
                #:axes-base-trans-data #:axes-base-trans-axes #:axes-base-trans-scale
                #:axes-base-data-lim #:axes-base-view-lim
                #:axes-base-lines #:axes-base-patches #:axes-base-artists
                #:axes-base-texts #:axes-base-images #:axes-base-patch
                #:axes-base-autoscale-x-p #:axes-base-autoscale-y-p
                #:axes-base-autoscale-margin
                ;; AxesBase functions
                #:axes-update-datalim #:axes-autoscale-view
                #:axes-set-xlim #:axes-set-ylim
                #:axes-get-xlim #:axes-get-ylim
                #:axes-add-line #:axes-add-patch #:axes-add-artist
                #:axes-get-all-artists
                ;; Axes
                #:mpl-axes
                ;; Plotting functions
                #:add-subplot #:plot #:scatter #:bar #:axes-fill #:fill-between
                ;; Figure
                #:mpl-figure #:make-figure
                #:figure-axes #:figure-width-px #:figure-height-px
                #:savefig)
  (:export #:run-axes-tests))

(in-package #:cl-matplotlib.tests.axes)

(def-suite axes-suite :description "Axes and plotting test suite")
(in-suite axes-suite)

;;; ============================================================
;;; Helpers
;;; ============================================================

(defun tmp-path (name ext)
  "Create a temporary file path."
  (format nil "/tmp/cl-mpl-test-~A.~A" name ext))

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
      (and (= (read-byte s) 137)
           (= (read-byte s) 80)
           (= (read-byte s) 78)
           (= (read-byte s) 71)))))

(defun approx= (a b &optional (epsilon 0.01d0))
  "Return T if A and B are approximately equal."
  (< (abs (- a b)) epsilon))

;;; ============================================================
;;; AxesBase Creation Tests
;;; ============================================================

(test axes-base-creation
  "AxesBase can be created with defaults."
  (let ((ax (make-instance 'axes-base)))
    (is (typep ax 'axes-base))
    (is (typep ax 'mpl.rendering:artist))
    (is (not (null (axes-base-position ax))))
    (is (not (null (axes-base-view-lim ax))))
    (is (not (null (axes-base-patch ax))))))

(test axes-base-default-position
  "AxesBase has default subplot position."
  (let ((ax (make-instance 'axes-base)))
    (let ((pos (axes-base-position ax)))
      (is (= 4 (length pos)))
      (is (approx= 0.125d0 (first pos)))
      (is (approx= 0.11d0 (second pos))))))

(test axes-base-custom-position
  "AxesBase accepts custom position."
  (let ((ax (make-instance 'axes-base :position (list 0.1d0 0.1d0 0.8d0 0.8d0))))
    (is (equal (list 0.1d0 0.1d0 0.8d0 0.8d0)
               (axes-base-position ax)))))

(test axes-base-with-figure
  "AxesBase links to parent figure."
  (let* ((fig (make-figure))
         (ax (make-instance 'axes-base :figure fig)))
    (is (eq fig (axes-base-figure ax)))
    (is (eq fig (mpl.rendering:artist-figure ax)))))

(test axes-base-has-background-patch
  "AxesBase has a background rectangle patch."
  (let ((ax (make-instance 'axes-base :facecolor "lightblue")))
    (is (typep (axes-base-patch ax) 'mpl.rendering:rectangle))))

;;; ============================================================
;;; Transform Tests
;;; ============================================================

(test axes-base-transforms-created
  "AxesBase creates transData, transAxes, transScale on init."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (make-instance 'axes-base :figure fig)))
    (is (not (null (axes-base-trans-data ax))))
    (is (not (null (axes-base-trans-axes ax))))
    (is (not (null (axes-base-trans-scale ax))))))

(test axes-trans-axes-maps-unit-to-display
  "transAxes maps (0,0) and (1,1) to axes display corners."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (make-instance 'axes-base
                            :figure fig
                            :position (list 0.125d0 0.11d0 0.775d0 0.77d0))))
    (let* ((trans (axes-base-trans-axes ax))
           (p00 (mpl.primitives:transform-point trans (list 0.0d0 0.0d0)))
           (p11 (mpl.primitives:transform-point trans (list 1.0d0 1.0d0))))
      ;; (0,0) should map to bottom-left of axes in display coords
      ;; Position: left=0.125, bottom=0.11, width=0.775, height=0.77
      ;; Figure: 640x480
      ;; Expected: x0 = 0.125*640 = 80, y0 = 0.11*480 = 52.8
      ;; Expected: x1 = (0.125+0.775)*640 = 576, y1 = (0.11+0.77)*480 = 422.4
      (is (approx= 80.0d0 (aref p00 0) 1.0d0))
      (is (approx= 52.8d0 (aref p00 1) 1.0d0))
      (is (approx= 576.0d0 (aref p11 0) 1.0d0))
      (is (approx= 422.4d0 (aref p11 1) 1.0d0)))))

(test axes-trans-data-maps-view-to-display
  "transData maps view limits to display coords."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (make-instance 'axes-base :figure fig
                            :position (list 0.0d0 0.0d0 1.0d0 1.0d0))))
    ;; Set view limits to 0-10 in both axes
    (setf (axes-base-view-lim ax)
          (mpl.primitives:make-bbox 0.0d0 0.0d0 10.0d0 10.0d0))
    ;; Update transData
    (cl-matplotlib.containers::%update-trans-data ax)
    (let* ((trans (axes-base-trans-data ax))
           ;; (0,0) in data should map to (0,0) in display (full-figure axes)
           (p00 (mpl.primitives:transform-point trans (list 0.0d0 0.0d0)))
           ;; (10,10) should map to (640,480)
           (p11 (mpl.primitives:transform-point trans (list 10.0d0 10.0d0)))
           ;; (5,5) should map to (320,240)
           (pmid (mpl.primitives:transform-point trans (list 5.0d0 5.0d0))))
      (is (approx= 0.0d0 (aref p00 0) 1.0d0))
      (is (approx= 0.0d0 (aref p00 1) 1.0d0))
      (is (approx= 640.0d0 (aref p11 0) 1.0d0))
      (is (approx= 480.0d0 (aref p11 1) 1.0d0))
      (is (approx= 320.0d0 (aref pmid 0) 1.0d0))
      (is (approx= 240.0d0 (aref pmid 1) 1.0d0)))))

;;; ============================================================
;;; Data Limit Tests
;;; ============================================================

(test axes-update-datalim-basic
  "axes-update-datalim expands data limits."
  (let ((ax (make-instance 'axes-base)))
    (axes-update-datalim ax '(1 2 3) '(4 5 6))
    (let ((dl (axes-base-data-lim ax)))
      (is (= 1.0d0 (mpl.primitives:bbox-x0 dl)))
      (is (= 4.0d0 (mpl.primitives:bbox-y0 dl)))
      (is (= 3.0d0 (mpl.primitives:bbox-x1 dl)))
      (is (= 6.0d0 (mpl.primitives:bbox-y1 dl))))))

(test axes-update-datalim-expand
  "axes-update-datalim expands when called multiple times."
  (let ((ax (make-instance 'axes-base)))
    (axes-update-datalim ax '(1 2 3) '(1 2 3))
    (axes-update-datalim ax '(0 5) '(0 10))
    (let ((dl (axes-base-data-lim ax)))
      (is (= 0.0d0 (mpl.primitives:bbox-x0 dl)))
      (is (= 0.0d0 (mpl.primitives:bbox-y0 dl)))
      (is (= 5.0d0 (mpl.primitives:bbox-x1 dl)))
      (is (= 10.0d0 (mpl.primitives:bbox-y1 dl))))))

(test axes-autoscale-view-basic
  "axes-autoscale-view sets view limits from data limits."
  (let ((ax (make-instance 'axes-base)))
    (axes-update-datalim ax '(0 10) '(0 100))
    (axes-autoscale-view ax)
    (let ((vl (axes-base-view-lim ax)))
      ;; With 5% margin: x range 10, margin 0.5
      (is (approx= -0.5d0 (mpl.primitives:bbox-x0 vl) 0.1d0))
      (is (approx= 10.5d0 (mpl.primitives:bbox-x1 vl) 0.1d0))
      ;; y range 100, margin 5
      (is (approx= -5.0d0 (mpl.primitives:bbox-y0 vl) 0.1d0))
      (is (approx= 105.0d0 (mpl.primitives:bbox-y1 vl) 0.1d0)))))

(test axes-autoscale-view-tight
  "axes-autoscale-view with tight=t uses exact limits."
  (let ((ax (make-instance 'axes-base)))
    (axes-update-datalim ax '(0 10) '(0 100))
    (axes-autoscale-view ax :tight t)
    (let ((vl (axes-base-view-lim ax)))
      (is (= 0.0d0 (mpl.primitives:bbox-x0 vl)))
      (is (= 10.0d0 (mpl.primitives:bbox-x1 vl)))
      (is (= 0.0d0 (mpl.primitives:bbox-y0 vl)))
      (is (= 100.0d0 (mpl.primitives:bbox-y1 vl))))))

;;; ============================================================
;;; Set/Get Limits Tests
;;; ============================================================

(test axes-set-get-xlim
  "axes-set-xlim and axes-get-xlim work correctly."
  (let ((ax (make-instance 'axes-base)))
    (axes-set-xlim ax :min 0 :max 10)
    (multiple-value-bind (xmin xmax) (axes-get-xlim ax)
      (is (= 0.0d0 xmin))
      (is (= 10.0d0 xmax)))
    ;; Setting xlim disables autoscale
    (is (null (axes-base-autoscale-x-p ax)))))

(test axes-set-get-ylim
  "axes-set-ylim and axes-get-ylim work correctly."
  (let ((ax (make-instance 'axes-base)))
    (axes-set-ylim ax :min -5 :max 5)
    (multiple-value-bind (ymin ymax) (axes-get-ylim ax)
      (is (= -5.0d0 ymin))
      (is (= 5.0d0 ymax)))))

;;; ============================================================
;;; Artist Management Tests
;;; ============================================================

(test axes-add-line
  "Lines can be added to axes."
  (let ((ax (make-instance 'axes-base))
        (line (make-instance 'mpl.rendering:line-2d
                             :xdata '(1 2 3) :ydata '(1 4 9))))
    (axes-add-line ax line)
    (is (= 1 (length (axes-base-lines ax))))
    (is (eq ax (mpl.rendering:artist-axes line)))))

(test axes-add-patch
  "Patches can be added to axes."
  (let ((ax (make-instance 'axes-base))
        (rect (make-instance 'mpl.rendering:rectangle
                             :x0 0.0d0 :y0 0.0d0
                             :width 1.0d0 :height 1.0d0)))
    (axes-add-patch ax rect)
    (is (= 1 (length (axes-base-patches ax))))
    (is (eq ax (mpl.rendering:artist-axes rect)))))

(test axes-get-all-artists-sorted
  "axes-get-all-artists returns z-order sorted list."
  (let ((ax (make-instance 'axes-base))
        (line (make-instance 'mpl.rendering:line-2d :zorder 2))
        (rect (make-instance 'mpl.rendering:rectangle
                             :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0
                             :zorder 1)))
    (axes-add-line ax line)
    (axes-add-patch ax rect)
    (let ((artists (axes-get-all-artists ax)))
      ;; Should include background patch (z=0), rect (z=1), line (z=2)
      (is (>= (length artists) 3))
      ;; Check z-order is ascending
      (let ((zorders (mapcar #'mpl.rendering:artist-zorder artists)))
        (is (apply #'<= zorders))))))

;;; ============================================================
;;; add-subplot Tests
;;; ============================================================

(test add-subplot-basic
  "add-subplot creates axes in figure."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (is (typep ax 'mpl-axes))
    (is (eq fig (axes-base-figure ax)))
    (is (member ax (figure-axes fig)))))

(test add-subplot-position-1-1-1
  "add-subplot(1,1,1) fills the plot area."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (pos (axes-base-position ax)))
    ;; For 1x1 grid, the axes should span the full subplot area
    ;; Default subplot params: left=0.125, right=0.9, bottom=0.11, top=0.88
    (is (approx= 0.125d0 (first pos)))
    (is (approx= 0.11d0 (second pos)))
    ;; Width = right - left = 0.775, Height = top - bottom = 0.77
    (is (approx= 0.775d0 (third pos)))
    (is (approx= 0.77d0 (fourth pos)))))

(test add-subplot-2x2-grid
  "add-subplot creates correct positions for 2x2 grid."
  (let* ((fig (make-figure))
         (ax1 (add-subplot fig 2 2 1))
         (ax2 (add-subplot fig 2 2 2))
         (ax3 (add-subplot fig 2 2 3))
         (ax4 (add-subplot fig 2 2 4)))
    (is (= 4 (length (figure-axes fig))))
    ;; ax1 should be top-left, ax2 top-right
    ;; ax3 should be bottom-left, ax4 bottom-right
    (let ((p1 (axes-base-position ax1))
          (p4 (axes-base-position ax4)))
      ;; ax1 is at row=0, col=0 (top-left)
      ;; ax4 is at row=1, col=1 (bottom-right)
      ;; ax4 should have greater x than ax1
      (is (> (first p4) (first p1)))
      ;; ax1 should have greater y than ax4 (top vs bottom)
      (is (> (second p1) (second p4))))))

;;; ============================================================
;;; plot() Tests
;;; ============================================================

(test plot-basic
  "plot() creates a Line2D and adds to axes."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (lines (plot ax '(1 2 3 4) '(1 4 9 16))))
    (is (= 1 (length lines)))
    (is (typep (first lines) 'mpl.rendering:line-2d))
    (is (= 1 (length (axes-base-lines ax))))))

(test plot-updates-data-limits
  "plot() updates axes data limits."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (let ((dl (axes-base-data-lim ax)))
      (is (= 1.0d0 (mpl.primitives:bbox-x0 dl)))
      (is (= 1.0d0 (mpl.primitives:bbox-y0 dl)))
      (is (= 4.0d0 (mpl.primitives:bbox-x1 dl)))
      (is (= 16.0d0 (mpl.primitives:bbox-y1 dl))))))

(test plot-autoscales
  "plot() triggers autoscaling."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(0 10) '(0 100))
    (let ((vl (axes-base-view-lim ax)))
      ;; View limits should be slightly larger than data limits (5% margin)
      (is (< (mpl.primitives:bbox-x0 vl) 0.0d0))
      (is (> (mpl.primitives:bbox-x1 vl) 10.0d0)))))

(test plot-with-options
  "plot() accepts color, linewidth, etc."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (lines (plot ax '(1 2 3) '(1 4 9)
                      :color "red" :linewidth 3.0 :linestyle :dashed)))
    (let ((line (first lines)))
      (is (string= "red" (mpl.rendering:line-2d-color line)))
      (is (= 3.0 (mpl.rendering:line-2d-linewidth line)))
      (is (eq :dashed (mpl.rendering:line-2d-linestyle line))))))

(test plot-multiple-calls
  "Multiple plot() calls accumulate lines."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9))
    (plot ax '(1 2 3) '(2 5 10))
    (is (= 2 (length (axes-base-lines ax))))))

;;; ============================================================
;;; scatter() Tests
;;; ============================================================

(test scatter-basic
  "scatter() creates patches for each point."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (artists (scatter ax '(1 2 3 4 5) '(2 4 1 5 3))))
    (is (= 5 (length artists)))
    (is (= 5 (length (axes-base-patches ax))))))

(test scatter-updates-data-limits
  "scatter() updates axes data limits."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (scatter ax '(1 2 3) '(10 20 30))
    (let ((dl (axes-base-data-lim ax)))
      (is (= 1.0d0 (mpl.primitives:bbox-x0 dl)))
      (is (= 10.0d0 (mpl.primitives:bbox-y0 dl)))
      (is (= 3.0d0 (mpl.primitives:bbox-x1 dl)))
      (is (= 30.0d0 (mpl.primitives:bbox-y1 dl))))))

(test scatter-with-color
  "scatter() accepts color option."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (artists (scatter ax '(1 2) '(3 4) :color "green")))
    (is (= 2 (length artists)))))

;;; ============================================================
;;; bar() Tests
;;; ============================================================

(test bar-basic
  "bar() creates rectangle patches."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (rects (bar ax '(1 2 3) '(5 7 3))))
    (is (= 3 (length rects)))
    (is (every (lambda (r) (typep r 'mpl.rendering:rectangle)) rects))
    (is (= 3 (length (axes-base-patches ax))))))

(test bar-updates-data-limits
  "bar() updates data limits correctly."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (bar ax '(1 2 3) '(5 7 3))
    (let ((dl (axes-base-data-lim ax)))
      ;; x: bars at 1,2,3 with width 0.8, centered → x range [0.6, 3.4]
      (is (approx= 0.6d0 (mpl.primitives:bbox-x0 dl)))
      (is (approx= 3.4d0 (mpl.primitives:bbox-x1 dl)))
      ;; y: heights 5,7,3 from bottom=0 → y range [0, 7]
      (is (= 0.0d0 (mpl.primitives:bbox-y0 dl)))
      (is (= 7.0d0 (mpl.primitives:bbox-y1 dl))))))

(test bar-with-options
  "bar() accepts width, color, etc."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (rects (bar ax '(1 2 3) '(5 7 3)
                     :width 0.5 :color "green" :edgecolor "black")))
    (is (= 3 (length rects)))))

;;; ============================================================
;;; fill() Tests
;;; ============================================================

(test fill-basic
  "fill() creates a polygon patch."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (poly (axes-fill ax '(0 1 0.5) '(0 0 1))))
    (is (typep poly 'mpl.rendering:polygon))
    (is (= 1 (length (axes-base-patches ax))))))

(test fill-updates-data-limits
  "fill() updates data limits."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (axes-fill ax '(0 10 5) '(0 0 10))
    (let ((dl (axes-base-data-lim ax)))
      (is (= 0.0d0 (mpl.primitives:bbox-x0 dl)))
      (is (= 10.0d0 (mpl.primitives:bbox-x1 dl)))
      (is (= 0.0d0 (mpl.primitives:bbox-y0 dl)))
      (is (= 10.0d0 (mpl.primitives:bbox-y1 dl))))))

;;; ============================================================
;;; fill-between() Tests
;;; ============================================================

(test fill-between-basic
  "fill-between() creates a polygon between two curves."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (poly (fill-between ax '(0 1 2 3) '(0 1 2 3) '(0 2 4 6))))
    (is (typep poly 'mpl.rendering:polygon))
    (is (= 1 (length (axes-base-patches ax))))))

;;; ============================================================
;;; Axes Draw Tests
;;; ============================================================

(test axes-draw-with-mock-renderer
  "Axes can be drawn with mock renderer."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (renderer (mpl.rendering:make-mock-renderer)))
    (plot ax '(1 2 3) '(1 4 9))
    ;; Should not error
    (mpl.rendering:draw ax renderer)
    (pass)))

(test axes-draw-marks-not-stale
  "Drawing marks axes as not stale."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (renderer (mpl.rendering:make-mock-renderer)))
    (is (eq t (mpl.rendering:artist-stale ax)))
    (mpl.rendering:draw ax renderer)
    (is (null (mpl.rendering:artist-stale ax)))))

;;; ============================================================
;;; Pipeline Integration Tests — PNG Output
;;; ============================================================

(test pipeline-plot-to-png
  "Full pipeline: plot() → savefig produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "axes-plot" "png")))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-scatter-to-png
  "Full pipeline: scatter() → savefig produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "axes-scatter" "png")))
    (scatter ax '(1 2 3 4 5) '(2 4 1 5 3))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-bar-to-png
  "Full pipeline: bar() → savefig produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "axes-bar" "png")))
    (bar ax '(1 2 3) '(5 7 3))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-fill-to-png
  "Full pipeline: fill() → savefig produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "axes-fill" "png")))
    (axes-fill ax '(0 1 0.5) '(0 0 1))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-fill-between-to-png
  "Full pipeline: fill-between() → savefig produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "axes-fill-between" "png")))
    (fill-between ax '(0 1 2 3) '(0 1 2 3) '(0 2 4 6))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; MVP Scenario Tests
;;; ============================================================

(test mvp-plot-produces-png
  "MVP: plot() produces PNG with visible data."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "mvp-plot" "png")))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (savefig fig path)
    ;; File must exist and be a non-trivial PNG
    (is (file-exists-and-valid-p path 1000))
    (is (png-header-valid-p path))))

(test mvp-scatter-produces-png
  "MVP: scatter() produces PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "mvp-scatter" "png")))
    (scatter ax '(1 2 3 4 5) '(2 4 1 5 3))
    (savefig fig path)
    (is (file-exists-and-valid-p path 1000))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Print Object Test
;;; ============================================================

(test axes-print-object
  "Axes prints a readable representation."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9))
    (let ((str (format nil "~A" ax)))
      ;; Should contain the type name somewhere
      (is (or (search "AXES-BASE" str)
              (search "MPL-AXES" str)
              (search "xlim" str))))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-axes-tests ()
  "Run all axes tests and return success boolean."
  (let ((results (run 'axes-suite)))
    (explain! results)
    (results-status results)))
