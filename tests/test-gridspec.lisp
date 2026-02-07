;;;; test-gridspec.lisp — Tests for GridSpec, SubplotSpec, subplots, subplot-mosaic
;;;; Phase 5b — FiveAM test suite

(defpackage #:cl-matplotlib.tests.gridspec
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; GridSpec classes
                #:gridspec-base #:gridspec #:gridspec-from-subplot-spec
                #:subplot-spec
                ;; Constructors
                #:make-gridspec #:make-subplot-spec #:make-gridspec-from-subplot-spec
                ;; GridSpec accessors
                #:gridspec-nrows #:gridspec-ncols #:gridspec-figure
                #:gridspec-left #:gridspec-right #:gridspec-top #:gridspec-bottom
                #:gridspec-wspace #:gridspec-hspace
                #:gridspec-width-ratios #:gridspec-height-ratios
                ;; GridSpec functions
                #:gridspec-get-geometry #:gridspec-get-subplot-params
                #:gridspec-get-grid-positions #:gridspec-subplotspec
                ;; SubplotSpec
                #:subplotspec-gridspec #:subplotspec-num1 #:subplotspec-num2
                #:subplotspec-get-gridspec #:subplotspec-get-rows-columns
                #:subplotspec-rowspan #:subplotspec-colspan
                #:subplotspec-get-position
                ;; GridSpecFromSubplotSpec
                #:gridspec-from-ss-parent
                ;; Subplots and mosaic
                #:subplots #:subplot-mosaic
                ;; Figure
                #:make-figure #:figure-axes
                ;; Axes
                #:mpl-axes #:axes-base #:axes-base-position
                #:axes-base-view-lim
                ;; Shared axes
                #:axes-share-x #:axes-share-y
                #:axes-base-sharex-group #:axes-base-sharey-group
                ;; Limits
                #:axes-set-xlim #:axes-set-ylim
                #:axes-get-xlim #:axes-get-ylim
                ;; Plotting
                #:plot #:add-subplot
                ;; Savefig
                #:savefig)
  (:export #:run-gridspec-tests))

(in-package #:cl-matplotlib.tests.gridspec)

(def-suite gridspec-suite :description "GridSpec, SubplotSpec, subplots, subplot-mosaic tests")
(in-suite gridspec-suite)

;;; ============================================================
;;; Helper
;;; ============================================================

(defun approx= (a b &optional (epsilon 0.001d0))
  "Check that A and B are approximately equal."
  (< (abs (- a b)) epsilon))

;;; ============================================================
;;; GridSpec construction tests
;;; ============================================================

(test gridspec-basic-construction
  "GridSpec with nrows and ncols."
  (let ((gs (make-gridspec 2 3)))
    (is (= 2 (gridspec-nrows gs)))
    (is (= 3 (gridspec-ncols gs)))
    (is (null (gridspec-figure gs)))
    (is (null (gridspec-left gs)))
    (is (null (gridspec-right gs)))))

(test gridspec-with-figure
  "GridSpec associated with a figure."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig)))
    (is (eq fig (gridspec-figure gs)))))

(test gridspec-with-params
  "GridSpec with explicit layout parameters."
  (let ((gs (make-gridspec 2 2 :left 0.1 :right 0.95 :top 0.95 :bottom 0.1
                               :wspace 0.3 :hspace 0.4)))
    (is (approx= 0.1d0 (gridspec-left gs)))
    (is (approx= 0.95d0 (gridspec-right gs)))
    (is (approx= 0.3d0 (gridspec-wspace gs)))
    (is (approx= 0.4d0 (gridspec-hspace gs)))))

(test gridspec-invalid-dimensions
  "GridSpec rejects invalid dimensions."
  (signals error (make-gridspec 0 2))
  (signals error (make-gridspec -1 2))
  (signals error (make-gridspec 2 0)))

(test gridspec-default-ratios
  "Default width/height ratios are all 1."
  (let ((gs (make-gridspec 3 2)))
    (is (= 3 (length (gridspec-height-ratios gs))))
    (is (= 2 (length (gridspec-width-ratios gs))))
    (is (every (lambda (r) (approx= 1.0d0 r)) (gridspec-height-ratios gs)))
    (is (every (lambda (r) (approx= 1.0d0 r)) (gridspec-width-ratios gs)))))

