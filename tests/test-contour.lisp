;;;; test-contour.lisp — Tests for contour plotting and marching squares
;;;; Phase 5d — FiveAM test suite

(defpackage #:cl-matplotlib.tests.contour
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; Marching squares
                #:marching-squares-single-level #:marching-squares-levels
                #:marching-squares-filled
                #:auto-select-levels #:auto-select-levels-filled
                ;; ContourSet
                #:contour-set #:contourset-levels #:contourset-collections
                #:contourset-cmap #:contourset-norm #:contourset-filled-p
                #:contourset-linewidths #:contourset-linestyles
                #:contourset-colors #:contourset-label-texts
                #:contourset-get-paths
                ;; QuadContourSet
                #:quad-contour-set #:qcs-x #:qcs-y #:qcs-z
                ;; Plotting functions
                #:contour #:contourf #:clabel
                ;; Axes
                #:mpl-axes #:axes-base
                #:add-subplot
                ;; Figure
                #:mpl-figure #:make-figure #:savefig)
  (:export #:run-contour-tests))

(in-package #:cl-matplotlib.tests.contour)

(def-suite contour-suite :description "Contour and marching squares test suite")
(in-suite contour-suite)

;;; ============================================================
;;; Test helpers
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

;;; Helper: create a simple 2D Z field
(defun make-simple-z (nx ny &key (fn (lambda (x y) (+ x y))))
  "Create an NY x NX 2D array of Z values from FN(x,y).
X ranges [0, nx-1], Y ranges [0, ny-1]."
  (let ((z (make-array (list ny nx) :element-type 'double-float)))
    (dotimes (j ny)
      (dotimes (i nx)
        (setf (aref z j i) (float (funcall fn i j) 1.0d0))))
    z))

;;; Helper: create a Gaussian field
(defun make-gaussian-field (x-coords y-coords)
  "Create a 2D Gaussian field z = exp(-(x^2 + y^2))."
  (let* ((nx (length x-coords))
         (ny (length y-coords))
         (z (make-array (list ny nx) :element-type 'double-float)))
    (dotimes (j ny)
      (dotimes (i nx)
        (let ((xi (float (elt x-coords i) 1.0d0))
              (yi (float (elt y-coords j) 1.0d0)))
          (setf (aref z j i) (exp (- (+ (* xi xi) (* yi yi))))))))
    z))

;;; ============================================================
;;; Marching Squares — Cell Classification Tests
;;; ============================================================

(test ms-simple-no-contour-below
  "No contour when all values below level."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.0d0 0.0d0)
                                                    (0.0d0 0.0d0))))
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (null paths))))

(test ms-simple-no-contour-above
  "No contour when all values above level."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((1.0d0 1.0d0)
                                                    (1.0d0 1.0d0))))
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (null paths))))

(test ms-simple-horizontal-contour
  "Contour through middle when bottom low, top high."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.0d0 0.0d0)   ; bottom: below
                                                    (1.0d0 1.0d0)))) ; top: above
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (not (null paths)))
    (is (= 1 (length paths)))
    ;; Contour should cross at y=0.5
    (let* ((path (first paths))
           (p1 (first path))
           (p2 (second path)))
      (is (approx= 0.5d0 (second p1)))
      (is (approx= 0.5d0 (second p2))))))

(test ms-simple-vertical-contour
  "Contour through middle when left low, right high."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.0d0 1.0d0)
                                                    (0.0d0 1.0d0))))
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (not (null paths)))
    (is (= 1 (length paths)))
    ;; Contour should cross at x=0.5
    (let* ((path (first paths))
           (p1 (first path))
           (p2 (second path)))
      (is (approx= 0.5d0 (first p1)))
      (is (approx= 0.5d0 (first p2))))))

(test ms-diagonal-contour
  "Contour when one corner above, rest below."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.0d0 0.0d0)
                                                    (0.0d0 1.0d0)))) ; top-right above
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (not (null paths)))
    (is (= 1 (length paths)))))

(test ms-interpolation-accuracy
  "Linear interpolation places contour correctly."
  (let* ((x '(0.0d0 4.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.0d0 4.0d0)   ; bottom: 0→4
                                                    (0.0d0 4.0d0)))) ; top: 0→4
         (paths (marching-squares-single-level x y z 2.0d0)))
    (is (not (null paths)))
    ;; Contour at level=2 should be at x=2.0 (halfway between 0 and 4)
    (let* ((path (first paths))
           (p1 (first path)))
      (is (approx= 2.0d0 (first p1) 0.001d0)))))

