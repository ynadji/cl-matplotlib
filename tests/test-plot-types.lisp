;;;; test-plot-types.lisp — Tests for additional plot types
;;;; Phase 6b — hist, pie, errorbar, stem, step, stackplot, barh, boxplot
;;;; FiveAM test suite

(defpackage #:cl-matplotlib.tests.plot-types
  (:use #:cl #:fiveam)
   (:import-from #:cl-matplotlib.containers
                ;; AxesBase
                #:axes-base #:axes-base-lines #:axes-base-patches
                #:axes-base-artists #:axes-base-texts
                #:axes-update-datalim #:axes-autoscale-view
                ;; Axes
                #:mpl-axes
                ;; Figure
                #:mpl-figure #:make-figure #:add-subplot #:savefig
                ;; Plotting functions
                #:plot #:bar
                ;; New plot types
                #:hist #:pie #:errorbar #:stem #:axes-step
                #:stackplot #:barh #:boxplot
                #:violinplot #:gaussian-kde
                #:quiver)
   (:import-from #:cl-matplotlib.rendering
                 #:quiver-collection)
  (:export #:run-plot-types-tests))

(in-package #:cl-matplotlib.tests.plot-types)

(def-suite plot-types-suite :description "Additional plot types test suite")
(in-suite plot-types-suite)

;;; ============================================================
;;; Helpers
;;; ============================================================

(defun make-test-axes ()
  "Create a figure and axes for testing."
  (let* ((fig (make-figure :figsize '(8.0 6.0)))
         (ax (add-subplot fig 1 1 1)))
    (values ax fig)))

(defun tmp-path (name ext)
  "Create a temporary file path."
  (format nil "/tmp/cl-mpl-test-~A.~A" name ext))

(defun file-exists-and-valid-p (path &optional (min-size 100))
  "Check that PATH exists and is larger than MIN-SIZE bytes."
  (and (probe-file path)
       (> (with-open-file (s path :element-type '(unsigned-byte 8))
            (file-length s))
          min-size)))

;;; ============================================================
;;; Histogram tests
;;; ============================================================

(test hist-basic
  "Test basic histogram creation."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 2.5 3.0 3.5 4.0 5.0 5.5 6.0 7.0)))
      (multiple-value-bind (counts bin-edges patches)
          (hist ax data :bins 5)
        (is (= 5 (length counts)))
        (is (= 6 (length bin-edges)))
        (is (= 5 (length patches)))
        ;; Total count should match data length
        (is (= 10 (reduce #'+ counts)))
        ;; Bin edges should span data range
        (is (<= (first bin-edges) 1.0))
        (is (>= (car (last bin-edges)) 7.0))))))

(test hist-custom-bins
  "Test histogram with custom bin edges."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0)))
      (multiple-value-bind (counts bin-edges patches)
          (hist ax data :bins '(0.0 2.5 5.5))
        (is (= 2 (length counts)))
        (is (= 3 (length bin-edges)))
        (is (= 2 (length patches)))
        ;; 2 values in [0, 2.5), 3 values in [2.5, 5.5]
        (is (= 2 (first counts)))
        (is (= 3 (second counts)))))))

(test hist-density
  "Test density-normalized histogram."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0)))
      (multiple-value-bind (counts bin-edges patches)
          (hist ax data :bins 5 :density t)
        (declare (ignore counts))
        ;; Density: sum(patch_height * bin_width) should ≈ 1.0
        ;; Patches are Rectangles; height is the density value
        (let ((area 0.0d0))
          (loop for i from 0 below (length patches)
                for p in patches
                for h = (mpl.rendering:rectangle-height p)
                for w = (- (elt bin-edges (1+ i)) (elt bin-edges i))
                do (incf area (* h w)))
          (is (< (abs (- area 1.0d0)) 0.01d0)))))))

(test hist-cumulative
  "Test cumulative histogram."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0)))
      (multiple-value-bind (counts bin-edges patches)
          (hist ax data :bins 5 :cumulative t)
        (declare (ignore bin-edges patches))
        ;; Last count should equal total data length
        (is (= 5 (car (last counts))))
        ;; Counts should be non-decreasing
        (loop for i from 1 below (length counts)
              do (is (>= (elt counts i) (elt counts (1- i)))))))))