(test gridspec-custom-ratios
  "GridSpec with custom width/height ratios."
  (let ((gs (make-gridspec 2 3 :height-ratios '(1 2) :width-ratios '(1 2 1))))
    (is (equal '(1 2) (gridspec-height-ratios gs)))
    (is (equal '(1 2 1) (gridspec-width-ratios gs)))))

(test gridspec-invalid-ratios
  "GridSpec rejects ratios of wrong length."
  (signals error (make-gridspec 2 3 :height-ratios '(1 2 3)))  ; should be length 2
  (signals error (make-gridspec 2 3 :width-ratios '(1 2))))      ; should be length 3

;;; ============================================================
;;; GridSpec geometry tests
;;; ============================================================

(test gridspec-get-geometry
  "get-geometry returns nrows and ncols."
  (let ((gs (make-gridspec 3 4)))
    (multiple-value-bind (nr nc) (gridspec-get-geometry gs)
      (is (= 3 nr))
      (is (= 4 nc)))))

(test gridspec-get-subplot-params-defaults
  "get-subplot-params returns defaults when no figure."
  (let* ((gs (make-gridspec 2 2))
         (params (gridspec-get-subplot-params gs)))
    (is (approx= 0.125d0 (getf params :left)))
    (is (approx= 0.9d0 (getf params :right)))
    (is (approx= 0.11d0 (getf params :bottom)))
    (is (approx= 0.88d0 (getf params :top)))
    (is (approx= 0.2d0 (getf params :wspace)))
    (is (approx= 0.2d0 (getf params :hspace)))))

(test gridspec-get-subplot-params-with-overrides
  "get-subplot-params merges GridSpec overrides."
  (let* ((gs (make-gridspec 2 2 :left 0.05 :wspace 0.1))
         (params (gridspec-get-subplot-params gs)))
    (is (approx= 0.05d0 (getf params :left)))
    (is (approx= 0.1d0 (getf params :wspace)))
    ;; Other values remain default
    (is (approx= 0.9d0 (getf params :right)))))

(test gridspec-get-subplot-params-with-figure
  "get-subplot-params uses figure subplot params as defaults."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig)))
    (let ((params (gridspec-get-subplot-params gs fig)))
      ;; Should use figure defaults
      (is (numberp (getf params :left)))
      (is (numberp (getf params :right))))))

;;; ============================================================
;;; Grid positions tests
;;; ============================================================

(test gridspec-grid-positions-2x2
  "Grid positions for a 2x2 grid."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig)))
    (multiple-value-bind (bottoms tops lefts rights)
        (gridspec-get-grid-positions gs fig)
      ;; Should have 2 rows and 2 columns
      (is (= 2 (length bottoms)))
      (is (= 2 (length tops)))
      (is (= 2 (length lefts)))
      (is (= 2 (length rights)))
      ;; Row 0 should be above row 1
      (is (> (first tops) (second tops)))
      ;; Column 0 should be left of column 1
      (is (< (first lefts) (second lefts)))
      ;; Tops should be above bottoms
      (is (> (first tops) (first bottoms)))
      (is (> (second tops) (second bottoms))))))

(test gridspec-grid-positions-1x1
  "Grid positions for a 1x1 grid fill available area."
  (let* ((fig (make-figure))
         (gs (make-gridspec 1 1 :figure fig)))
    (multiple-value-bind (bottoms tops lefts rights)
        (gridspec-get-grid-positions gs fig)
      (is (= 1 (length bottoms)))
      (is (approx= 0.125d0 (first lefts)))
      (is (approx= 0.9d0 (first rights)))
      (is (approx= 0.11d0 (first bottoms)))
      (is (approx= 0.88d0 (first tops))))))

(test gridspec-grid-positions-with-ratios
  "Grid positions respect width/height ratios."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig :width-ratios '(1 3) :height-ratios '(1 2))))
    (multiple-value-bind (bottoms tops lefts rights)
        (gridspec-get-grid-positions gs fig)
      ;; Column 1 (ratio 3) should be 3x wider than column 0 (ratio 1)
      (let ((w0 (- (first rights) (first lefts)))
            (w1 (- (second rights) (second lefts))))
        (is (approx= 3.0d0 (/ w1 w0) 0.05)))
      ;; Row 1 (ratio 2) should be 2x taller than row 0 (ratio 1)
      (let ((h0 (- (first tops) (first bottoms)))
            (h1 (- (second tops) (second bottoms))))
        (is (approx= 2.0d0 (/ h1 h0) 0.05))))))

;;; ============================================================
;;; SubplotSpec tests
;;; ============================================================