;;; ============================================================
;;; Marching Squares — Multi-cell Grid Tests
;;; ============================================================

(test ms-larger-grid-contour
  "Contour extraction works on a larger grid."
  (let* ((x (loop for i from 0.0d0 to 4.0d0 collect i))
         (y (loop for i from 0.0d0 to 4.0d0 collect i))
         (z (make-simple-z 5 5 :fn (lambda (xi yi) (+ xi yi))))
         ;; Level 4: crosses diagonal
         (paths (marching-squares-single-level x y z 4.0d0)))
    (is (not (null paths)))
    ;; Should produce at least one path crossing the grid diagonally
    (is (>= (length paths) 1))))

(test ms-circle-contour
  "Contour of x^2 + y^2 produces closed curve."
  (let* ((x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-simple-z (length x) (length y)
                           :fn (lambda (xi yi)
                                 (let ((xv (elt x xi))
                                       (yv (elt y yi)))
                                   (+ (* xv xv) (* yv yv))))))
         (paths (marching-squares-single-level x y z 2.0d0)))
    (is (not (null paths)))
    ;; Should produce paths forming a circle-like curve
    (is (>= (reduce #'+ (mapcar #'length paths)) 4))))

(test ms-gaussian-contour
  "Contour of Gaussian produces connected paths."
  (let* ((x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (not (null paths)))
    ;; 0.5 level of Gaussian should give a closed contour
    (is (>= (length paths) 1))))

;;; ============================================================
;;; Marching Squares — Multi-level Tests
;;; ============================================================

(test ms-multi-level
  "Multi-level extraction produces one entry per level."
  (let* ((x (loop for i from 0.0d0 to 4.0d0 collect i))
         (y (loop for i from 0.0d0 to 4.0d0 collect i))
         (z (make-simple-z 5 5 :fn (lambda (xi yi) (+ xi yi))))
         (levels '(1.0d0 2.0d0 3.0d0 4.0d0 5.0d0 6.0d0))
         (result (marching-squares-levels x y z levels)))
    (is (= 6 (length result)))
    ;; Each result is (level . paths)
    (is (approx= 1.0d0 (car (first result))))
    (is (approx= 6.0d0 (car (sixth result))))
    ;; At least some levels should have paths
    (is (> (count-if (lambda (entry) (not (null (cdr entry)))) result) 0))))

;;; ============================================================
;;; Marching Squares — Filled Contour Tests
;;; ============================================================

(test ms-filled-basic
  "Filled contour produces polygons for band."
  (let* ((x (loop for i from 0.0d0 to 4.0d0 collect i))
         (y (loop for i from 0.0d0 to 4.0d0 collect i))
         (z (make-simple-z 5 5 :fn (lambda (xi yi)
                                     (float (+ xi yi) 1.0d0))))
         (polygons (marching-squares-filled x y z 2.0d0 4.0d0)))
    (is (not (null polygons)))
    ;; Each polygon should have at least 3 vertices
    (dolist (poly polygons)
      (is (>= (length poly) 3)))))

(test ms-filled-all-inside
  "Cell entirely within band produces quad polygon."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.5d0 0.5d0)
                                                    (0.5d0 0.5d0))))
         (polygons (marching-squares-filled x y z 0.0d0 1.0d0)))
    (is (not (null polygons)))
    ;; All corners in band → 4-vertex polygon
    (is (= 4 (length (first polygons))))))

(test ms-filled-none-inside
  "Cell entirely outside band produces no polygons."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((5.0d0 5.0d0)
                                                    (5.0d0 5.0d0))))
         (polygons (marching-squares-filled x y z 0.0d0 1.0d0)))
    (is (null polygons))))

;;; ============================================================
;;; Auto Level Selection Tests
;;; ============================================================