(test hist-step-type
  "Test step histogram type."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0)))
      (multiple-value-bind (counts bin-edges patches)
          (hist ax data :bins 5 :histtype :step)
        (declare (ignore bin-edges))
        (is (= 5 (length counts)))
        ;; Step type creates a Line2D instead of rectangles
        (is (= 1 (length patches)))
        (is (typep (first patches) 'mpl.rendering:line-2d))))))

(test hist-stepfilled-type
  "Test stepfilled histogram type."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0)))
      (multiple-value-bind (counts bin-edges patches)
          (hist ax data :bins 5 :histtype :stepfilled)
        (declare (ignore bin-edges))
        (is (= 5 (length counts)))
        ;; Stepfilled creates a Polygon
        (is (= 1 (length patches)))
        (is (typep (first patches) 'mpl.rendering:polygon))))))

(test hist-empty-data
  "Test histogram with single-value data."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(3.0 3.0 3.0)))
      (multiple-value-bind (counts bin-edges patches)
          (hist ax data :bins 5)
        (declare (ignore patches))
        ;; Should handle all-same-value data
        (is (= 5 (length counts)))
        (is (= 6 (length bin-edges)))
        ;; All data should be in one bin
        (is (= 3 (reduce #'+ counts)))))))

(test hist-savefig
  "Test histogram rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let* ((data (loop repeat 100 collect (+ 50.0 (* 15.0 (- (random 2.0) 1.0)))))
           (path (tmp-path "hist-basic" "png")))
      (hist ax data :bins 20 :color "skyblue" :edgecolor "black")
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Pie chart tests
;;; ============================================================

(test pie-basic
  "Test basic pie chart creation."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (multiple-value-bind (patches texts autotexts)
        (pie ax '(30 20 25 15 10))
      (is (= 5 (length patches)))
      ;; All patches should be wedges
      (dolist (p patches)
        (is (typep p 'mpl.rendering:wedge)))
      ;; No labels or autopct
      (is (null texts))
      (is (null autotexts)))))

(test pie-with-labels
  "Test pie chart with labels."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (multiple-value-bind (patches texts autotexts)
        (pie ax '(30 20 25) :labels '("A" "B" "C"))
      (declare (ignore autotexts))
      (is (= 3 (length patches)))
      (is (= 3 (length texts)))
      (dolist (txt texts)
        (is (typep txt 'mpl.rendering:text-artist))))))

(test pie-with-autopct
  "Test pie chart with percentage labels."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (multiple-value-bind (patches texts autotexts)
        (pie ax '(50 50) :autopct "~,1F%")
      (declare (ignore texts))
      (is (= 2 (length patches)))
      (is (= 2 (length autotexts)))
      (dolist (txt autotexts)
        (is (typep txt 'mpl.rendering:text-artist))))))

(test pie-with-colors
  "Test pie chart with custom colors."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (multiple-value-bind (patches texts autotexts)
        (pie ax '(30 20 25) :colors '("red" "green" "blue"))
      (declare (ignore texts autotexts))
      (is (= 3 (length patches)))
      (is (string= "red" (mpl.rendering:patch-facecolor (first patches))))
      (is (string= "green" (mpl.rendering:patch-facecolor (second patches))))
      (is (string= "blue" (mpl.rendering:patch-facecolor (third patches)))))))

(test pie-savefig
  "Test pie chart rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "pie-basic" "png")))
      (pie ax '(30 20 25 15 10) :labels '("A" "B" "C" "D" "E")
           :colors '("red" "blue" "green" "orange" "purple"))
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Error bar tests
;;; ============================================================

(test errorbar-basic-yerr
  "Test error bars with vertical errors."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0 4.0 5.0))
          (y '(2.0 4.0 3.0 5.0 4.5)))
      (multiple-value-bind (line err-lines caps)
          (errorbar ax x y :yerr 0.5)
        (is (typep line 'mpl.rendering:line-2d))
        (is (typep err-lines 'mpl.rendering:line-collection))
        (is-true caps)  ; caps should exist with default capsize
        ))))

(test errorbar-basic-xerr
  "Test error bars with horizontal errors."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0))
          (y '(2.0 4.0 3.0)))
      (multiple-value-bind (line err-lines caps)
          (errorbar ax x y :xerr 0.3)
        (is (typep line 'mpl.rendering:line-2d))
        (is (typep err-lines 'mpl.rendering:line-collection))
        (is-true caps)))))

(test errorbar-both
  "Test error bars with both x and y errors."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0))
          (y '(2.0 4.0 3.0)))
      (multiple-value-bind (line err-lines caps)
          (errorbar ax x y :yerr 0.5 :xerr 0.3)
        (is (typep line 'mpl.rendering:line-2d))
        (is (typep err-lines 'mpl.rendering:line-collection))
        (is-true caps)))))

(test errorbar-per-point-err
  "Test error bars with per-point error values."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0))
          (y '(2.0 4.0 3.0))
          (yerr '(0.2 0.5 0.3)))
      (multiple-value-bind (line err-lines caps)
          (errorbar ax x y :yerr yerr)
        (is (typep line 'mpl.rendering:line-2d))
        (is (typep err-lines 'mpl.rendering:line-collection))
        (is-true caps)))))

(test errorbar-savefig
  "Test error bar rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "errorbar-basic" "png"))
          (x '(1.0 2.0 3.0 4.0 5.0))
          (y '(2.0 4.0 3.0 5.0 4.5)))
      (errorbar ax x y :yerr 0.5 :color "red")
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Stem plot tests
;;; ============================================================

(test stem-basic
  "Test basic stem plot creation."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0 4.0 5.0))
          (y '(2.0 4.0 3.0 5.0 1.0)))
      (multiple-value-bind (markerline stemlines baseline)
          (stem ax x y)
        (is (typep markerline 'mpl.rendering:line-2d))
        (is (typep stemlines 'mpl.rendering:line-collection))
        (is (typep baseline 'mpl.rendering:line-2d))))))

(test stem-custom-bottom
  "Test stem plot with custom bottom."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0))
          (y '(5.0 6.0 7.0)))
      (multiple-value-bind (markerline stemlines baseline)
          (stem ax x y :bottom 2.0)
        (declare (ignore stemlines))
        (is (typep markerline 'mpl.rendering:line-2d))
        ;; Baseline should be at y=2
        (is (= 2.0d0 (elt (mpl.rendering:line-2d-ydata baseline) 0)))))))

(test stem-savefig
  "Test stem plot rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "stem-basic" "png"))
          (x '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0))
          (y '(2.0 4.0 1.0 5.0 3.0 6.0 2.0 4.0)))
      (stem ax x y)
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Step plot tests
;;; ============================================================

(test step-pre
  "Test step plot with :pre where."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0 4.0))
          (y '(1.0 3.0 2.0 4.0)))
      (let ((line (axes-step ax x y :where :pre)))
        (is (typep line 'mpl.rendering:line-2d))
        ;; Step :pre: n=4 → 1+2*(n-1) = 7 points
        (is (= 7 (length (mpl.rendering:line-2d-xdata line))))))))

(test step-post
  "Test step plot with :post where."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0 4.0))
          (y '(1.0 3.0 2.0 4.0)))
      (let ((line (axes-step ax x y :where :post)))
        (is (typep line 'mpl.rendering:line-2d))
        ;; Step :post: n=4 → 2*(n-1)+1 = 7 points
        (is (= 7 (length (mpl.rendering:line-2d-xdata line))))))))

(test step-mid
  "Test step plot with :mid where."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0 4.0))
          (y '(1.0 3.0 2.0 4.0)))
      (let ((line (axes-step ax x y :where :mid)))
        (is (typep line 'mpl.rendering:line-2d))
        ;; Step :mid: n=4 → first + 2*(n-1) pairs + last = 1+2*(n-1)+1 = 8 points
        (is (= 8 (length (mpl.rendering:line-2d-xdata line))))))))

(test step-savefig
  "Test step plot rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "step-basic" "png"))
          (x '(1.0 2.0 3.0 4.0 5.0))
          (y '(1.0 3.0 2.0 4.0 3.5)))
      (axes-step ax x y :where :pre :color "green")
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Stackplot tests
;;; ============================================================

(test stackplot-basic
  "Test basic stacked area plot."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0 4.0 5.0))
          (y1 '(1.0 2.0 3.0 2.0 1.0))
          (y2 '(2.0 1.0 2.0 3.0 2.0)))
      (let ((polys (stackplot ax x (list y1 y2))))
        (is (= 2 (length polys)))
        (dolist (p polys)
          (is (typep p 'mpl.rendering:polygon)))))))

(test stackplot-with-labels-colors
  "Test stackplot with labels and colors."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((x '(1.0 2.0 3.0))
          (y1 '(1.0 2.0 3.0))
          (y2 '(2.0 1.0 2.0))
          (y3 '(3.0 2.0 1.0)))
      (let ((polys (stackplot ax x (list y1 y2 y3)
                              :labels '("A" "B" "C")
                              :colors '("red" "green" "blue"))))
        (is (= 3 (length polys)))
        (is (string= "red" (mpl.rendering:patch-facecolor (first polys))))
        (is (string= "green" (mpl.rendering:patch-facecolor (second polys))))
        (is (string= "blue" (mpl.rendering:patch-facecolor (third polys))))))))

(test stackplot-savefig
  "Test stackplot rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "stackplot-basic" "png"))
          (x '(1.0 2.0 3.0 4.0 5.0))
          (y1 '(1.0 2.0 3.0 2.0 1.0))
          (y2 '(2.0 1.0 2.0 3.0 2.0))
          (y3 '(1.5 2.5 1.5 1.0 2.5)))
      (stackplot ax x (list y1 y2 y3)
                 :colors '("skyblue" "salmon" "lightgreen"))
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Barh (horizontal bar) tests
;;; ============================================================

(test barh-basic
  "Test basic horizontal bar chart."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((y '(1.0 2.0 3.0 4.0))
          (width '(10.0 20.0 15.0 25.0)))
      (let ((rects (barh ax y width)))
        (is (= 4 (length rects)))
        (dolist (r rects)
          (is (typep r 'mpl.rendering:rectangle)))))))

(test barh-custom-height-left
  "Test barh with custom height and left."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((y '(1.0 2.0 3.0))
          (width '(10.0 20.0 15.0)))
      (let ((rects (barh ax y width :height 0.5 :left 5)))
        (is (= 3 (length rects)))
        ;; Check that left offset is applied
        (is (= 5.0d0 (mpl.rendering:rectangle-x0 (first rects))))))))

(test barh-savefig
  "Test barh rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "barh-basic" "png"))
          (y '(1.0 2.0 3.0 4.0 5.0))
          (width '(10.0 20.0 15.0 25.0 18.0)))
      (barh ax y width :color "coral")
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Boxplot tests
;;; ============================================================

(test boxplot-basic
  "Test basic boxplot creation."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0)))
      (let ((result (boxplot ax (list data))))
        (is (= 1 (length (getf result :boxes))))
        (is (= 1 (length (getf result :medians))))
        (is (= 2 (length (getf result :whiskers))))
        (is (= 2 (length (getf result :caps))))))))

(test boxplot-multiple
  "Test boxplot with multiple datasets."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data1 '(1.0 2.0 3.0 4.0 5.0))
          (data2 '(3.0 4.0 5.0 6.0 7.0))
          (data3 '(2.0 5.0 8.0 3.0 6.0)))
      (let ((result (boxplot ax (list data1 data2 data3))))
        (is (= 3 (length (getf result :boxes))))
        (is (= 3 (length (getf result :medians))))
        (is (= 6 (length (getf result :whiskers))))
        (is (= 6 (length (getf result :caps))))))))

(test boxplot-with-outliers
  "Test boxplot detects outliers correctly."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    ;; Add outliers: 100 is way outside the IQR of 1-10
    (let ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 100.0)))
      (let ((result (boxplot ax (list data))))
        (is (= 1 (length (getf result :boxes))))
        ;; Should have outlier markers
        (is (plusp (length (getf result :fliers))))))))

(test boxplot-quartiles
  "Test that boxplot computes correct quartiles."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    ;; Simple data: 1-10, Q1=3.25, median=5.5, Q3=7.75
    (let ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0)))
      (let ((result (boxplot ax (list data))))
        ;; Box rect should span Q1 to Q3
        (let ((box (first (getf result :boxes))))
          (is (typep box 'mpl.rendering:rectangle))
          ;; y0 should be Q1 ≈ 3.25
          (is (< (abs (- (mpl.rendering:rectangle-y0 box) 3.25d0)) 0.01d0))
          ;; height should be IQR = Q3-Q1 ≈ 4.5
          (is (< (abs (- (mpl.rendering:rectangle-height box) 4.5d0)) 0.01d0)))))))

(test boxplot-horizontal
  "Test horizontal boxplot."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0)))
      (let ((result (boxplot ax (list data) :vert nil)))
        (is (= 1 (length (getf result :boxes))))
        ;; For horizontal box, x0 should be Q1
        (let ((box (first (getf result :boxes))))
          (is (< (abs (- (mpl.rendering:rectangle-x0 box) 3.25d0)) 0.01d0)))))))

(test boxplot-savefig
  "Test boxplot rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "boxplot-basic" "png"))
          (data1 (loop repeat 50 collect (+ 50.0 (* 10.0 (- (random 2.0) 1.0)))))
          (data2 (loop repeat 50 collect (+ 60.0 (* 15.0 (- (random 2.0) 1.0)))))
          (data3 (loop repeat 50 collect (+ 45.0 (* 8.0 (- (random 2.0) 1.0))))))
      (boxplot ax (list data1 data2 data3))
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Violin plot / KDE tests
;;; ============================================================

(test violinplot-kde-peak
  "Test KDE of N(0,1)-like data: peak density near 0.3989."
  ;; Use a deterministic set of 1000 samples approximating N(0,1)
  ;; via Box-Muller-style precomputed values won't work easily.
  ;; Instead: test with a known single-point dataset where the answer is exact.
  ;; For a single point at 0.0, bandwidth h = max(1e-3, n^(-1/5) * sigma)
  ;; sigma=0 so h=1e-3, density at 0 = 1/(1*h) * (1/sqrt(2*pi)) * exp(0)
  ;; = 1/(1e-3 * sqrt(2*pi)) = 1000/2.5066... ≈ 398.94
  ;; That's the single-point case. Let's test with a larger dataset instead.
  ;;
  ;; Use 100 samples drawn uniformly between -3 and 3, plus extra near 0
  ;; to simulate a bell shape. Better: just test the mathematical properties.
  ;;
  ;; Simplest reliable test: 1000 uniformly spaced points from N(0,1) CDF inverse
  ;; would be ideal but complex. Instead, test that KDE of symmetric data
  ;; has its peak near the center.
  (let* ((data (loop for i from 0 below 1000
                     collect (let* ((u (/ (+ i 0.5d0) 1000.0d0))
                                    ;; Approximate inverse normal CDF using rational approx
                                    ;; For u in (0,1), use Beasley-Springer-Moro algorithm
                                    (a (- u 0.5d0)))
                               ;; Simple approximation: use linear steps scaled by normal-ish shape
                               ;; Actually, let's use a simpler approach:
                               ;; Generate data as: x_i = tan(pi*(u_i - 0.5)) scaled
                               ;; No — just use a precomputed-style approach.
                               ;; Rational approximation of probit function:
                               (if (< (abs a) 0.42d0)
                                   ;; Central region
                                   (let* ((r (* a a))
                                          (p (* a (+ 2.50662823884d0
                                                    (* r (+ -18.61500062529d0
                                                            (* r (+ 41.39119773534d0
                                                                    (* r -25.44106049637d0)))))))))
                                     (/ p (+ 1.0d0
                                             (* r (+ -8.47351093090d0
                                                     (* r (+ 23.08336743743d0
                                                             (* r (+ -21.06224101826d0
                                                                     (* r 3.13082909833d0))))))))))
                                   ;; Tail region
                                   (let* ((r (if (> a 0.0d0) (- 1.0d0 u) u))
                                          (r2 (sqrt (- (log r))))
                                          (p (+ 0.3374754822726147d0
                                                (* r2 (+ 0.9761690190917186d0
                                                         (* r2 (+ 0.1607979714918209d0
                                                                   (* r2 (+ 0.0276438810333863d0
                                                                            (* r2 0.0038405729373609d0)))))))))
                                          (q (+ 1.0d0
                                                (* r2 (+ 0.7846733086024346d0
                                                         (* r2 (+ 0.2549732539343734d0
                                                                   (* r2 (+ 0.0421256838732559d0
                                                                            (* r2 0.0030276323105590d0))))))))))
                                     (if (< a 0.0d0) (- (/ p q)) (/ p q)))))))
         ;; Evaluate KDE at 0
         (kde-at-zero (first (gaussian-kde data '(0.0d0))))
         ;; Expected: peak density of N(0,1) is 1/sqrt(2*pi) ≈ 0.3989
         (expected 0.3989d0)
         (error-pct (abs (/ (- kde-at-zero expected) expected))))
    (is (< error-pct 0.05d0)
        "KDE peak at x=0 should be within 5% of 0.3989, got ~F (error ~,1F%)"
        kde-at-zero (* error-pct 100.0d0))))

(test violinplot-kde-empty
  "Test KDE with empty dataset doesn't crash."
  (let ((result (gaussian-kde '() '(0.0d0 1.0d0 2.0d0))))
    (is (= 3 (length result)))
    (is (every (lambda (v) (= v 0.0d0)) result))))

(test violinplot-kde-identical
  "Test KDE with all identical values doesn't crash."
  (let* ((data (make-list 100 :initial-element 5.0d0))
         (result (gaussian-kde data '(5.0d0))))
    (is (= 1 (length result)))
    ;; Should return a valid positive density
    (is (> (first result) 0.0d0))))

(test violinplot-basic
  "Test basic violinplot creation with 3 datasets."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data1 '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0))
          (data2 '(3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0 11.0 12.0))
          (data3 '(2.0 5.0 8.0 3.0 6.0 9.0 4.0 7.0 10.0 1.0)))
      (violinplot ax (list data1 data2 data3))
      ;; Should have 3 polygon patches (violin bodies)
      (is (>= (length (axes-base-patches ax)) 3))
      ;; Should have lines for medians and extrema
      (is (> (length (axes-base-lines ax)) 0)))))

(test violinplot-horizontal
  "Test horizontal violinplot."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0)))
      (violinplot ax (list data) :vert nil)
      ;; Should have at least 1 patch
      (is (>= (length (axes-base-patches ax)) 1)))))

(test violinplot-no-medians-extrema
  "Test violinplot with medians and extrema disabled."
  (multiple-value-bind (ax fig) (make-test-axes)
    (declare (ignore fig))
    (let ((data '(1.0 2.0 3.0 4.0 5.0)))
      (violinplot ax (list data) :showmedians nil :showextrema nil)
      ;; Should have 1 patch (the body) but no lines
      (is (= 1 (length (axes-base-patches ax))))
      (is (= 0 (length (axes-base-lines ax)))))))

(test violinplot-savefig
  "Test violinplot rendering to PNG."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "violinplot-basic" "png"))
          (data1 (loop repeat 50 collect (+ 50.0d0 (* 10.0d0 (- (random 2.0d0) 1.0d0)))))
          (data2 (loop repeat 50 collect (+ 60.0d0 (* 15.0d0 (- (random 2.0d0) 1.0d0)))))
          (data3 (loop repeat 50 collect (+ 45.0d0 (* 8.0d0 (- (random 2.0d0) 1.0d0))))))
      (violinplot ax (list data1 data2 data3))
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Quiver plot tests
;;; ============================================================

(test quiver-basic
  "Basic quiver renders without crash"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (u '((1.0d0 0.0d0) (1.0d0 0.0d0)))
         (v '((0.0d0 1.0d0) (0.0d0 1.0d0))))
    (quiver ax u v)
    (is (not (null (axes-base-artists ax))))))

(test quiver-with-positions
  "Quiver with explicit X Y positions"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (u '(1.0d0 0.0d0))
         (v '(0.0d0 1.0d0)))
    (quiver ax x y u v)
    (is (not (null (axes-base-artists ax))))))

(test quiver-zero-vectors
  "Quiver skips zero-length vectors without crash"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (u '(0.0d0 1.0d0 0.0d0))
         (v '(0.0d0 0.0d0 1.0d0)))
    (is-false (nth-value 1 (ignore-errors (quiver ax u v))))))

(test quiver-savefig
  "Quiver renders to PNG without error"
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (u '((1.0d0 0.0d0) (1.0d0 0.0d0)))
         (v '((0.0d0 0.0d0) (0.0d0 0.0d0)))
         (out "/tmp/test-quiver.png"))
    (quiver ax u v)
    (savefig fig out)
    (is (probe-file out))))

;;; ============================================================
;;; Integration tests
;;; ============================================================

(test combined-plot-types
  "Test multiple plot types on the same axes."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let ((path (tmp-path "combined-plot-types" "png"))
          (x '(1.0 2.0 3.0 4.0 5.0))
          (y '(2.0 4.0 3.0 5.0 4.5)))
      ;; Plot main line
      (plot ax x y :color "blue" :linewidth 2.0)
      ;; Add error bars
      (errorbar ax x y :yerr 0.5 :color "red")
      ;; Save
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

(test hist-evidence-png
  "Generate evidence PNG: histogram of random data with 30 bins."
  (multiple-value-bind (ax fig) (make-test-axes)
    (let* ((data (loop repeat 1000 collect (+ 50.0 (* 15.0 (- (random 2.0) 1.0)))))
           (path ".sisyphus/evidence/phase6b-hist.png"))
      ;; Ensure directory exists
      (ensure-directories-exist path)
      (hist ax data :bins 30 :color "skyblue" :edgecolor "black")
      (savefig fig path)
      (is-true (file-exists-and-valid-p path)))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-plot-types-tests ()
  "Run all plot types tests and report results."
  (let ((results (run 'plot-types-suite)))
    (explain! results)
    (unless (results-status results)
      (error "Plot types tests FAILED"))))