(test subplot-spec-basic
  "SubplotSpec for single cell."
  (let* ((gs (make-gridspec 2 3))
         (ss (make-subplot-spec gs 0)))
    (is (eq gs (subplotspec-gridspec ss)))
    (is (= 0 (subplotspec-num1 ss)))
    (is (= 0 (subplotspec-num2 ss)))))

(test subplot-spec-spanning
  "SubplotSpec spanning multiple cells."
  (let* ((gs (make-gridspec 2 3))
         (ss (make-subplot-spec gs 0 5)))
    (is (= 0 (subplotspec-num1 ss)))
    (is (= 5 (subplotspec-num2 ss)))))

(test gridspec-subplotspec-single-cell
  "gridspec-subplotspec for single cell."
  (let* ((gs (make-gridspec 2 3))
         (ss (gridspec-subplotspec gs 0 1)))
    (is (= 1 (subplotspec-num1 ss)))  ; row=0, col=1 → index 1 in 3-col grid
    (is (= 1 (subplotspec-num2 ss)))))

(test gridspec-subplotspec-spanning
  "gridspec-subplotspec with rowspan/colspan."
  (let* ((gs (make-gridspec 3 3))
         (ss (gridspec-subplotspec gs 0 0 :rowspan 2 :colspan 2)))
    ;; num1 = 0*3 + 0 = 0, num2 = 1*3 + 1 = 4
    (is (= 0 (subplotspec-num1 ss)))
    (is (= 4 (subplotspec-num2 ss)))))

(test subplotspec-get-rows-columns
  "get-rows-columns returns correct row/col bounds."
  (let* ((gs (make-gridspec 3 3))
         (ss (gridspec-subplotspec gs 0 1 :rowspan 2 :colspan 1)))
    (multiple-value-bind (r1 r2 c1 c2)
        (subplotspec-get-rows-columns ss)
      (is (= 0 r1))
      (is (= 1 r2))
      (is (= 1 c1))
      (is (= 1 c2)))))

(test subplotspec-rowspan-colspan
  "rowspan and colspan accessors."
  (let* ((gs (make-gridspec 3 4))
         (ss (gridspec-subplotspec gs 1 1 :rowspan 2 :colspan 3)))
    (multiple-value-bind (rs-start rs-stop) (subplotspec-rowspan ss)
      (is (= 1 rs-start))
      (is (= 3 rs-stop)))
    (multiple-value-bind (cs-start cs-stop) (subplotspec-colspan ss)
      (is (= 1 cs-start))
      (is (= 4 cs-stop)))))

(test subplotspec-get-position
  "get-position returns valid figure coordinates."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig))
         (ss (gridspec-subplotspec gs 0 0)))
    (let ((pos (subplotspec-get-position ss fig)))
      ;; Should return (left bottom width height)
      (is (= 4 (length pos)))
      (is (> (first pos) 0))    ; left > 0
      (is (> (second pos) 0))   ; bottom > 0
      (is (> (third pos) 0))    ; width > 0
      (is (> (fourth pos) 0))))) ; height > 0

(test subplotspec-positions-dont-overlap
  "Positions of adjacent cells don't overlap."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig))
         (ss00 (gridspec-subplotspec gs 0 0))
         (ss01 (gridspec-subplotspec gs 0 1))
         (ss10 (gridspec-subplotspec gs 1 0)))
    (let ((pos00 (subplotspec-get-position ss00 fig))
          (pos01 (subplotspec-get-position ss01 fig))
          (pos10 (subplotspec-get-position ss10 fig)))
      ;; Cell (0,1) should be to the right of (0,0)
      (is (> (first pos01) (+ (first pos00) (third pos00) -0.01)))
      ;; Cell (1,0) should be below (0,0) 
      ;; Note: row 0 is top, row 1 is bottom. So pos10's bottom < pos00's bottom
      (is (< (second pos10) (second pos00))))))

(test subplotspec-spanning-position
  "Spanning SubplotSpec covers correct area."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig))
         (ss-single (gridspec-subplotspec gs 0 0))
         (ss-span (gridspec-subplotspec gs 0 0 :rowspan 1 :colspan 2)))
    (let ((pos-single (subplotspec-get-position ss-single fig))
          (pos-span (subplotspec-get-position ss-span fig)))
      ;; Spanning cell should be roughly 2x wider
      (is (> (third pos-span) (* 1.5 (third pos-single)))))))

;;; ============================================================
;;; GridSpecFromSubplotSpec tests
;;; ============================================================