(test auto-levels-basic
  "Auto-select 7 levels between 0 and 1."
  (let ((levels (auto-select-levels 0.0d0 1.0d0 7)))
    (is (= 7 (length levels)))
    ;; Levels should be within (0, 1)
    (is (> (first levels) 0.0d0))
    (is (< (car (last levels)) 1.0d0))
    ;; Levels should be monotonically increasing
    (loop for i from 0 below (1- (length levels))
          do (is (< (elt levels i) (elt levels (1+ i)))))))

(test auto-levels-equal-range
  "Auto-select with equal zmin/zmax returns single value."
  (let ((levels (auto-select-levels 5.0d0 5.0d0)))
    (is (= 1 (length levels)))))

(test auto-levels-filled-basic
  "Auto-select filled levels produces N+1 boundaries."
  (let ((levels (auto-select-levels-filled 0.0d0 10.0d0 5)))
    (is (= 6 (length levels)))
    (is (approx= 0.0d0 (first levels)))
    (is (approx= 10.0d0 (car (last levels))))))

(test auto-levels-filled-equal
  "Auto-select filled with equal range."
  (let ((levels (auto-select-levels-filled 3.0d0 3.0d0)))
    (is (= 2 (length levels)))))

;;; ============================================================
;;; ContourSet Class Tests
;;; ============================================================