(test gridspec-from-subplot-spec-basic
  "Nested GridSpec within a SubplotSpec."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig))
         (ss (gridspec-subplotspec gs 0 0))
         (inner-gs (make-gridspec-from-subplot-spec 2 2 ss)))
    (is (= 2 (gridspec-nrows inner-gs)))
    (is (= 2 (gridspec-ncols inner-gs)))
    (is (eq ss (gridspec-from-ss-parent inner-gs)))))

(test gridspec-from-subplot-spec-positions
  "Nested grid positions are within parent cell."
  (let* ((fig (make-figure))
         (gs (make-gridspec 2 2 :figure fig))
         (ss (gridspec-subplotspec gs 0 0))
         (parent-pos (subplotspec-get-position ss fig))
         (inner-gs (make-gridspec-from-subplot-spec 2 2 ss)))
    (multiple-value-bind (bottoms tops lefts rights)
        (gridspec-get-grid-positions inner-gs fig)
      ;; All inner positions should be within parent bounds
      (let ((p-left (first parent-pos))
            (p-bottom (second parent-pos))
            (p-right (+ (first parent-pos) (third parent-pos)))
            (p-top (+ (second parent-pos) (fourth parent-pos))))
        ;; Inner lefts should be >= parent left
        (is (>= (first lefts) (- p-left 0.01)))
        ;; Inner rights should be <= parent right
        (is (<= (first rights) (+ p-right 0.01)))
        ;; Inner tops should be <= parent top
        (is (<= (first tops) (+ p-top 0.01)))
        ;; Inner bottoms should be >= parent bottom
        (is (>= (second bottoms) (- p-bottom 0.01)))))))

;;; ============================================================
;;; Shared axes tests
;;; ============================================================

(test shared-axes-x-basic
  "axes-share-x links X limits."
  (let* ((fig (make-figure))
         (ax1 (add-subplot fig 1 2 1))
         (ax2 (add-subplot fig 1 2 2)))
    (axes-share-x ax1 ax2)
    (is (member ax2 (axes-base-sharex-group ax1)))
    (is (member ax1 (axes-base-sharex-group ax2)))))

(test shared-axes-x-propagation
  "Setting xlim on shared axes propagates."
  (let* ((fig (make-figure))
         (ax1 (add-subplot fig 1 2 1))
         (ax2 (add-subplot fig 1 2 2)))
    (axes-share-x ax1 ax2)
    (axes-set-xlim ax1 :min 0 :max 10)
    (multiple-value-bind (xmin xmax) (axes-get-xlim ax2)
      (is (approx= 0.0d0 xmin))
      (is (approx= 10.0d0 xmax)))))

(test shared-axes-y-propagation
  "Setting ylim on shared axes propagates."
  (let* ((fig (make-figure))
         (ax1 (add-subplot fig 1 2 1))
         (ax2 (add-subplot fig 1 2 2)))
    (axes-share-y ax1 ax2)
    (axes-set-ylim ax1 :min -5 :max 5)
    (multiple-value-bind (ymin ymax) (axes-get-ylim ax2)
      (is (approx= -5.0d0 ymin))
      (is (approx= 5.0d0 ymax)))))

(test shared-axes-no-circular-propagation
  "Shared axes don't cause infinite propagation."
  (let* ((fig (make-figure))
         (ax1 (add-subplot fig 1 2 1))
         (ax2 (add-subplot fig 1 2 2)))
    (axes-share-x ax1 ax2)
    ;; This should not hang
    (axes-set-xlim ax1 :min 1 :max 100)
    (axes-set-xlim ax2 :min 2 :max 200)
    (multiple-value-bind (xmin xmax) (axes-get-xlim ax1)
      (is (approx= 2.0d0 xmin))
      (is (approx= 200.0d0 xmax)))))

(test shared-axes-data-driven
  "Shared axes propagate when autoscaling from data."
  (let* ((fig (make-figure))
         (ax1 (add-subplot fig 1 2 1))
         (ax2 (add-subplot fig 1 2 2)))
    (axes-share-x ax1 ax2)
    ;; Plot on ax1 should update ax2's xlim
    (plot ax1 '(0 5 10) '(1 2 3))
    (multiple-value-bind (xmin xmax) (axes-get-xlim ax2)
      ;; Should be approximately 0 to 10 (with margins)
      (is (< xmin 1.0d0))
      (is (> xmax 9.0d0)))))

;;; ============================================================
;;; subplots tests
;;; ============================================================

(test subplots-basic
  "subplots creates NxM axes grid."
  (let* ((fig (make-figure))
         (result (subplots fig 2 2)))
    ;; 2x2 should return a 2D array
    (is (arrayp result))
    (is (= 2 (array-dimension result 0)))
    (is (= 2 (array-dimension result 1)))
    ;; Each element should be an axes
    (dotimes (i 2)
      (dotimes (j 2)
        (is (typep (aref result i j) 'mpl-axes))))))

(test subplots-1x1-squeeze
  "subplots 1x1 with squeeze returns single axes."
  (let* ((fig (make-figure))
         (result (subplots fig 1 1)))
    (is (typep result 'mpl-axes))))

(test subplots-1xn-squeeze
  "subplots 1xN with squeeze returns 1D array."
  (let* ((fig (make-figure))
         (result (subplots fig 1 3)))
    (is (arrayp result))
    (is (= 1 (array-rank result)))
    (is (= 3 (array-dimension result 0)))))

(test subplots-nx1-squeeze
  "subplots Nx1 with squeeze returns 1D array."
  (let* ((fig (make-figure))
         (result (subplots fig 3 1)))
    (is (arrayp result))
    (is (= 1 (array-rank result)))
    (is (= 3 (array-dimension result 0)))))

(test subplots-no-squeeze
  "subplots with squeeze=nil always returns 2D array."
  (let* ((fig (make-figure))
         (result (subplots fig 1 1 :squeeze nil)))
    (is (arrayp result))
    (is (= 2 (array-rank result)))
    (is (= 1 (array-dimension result 0)))
    (is (= 1 (array-dimension result 1)))))

(test subplots-adds-to-figure
  "subplots adds all axes to figure."
  (let* ((fig (make-figure))
         (_result (subplots fig 2 3)))
    (declare (ignore _result))
    (is (= 6 (length (figure-axes fig))))))

(test subplots-axes-positions-valid
  "All axes from subplots have valid positions."
  (let* ((fig (make-figure))
         (result (subplots fig 2 2)))
    (dotimes (i 2)
      (dotimes (j 2)
        (let ((pos (axes-base-position (aref result i j))))
          (is (= 4 (length pos)))
          (is (> (third pos) 0))    ; width > 0
          (is (> (fourth pos) 0)))))))  ; height > 0

(test subplots-sharex-all
  "subplots with sharex=:all links all X axes."
  (let* ((fig (make-figure))
         (result (subplots fig 2 2 :sharex :all)))
    ;; All axes should share X with (0,0)
    (is (member (aref result 0 1) (axes-base-sharex-group (aref result 0 0))))
    (is (member (aref result 1 0) (axes-base-sharex-group (aref result 0 0))))
    (is (member (aref result 1 1) (axes-base-sharex-group (aref result 0 0))))))

(test subplots-sharey-all
  "subplots with sharey=:all links all Y axes."
  (let* ((fig (make-figure))
         (result (subplots fig 2 2 :sharey :all)))
    ;; All axes should share Y with (0,0)
    (is (member (aref result 0 1) (axes-base-sharey-group (aref result 0 0))))))

(test subplots-sharex-row
  "subplots with sharex=:row links X axes within same row."
  (let* ((fig (make-figure))
         (result (subplots fig 2 2 :sharex :row)))
    ;; (0,0) and (0,1) should share X
    (is (member (aref result 0 1) (axes-base-sharex-group (aref result 0 0))))
    ;; (0,0) and (1,0) should NOT share X
    (is (not (member (aref result 1 0) (axes-base-sharex-group (aref result 0 0)))))))

(test subplots-sharey-col
  "subplots with sharey=:col links Y axes within same column."
  (let* ((fig (make-figure))
         (result (subplots fig 2 2 :sharey :col)))
    ;; (0,0) and (1,0) should share Y
    (is (member (aref result 1 0) (axes-base-sharey-group (aref result 0 0))))
    ;; (0,0) and (0,1) should NOT share Y
    (is (not (member (aref result 0 1) (axes-base-sharey-group (aref result 0 0)))))))

;;; ============================================================
;;; subplot-mosaic tests
;;; ============================================================

(test subplot-mosaic-basic
  "subplot-mosaic creates named axes."
  (let* ((fig (make-figure))
         (result (subplot-mosaic fig #("AB" "CD"))))
    (is (hash-table-p result))
    (is (= 4 (hash-table-count result)))
    (is (typep (gethash "A" result) 'mpl-axes))
    (is (typep (gethash "B" result) 'mpl-axes))
    (is (typep (gethash "C" result) 'mpl-axes))
    (is (typep (gethash "D" result) 'mpl-axes))))

(test subplot-mosaic-spanning
  "subplot-mosaic with spanning axes."
  (let* ((fig (make-figure))
         (result (subplot-mosaic fig #("AA" "BC"))))
    (is (= 3 (hash-table-count result)))
    ;; A should be wider than B or C (spans 2 columns)
    (let ((a-pos (axes-base-position (gethash "A" result)))
          (b-pos (axes-base-position (gethash "B" result))))
      (is (> (third a-pos) (* 1.5 (third b-pos)))))))

(test subplot-mosaic-adds-to-figure
  "subplot-mosaic adds axes to figure."
  (let* ((fig (make-figure))
         (_result (subplot-mosaic fig #("AB" "CD"))))
    (declare (ignore _result))
    (is (= 4 (length (figure-axes fig))))))

(test subplot-mosaic-dot-empty
  "subplot-mosaic treats '.' as empty space."
  (let* ((fig (make-figure))
         (result (subplot-mosaic fig #("A." ".B"))))
    (is (= 2 (hash-table-count result)))
    (is (typep (gethash "A" result) 'mpl-axes))
    (is (typep (gethash "B" result) 'mpl-axes))
    (is (null (gethash "." result)))))

(test subplot-mosaic-vertical-span
  "subplot-mosaic with vertically spanning axes."
  (let* ((fig (make-figure))
         (result (subplot-mosaic fig #("AB" "CB"))))
    (is (= 3 (hash-table-count result)))
    ;; B should be taller than A (spans 2 rows)
    (let ((b-pos (axes-base-position (gethash "B" result)))
          (a-pos (axes-base-position (gethash "A" result))))
      (is (> (fourth b-pos) (* 1.5 (fourth a-pos)))))))

;;; ============================================================
;;; Integration tests
;;; ============================================================

(test integration-subplots-and-plot
  "Plot data on multiple subplots."
  (let* ((fig (make-figure))
         (axes (subplots fig 2 2)))
    ;; Plot on each axes
    (plot (aref axes 0 0) '(1 2 3) '(1 4 9))
    (plot (aref axes 0 1) '(1 2 3) '(9 4 1))
    (plot (aref axes 1 0) '(1 2 3) '(2 3 4))
    (plot (aref axes 1 1) '(1 2 3) '(4 3 2))
    ;; Each axes should have one line
    (dotimes (i 2)
      (dotimes (j 2)
        (is (= 1 (length (cl-matplotlib.containers::axes-base-lines (aref axes i j)))))))))

(test integration-subplots-positions-non-overlapping
  "All subplot positions are non-overlapping."
  (let* ((fig (make-figure))
         (axes (subplots fig 2 3)))
    ;; Check no horizontal overlap between columns
    (dotimes (row 2)
      (dotimes (col 2)
        (let* ((ax1 (aref axes row col))
               (ax2 (aref axes row (1+ col)))
               (pos1 (axes-base-position ax1))
               (pos2 (axes-base-position ax2)))
          (is (<= (+ (first pos1) (third pos1))
                  (+ (first pos2) 0.01))))))
    ;; Check no vertical overlap between rows
    (dotimes (row 1)
      (dotimes (col 3)
        (let* ((ax1 (aref axes row col))
               (ax2 (aref axes (1+ row) col))
               (pos1 (axes-base-position ax1))
               (pos2 (axes-base-position ax2)))
          ;; Row 0 (top) should have higher bottom than row 1
          (is (>= (second pos1)
                  (+ (second pos2) (fourth pos2) -0.01))))))))

(test integration-savefig-with-subplots
  "Save figure with subplots to PNG."
  (let* ((fig (make-figure))
         (axes (subplots fig 2 2))
         (path "/tmp/cl-mpl-test-gridspec.png"))
    (plot (aref axes 0 0) '(1 2 3) '(1 4 9))
    (plot (aref axes 0 1) '(1 2 3) '(9 4 1))
    (plot (aref axes 1 0) '(1 2 3) '(2 3 4))
    (plot (aref axes 1 1) '(1 2 3) '(4 3 2))
    (savefig fig path)
    (is (probe-file path))
    ;; Check file is valid PNG (> 100 bytes)
    (when (probe-file path)
      (is (> (with-open-file (s path :element-type '(unsigned-byte 8))
               (file-length s))
             100)))))

;;; ============================================================
;;; Run function
;;; ============================================================

(defun run-gridspec-tests ()
  "Run all gridspec tests."
  (run! 'gridspec-suite))