(test contour-set-creation
  "ContourSet can be created."
  (let ((cs (make-instance 'contour-set :levels '(1.0d0 2.0d0 3.0d0))))
    (is (typep cs 'contour-set))
    (is (typep cs 'mpl.rendering:artist))
    (is (= 3 (length (contourset-levels cs))))))

(test contour-set-is-artist
  "ContourSet inherits from artist."
  (let ((cs (make-instance 'contour-set)))
    (is (typep cs 'mpl.rendering:artist))
    (is (= 2 (mpl.rendering:artist-zorder cs)))))

(test contour-set-draw-empty
  "Drawing an empty ContourSet does not error."
  (let ((cs (make-instance 'contour-set))
        (renderer (mpl.rendering:make-mock-renderer)))
    (mpl.rendering:draw cs renderer)
    (pass)))

;;; ============================================================
;;; QuadContourSet Tests
;;; ============================================================

(test quad-contour-set-creation
  "QuadContourSet can be created with x, y, z."
  (let* ((x '(0.0d0 1.0d0 2.0d0))
         (y '(0.0d0 1.0d0 2.0d0))
         (z (make-simple-z 3 3 :fn (lambda (xi yi) (float (+ xi yi) 1.0d0)))))
    (let ((qcs (make-instance 'quad-contour-set
                              :x x :y y :z z
                              :filled nil)))
      (is (typep qcs 'quad-contour-set))
      (is (typep qcs 'contour-set))
      ;; Should have auto-selected levels
      (is (not (null (contourset-levels qcs)))))))

(test quad-contour-set-explicit-levels
  "QuadContourSet respects explicit levels."
  (let* ((x '(0.0d0 1.0d0 2.0d0))
         (y '(0.0d0 1.0d0 2.0d0))
         (z (make-simple-z 3 3 :fn (lambda (xi yi) (float (+ xi yi) 1.0d0))))
         (levels '(1.0d0 2.0d0 3.0d0)))
    (let ((qcs (make-instance 'quad-contour-set
                              :x x :y y :z z
                              :levels levels
                              :filled nil)))
      (is (= 3 (length (contourset-levels qcs))))
      (is (approx= 1.0d0 (first (contourset-levels qcs)))))))

(test quad-contour-set-has-collections
  "QuadContourSet creates collections for each level."
  (let* ((x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y)))
    (let ((qcs (make-instance 'quad-contour-set
                              :x x :y y :z z
                              :levels '(0.1d0 0.3d0 0.5d0 0.7d0 0.9d0)
                              :filled nil)))
      (is (= 5 (length (contourset-collections qcs))))
      ;; At least some collections should be non-nil
      (is (> (count-if #'identity (contourset-collections qcs)) 0)))))

(test quad-contour-set-filled
  "QuadContourSet with filled=t creates PolyCollections."
  (let* ((x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y)))
    (let ((qcs (make-instance 'quad-contour-set
                              :x x :y y :z z
                              :levels '(0.0d0 0.2d0 0.4d0 0.6d0 0.8d0 1.0d0)
                              :filled t)))
      ;; 6 levels → 5 bands → 5 collections
      (is (= 5 (length (contourset-collections qcs))))
      ;; Collections should be PolyCollections
      (dolist (coll (contourset-collections qcs))
        (when coll
          (is (typep coll 'mpl.rendering:poly-collection)))))))

;;; ============================================================
;;; Axes.contour Tests
;;; ============================================================

(test contour-on-axes
  "contour() creates a QuadContourSet and adds to axes."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z)))
    (is (typep cs 'quad-contour-set))
    (is (not (contourset-filled-p cs)))
    ;; Should have auto-selected levels
    (is (not (null (contourset-levels cs))))
    ;; Should have collections with LineCollections
    (let ((non-nil (remove-if #'null (contourset-collections cs))))
      (is (> (length non-nil) 0))
      (dolist (coll non-nil)
        (is (typep coll 'mpl.rendering:line-collection))))))

(test contour-explicit-levels
  "contour() with explicit levels."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z :levels '(0.1d0 0.3d0 0.5d0 0.7d0))))
    (is (= 4 (length (contourset-levels cs))))))

(test contour-with-colors
  "contour() with explicit colors."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z :levels '(0.3d0 0.5d0 0.7d0)
                                :colors '("red" "green" "blue"))))
    (is (equal '("red" "green" "blue") (contourset-colors cs)))))

(test contour-with-cmap
  "contour() with colormap."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z :cmap :viridis)))
    (is (not (null (contourset-cmap cs))))
    (is (not (null (contourset-norm cs))))))

;;; ============================================================
;;; Axes.contourf Tests
;;; ============================================================

(test contourf-on-axes
  "contourf() creates a filled QuadContourSet."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contourf ax x y z)))
    (is (typep cs 'quad-contour-set))
    (is (contourset-filled-p cs))
    ;; Collections should be PolyCollections
    (let ((non-nil (remove-if #'null (contourset-collections cs))))
      (is (> (length non-nil) 0))
      (dolist (coll non-nil)
        (is (typep coll 'mpl.rendering:poly-collection))))))

(test contourf-explicit-levels
  "contourf() with explicit levels."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contourf ax x y z :levels '(0.0d0 0.2d0 0.4d0 0.6d0 0.8d0 1.0d0))))
    (is (= 6 (length (contourset-levels cs))))
    (is (= 5 (length (contourset-collections cs))))))

(test contourf-with-cmap
  "contourf() with colormap."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contourf ax x y z :cmap :viridis)))
    (is (not (null (contourset-cmap cs))))))

(test contourf-with-alpha
  "contourf() with transparency."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contourf ax x y z :alpha 0.5)))
    ;; All collections should have alpha set
    (dolist (coll (contourset-collections cs))
      (when coll
        (is (approx= 0.5d0 (mpl.rendering:artist-alpha coll)))))))

;;; ============================================================
;;; Contour Label Tests
;;; ============================================================

(test clabel-basic
  "clabel() adds text labels to contour lines."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z :levels '(0.1d0 0.3d0 0.5d0 0.7d0)))
         (labels (clabel cs)))
    ;; Should have some labels (at least for levels with paths)
    (is (>= (length labels) 1))
    ;; Each label should be a text artist
    (dolist (lbl labels)
      (is (typep lbl 'mpl.rendering:text-artist)))))

(test clabel-fontsize
  "clabel() respects fontsize parameter."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z :levels '(0.3d0 0.5d0 0.7d0)))
         (labels (clabel cs :fontsize 14)))
    (dolist (lbl labels)
      (is (approx= 14.0d0 (mpl.rendering:text-fontsize lbl))))))

(test clabel-custom-format
  "clabel() with custom format string."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z :levels '(0.5d0)))
         (labels (clabel cs :fmt "~,1F")))
    (when labels
      ;; Label text should be formatted as "0.5"
      (is (string= "0.5" (mpl.rendering:text-text (first labels)))))))

;;; ============================================================
;;; Draw Tests with Mock Renderer
;;; ============================================================

(test contour-draw-mock
  "Contour can be drawn with mock renderer."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contour ax x y z))
         (renderer (mpl.rendering:make-mock-renderer)))
    (mpl.rendering:draw cs renderer)
    (pass)))

(test contourf-draw-mock
  "Contourf can be drawn with mock renderer."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (y (loop for i from -2.0d0 to 2.0d0 by 1.0d0 collect i))
         (z (make-gaussian-field x y))
         (cs (contourf ax x y z))
         (renderer (mpl.rendering:make-mock-renderer)))
    (mpl.rendering:draw cs renderer)
    (pass)))

;;; ============================================================
;;; Pipeline Tests — PNG Output
;;; ============================================================

(test pipeline-contour-to-png
  "Contour plot produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -3.0d0 to 3.0d0 by 0.2d0 collect i))
         (y (loop for i from -3.0d0 to 3.0d0 by 0.2d0 collect i))
         (z (make-gaussian-field x y))
         (path (tmp-path "contour-lines" "png")))
    (contour ax x y z :levels '(0.1d0 0.3d0 0.5d0 0.7d0 0.9d0)
                       :cmap :viridis)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-contourf-to-png
  "Filled contour plot produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -3.0d0 to 3.0d0 by 0.2d0 collect i))
         (y (loop for i from -3.0d0 to 3.0d0 by 0.2d0 collect i))
         (z (make-gaussian-field x y))
         (path (tmp-path "contourf-filled" "png")))
    (contourf ax x y z :cmap :viridis)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-contour-with-labels-to-png
  "Contour plot with labels produces valid PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (loop for i from -3.0d0 to 3.0d0 by 0.5d0 collect i))
         (y (loop for i from -3.0d0 to 3.0d0 by 0.5d0 collect i))
         (z (make-gaussian-field x y))
         (path (tmp-path "contour-labeled" "png")))
    (let ((cs (contour ax x y z :levels '(0.1d0 0.3d0 0.5d0 0.7d0))))
      (clabel cs :fontsize 10))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Edge Cases
;;; ============================================================

(test contour-single-level
  "Contour with single level works."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x '(0.0d0 1.0d0 2.0d0 3.0d0))
         (y '(0.0d0 1.0d0 2.0d0 3.0d0))
         (z (make-simple-z 4 4 :fn (lambda (xi yi) (float (+ xi yi) 1.0d0))))
         (cs (contour ax x y z :levels '(3.0d0))))
    (is (= 1 (length (contourset-levels cs))))))

(test contour-constant-field
  "Contour on constant field produces no paths."
  (let* ((x '(0.0d0 1.0d0 2.0d0))
         (y '(0.0d0 1.0d0 2.0d0))
         (z (make-array '(3 3) :element-type 'double-float
                                :initial-element 5.0d0))
         (paths (marching-squares-single-level x y z 3.0d0)))
    ;; All values are 5.0 > 3.0, so all cells are case 15 (all above)
    (is (null paths))))

(test contour-minimum-grid
  "Contour works on minimum 2x2 grid."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.0d0 1.0d0)
                                                    (1.0d0 0.0d0))))
         (cs (contour ax x y z :levels '(0.5d0))))
    (is (typep cs 'quad-contour-set))
    (is (= 1 (length (contourset-levels cs))))))

;;; ============================================================
;;; Saddle Point Tests
;;; ============================================================

(test ms-saddle-case-5
  "Marching squares handles saddle case 5 (BL+TR above)."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         ;; BL=1, BR=0, TR=1, TL=0 → case 5 (saddle)
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((1.0d0 0.0d0)   ; BL=1, BR=0
                                                    (0.0d0 1.0d0)))) ; TL=0, TR=1
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (not (null paths)))
    ;; Should produce two separate paths (one per segment pair)
    (is (>= (length paths) 1))))

(test ms-saddle-case-10
  "Marching squares handles saddle case 10 (BR+TL above)."
  (let* ((x '(0.0d0 1.0d0))
         (y '(0.0d0 1.0d0))
         ;; BL=0, BR=1, TR=0, TL=1 → case 10 (saddle)
         (z (make-array '(2 2) :element-type 'double-float
                                :initial-contents '((0.0d0 1.0d0)   ; BL=0, BR=1
                                                    (1.0d0 0.0d0)))) ; TL=1, TR=0
         (paths (marching-squares-single-level x y z 0.5d0)))
    (is (not (null paths)))
    (is (>= (length paths) 1))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-contour-tests ()
  "Run all contour tests and return success boolean."
  (let ((results (run 'contour-suite)))
    (explain! results)
    (results-status results)))
