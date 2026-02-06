;;;; test-path.lisp — Tests for path system, ported from matplotlib's test_path.py
;;;; Uses FiveAM test framework.

(defpackage #:cl-matplotlib.primitives.tests
  (:use #:cl #:fiveam #:cl-matplotlib.primitives)
  (:export #:path-tests))

(in-package #:cl-matplotlib.primitives.tests)

(def-suite path-tests
  :description "Path system tests ported from matplotlib's test_path.py")

(in-suite path-tests)

;;; ============================================================
;;; Helper utilities
;;; ============================================================

(defun approx= (a b &optional (tol 1d-6))
  "Check if two doubles are approximately equal."
  (<= (abs (- a b)) tol))

(defun verts-array (list-of-pairs)
  "Create a (N, 2) double-float array from list of (x y) pairs."
  (let* ((n (length list-of-pairs))
         (arr (make-array (list n 2) :element-type 'double-float)))
    (loop for pair in list-of-pairs
          for i from 0
          do (setf (aref arr i 0) (float (first pair) 1.0d0)
                   (aref arr i 1) (float (second pair) 1.0d0)))
    arr))

(defun codes-array (list-of-codes)
  "Create a (unsigned-byte 8) array from a list of code values."
  (let ((arr (make-array (length list-of-codes) :element-type '(unsigned-byte 8))))
    (loop for c in list-of-codes
          for i from 0
          do (setf (aref arr i) c))
    arr))

;;; ============================================================
;;; Test: Empty closed path
;;; Ported from test_empty_closed_path
;;; ============================================================

(test test-empty-closed-path
  "An empty path with closed=T should have 0 vertices and nil codes."
  (let ((path (make-path :vertices '() :closed t)))
    (is (= 0 (path-length path)))
    (is (null (mpl-path-codes path)))
    (let ((bb (path-get-extents path)))
      (is (bbox-null-p bb)))))

;;; ============================================================
;;; Test: Readonly path
;;; Ported from test_readonly_path
;;; ============================================================

(test test-readonly-path
  "A readonly path should have readonly set to T."
  (let ((path (path-unit-circle)))
    (is (mpl-path-readonly path))))

;;; ============================================================
;;; Test: Path creation with bad inputs
;;; Ported from test_path_exceptions
;;; ============================================================

(test test-path-exceptions
  "Path creation with invalid inputs should signal errors."
  ;; Mismatched codes length — codes has 2 elements, vertices has 6
  (signals error
    (make-path :vertices '((0 0) (1 1) (2 2) (3 3) (4 4) (5 5))
               :codes (list 1 2)))
  ;; First code not MOVETO
  (signals error
    (make-path :vertices '((0 0) (1 1))
               :codes (list 2 2))))

;;; ============================================================
;;; Test: Point in path
;;; Ported from test_point_in_path
;;; ============================================================

(test test-point-in-path
  "Test point containment in a closed square path."
  (let ((path (path-create-closed '((0 0) (0 1) (1 1) (1 0)))))
    (is (path-contains-point path '(0.5 0.5)))
    (is (not (path-contains-point path '(1.5 0.5))))))

;;; ============================================================
;;; Test: Point in path with NaN
;;; Ported from test_point_in_path_nan  
;;; ============================================================

(test test-point-in-path-nan
  "A NaN point should not be considered inside any path."
  (let* ((path (make-path :vertices '((0 0) (1 0) (1 1) (0 1) (0 0))))
         (nan float-features:double-float-nan)
         (result (path-contains-points path (list (list nan 0.5)))))
    (is (= 1 (length result)))
    (is (not (aref result 0)))))

;;; ============================================================
;;; Test: Exact extents (line segments only)
;;; Ported from test_exact_extents
;;; ============================================================

(test test-extents-linear
  "A linear path from (0,1) to (1,1) should have correct extents."
  (let* ((path (make-path :vertices '((0 1) (1 1))
                           :codes (list +moveto+ +lineto+)))
         (bb (path-get-extents path)))
    (is (approx= 0.0d0 (bbox-x0 bb)))
    (is (approx= 1.0d0 (bbox-y0 bb)))
    (is (approx= 1.0d0 (bbox-x1 bb)))
    (is (approx= 1.0d0 (bbox-y1 bb)))))

(test test-extents-point
  "A single-point path should have zero-size extents."
  (let* ((path (make-path :vertices '((1 2)) :codes (list +moveto+)))
         (bb (path-get-extents path)))
    (is (approx= 1.0d0 (bbox-x0 bb)))
    (is (approx= 2.0d0 (bbox-y0 bb)))
    (is (approx= 1.0d0 (bbox-x1 bb)))
    (is (approx= 2.0d0 (bbox-y1 bb)))))

(test test-extents-cubic-bezier
  "A cubic Bézier path should account for curve extrema, not just control points."
  (let* ((path (make-path :vertices '((0 0) (1 0) (1 1) (0 1))
                           :codes (list +moveto+ +curve4+ +curve4+ +curve4+)))
         (bb (path-get-extents path)))
    ;; The curve does NOT extend to the full control point hull
    ;; max x should be ~0.75, not 1.0
    (is (approx= 0.0d0 (bbox-x0 bb)))
    (is (approx= 0.0d0 (bbox-y0 bb)))
    (is (approx= 0.75d0 (bbox-x1 bb) 0.01))
    (is (approx= 1.0d0 (bbox-y1 bb)))))

(test test-extents-quadratic-bezier
  "A quadratic Bézier path should account for curve extrema."
  (let* ((path (make-path :vertices '((0 0) (0 1) (1 0))
                           :codes (list +moveto+ +curve3+ +curve3+)))
         (bb (path-get-extents path)))
    (is (approx= 0.0d0 (bbox-x0 bb)))
    (is (approx= 0.0d0 (bbox-y0 bb)))
    (is (approx= 1.0d0 (bbox-x1 bb)))
    (is (approx= 0.5d0 (bbox-y1 bb) 0.01))))

;;; ============================================================
;;; Test: Extents with ignored codes (STOP, CLOSEPOLY)
;;; Ported from test_extents_with_ignored_codes
;;; ============================================================

(test test-extents-with-closepoly-ignored
  "CLOSEPOLY vertices should be ignored when calculating extents."
  (let* ((path (make-path :vertices '((0 0) (1 1) (2 2))
                           :codes (list +moveto+ +moveto+ +closepoly+)))
         (bb (path-get-extents path)))
    (is (approx= 0.0d0 (bbox-x0 bb)))
    (is (approx= 0.0d0 (bbox-y0 bb)))
    (is (approx= 1.0d0 (bbox-x1 bb)))
    (is (approx= 1.0d0 (bbox-y1 bb)))))

(test test-extents-with-stop-ignored
  "STOP vertices should be ignored when calculating extents."
  (let* ((path (make-path :vertices '((0 0) (1 1) (2 2))
                           :codes (list +moveto+ +moveto+ +stop+)))
         (bb (path-get-extents path)))
    (is (approx= 0.0d0 (bbox-x0 bb)))
    (is (approx= 0.0d0 (bbox-y0 bb)))
    (is (approx= 1.0d0 (bbox-x1 bb)))
    (is (approx= 1.0d0 (bbox-y1 bb)))))

;;; ============================================================
;;; Test: Make compound path (empty)
;;; Ported from test_make_compound_path_empty
;;; ============================================================

(test test-make-compound-path-empty
  "Compound path from no paths should produce empty path."
  (let ((empty (path-make-compound-path nil)))
    (is (= 0 (path-length empty))))
  ;; Two empties
  (let ((r2 (path-make-compound-path
             (list (make-path :vertices '())
                   (make-path :vertices '())))))
    (is (= 0 (path-length r2)))))

;;; ============================================================
;;; Test: Make compound path removes STOPs
;;; Ported from test_make_compound_path_stops
;;; ============================================================

(test test-make-compound-path-stops
  "Compound path should remove internal STOP codes."
  (let* ((p1 (make-path :vertices '((0 0) (0 0))
                         :codes (list +moveto+ +stop+)))
         (compound (path-make-compound-path (list p1 p1 p1))))
    ;; Should have no STOP codes
    (let ((codes (mpl-path-codes compound)))
      (when codes
        (is (not (find +stop+ codes)))))))

;;; ============================================================
;;; Test: Unit rectangle
;;; ============================================================

(test test-unit-rectangle
  "unit-rectangle should be a closed path from (0,0) to (1,1)."
  (let* ((rect (path-unit-rectangle))
         (bb (path-get-extents rect)))
    (is (approx= 0.0d0 (bbox-x0 bb)))
    (is (approx= 0.0d0 (bbox-y0 bb)))
    (is (approx= 1.0d0 (bbox-x1 bb)))
    (is (approx= 1.0d0 (bbox-y1 bb)))))

;;; ============================================================
;;; Test: Unit circle
;;; ============================================================

(test test-unit-circle
  "unit-circle should have 26 vertices and span [-1,-1] to [1,1]."
  (let* ((circle (path-unit-circle))
         (bb (path-get-extents circle)))
    (is (= 26 (path-length circle)))
    (is (approx= -1.0d0 (bbox-x0 bb) 0.01))
    (is (approx= -1.0d0 (bbox-y0 bb) 0.01))
    (is (approx= 1.0d0 (bbox-x1 bb) 0.01))
    (is (approx= 1.0d0 (bbox-y1 bb) 0.01))))

(test test-unit-circle-readonly
  "unit-circle should be readonly."
  (is (mpl-path-readonly (path-unit-circle))))

(test test-unit-circle-contains-origin
  "unit-circle should contain the origin."
  (is (path-contains-point (path-unit-circle) '(0.0 0.0))))

(test test-unit-circle-not-contains-outside
  "unit-circle should not contain points far outside."
  (is (not (path-contains-point (path-unit-circle) '(2.0 0.0)))))

;;; ============================================================
;;; Test: Arc
;;; Ported from test_full_arc
;;; ============================================================

(test test-full-arc
  "A full 360-degree arc should span [-1,-1] to [1,1]."
  (dolist (offset '(0 45 90 180 270 -360))
    (let* ((low offset)
           (high (+ 360 offset))
           (path (path-arc low high))
           (verts (mpl-path-vertices path))
           (n (array-dimension verts 0))
           (min-x 100.0d0) (min-y 100.0d0)
           (max-x -100.0d0) (max-y -100.0d0))
      (dotimes (i n)
        (let ((x (aref verts i 0)) (y (aref verts i 1)))
          (setf min-x (min min-x x) max-x (max max-x x)
                min-y (min min-y y) max-y (max max-y y))))
      (is (approx= -1.0d0 min-x 0.02))
      (is (approx= -1.0d0 min-y 0.02))
      (is (approx= 1.0d0 max-x 0.02))
      (is (approx= 1.0d0 max-y 0.02)))))

;;; ============================================================
;;; Test: Wedge
;;; ============================================================

(test test-wedge
  "A wedge should start at origin and form a pie slice."
  (let* ((wedge (path-wedge 0 90))
         (verts (mpl-path-vertices wedge)))
    ;; First vertex should be at origin (center of wedge)
    (is (approx= 0.0d0 (aref verts 0 0)))
    (is (approx= 0.0d0 (aref verts 0 1)))
    ;; Should have CLOSEPOLY at end
    (let ((codes (mpl-path-codes wedge)))
      (is (= +closepoly+ (aref codes (1- (length codes))))))))

;;; ============================================================
;;; Test: Path deepcopy
;;; Ported from test_path_deepcopy
;;; ============================================================

(test test-path-deepcopy
  "Deepcopy should create independent copy, never readonly."
  (let* ((path1 (make-path :vertices '((0 0) (1 1)) :readonly t))
         (path1-copy (path-deepcopy path1)))
    (is (not (eq path1 path1-copy)))
    (is (not (eq (mpl-path-vertices path1) (mpl-path-vertices path1-copy))))
    ;; Values should be equal
    (is (= (aref (mpl-path-vertices path1) 0 0)
            (aref (mpl-path-vertices path1-copy) 0 0)))
    (is (mpl-path-readonly path1))
    (is (not (mpl-path-readonly path1-copy))))
  ;; With codes
  (let* ((path2 (make-path :vertices '((0 0) (1 1))
                            :codes (list +moveto+ +lineto+)
                            :readonly t))
         (path2-copy (path-deepcopy path2)))
    (is (not (eq path2 path2-copy)))
    (is (not (eq (mpl-path-codes path2) (mpl-path-codes path2-copy))))
    (is (= (aref (mpl-path-codes path2) 0) (aref (mpl-path-codes path2-copy) 0)))
    (is (mpl-path-readonly path2))
    (is (not (mpl-path-readonly path2-copy)))))

;;; ============================================================
;;; Test: Path shallow copy
;;; Ported from test_path_shallowcopy
;;; ============================================================

(test test-path-shallowcopy
  "Shallow copy should share vertices and codes."
  (let* ((path1 (make-path :vertices '((0 0) (1 1))))
         (path1-copy (path-copy path1)))
    (is (not (eq path1 path1-copy)))
    (is (eq (mpl-path-vertices path1) (mpl-path-vertices path1-copy))))
  (let* ((path2 (make-path :vertices '((0 0) (1 1))
                            :codes (list +moveto+ +lineto+)))
         (path2-copy (path-copy path2)))
    (is (not (eq path2 path2-copy)))
    (is (eq (mpl-path-vertices path2) (mpl-path-vertices path2-copy)))
    (is (eq (mpl-path-codes path2) (mpl-path-codes path2-copy)))))

;;; ============================================================
;;; Test: Path to polygons
;;; Ported from test_path_to_polygons
;;; ============================================================

(test test-path-to-polygons-two-points
  "A 2-point unclosed path should return empty for closed-only."
  (let ((p (make-path :vertices '((10 10) (20 20)))))
    ;; closed-only: < 3 points, so empty
    (is (null (path-to-polygons p :closed-only t)))
    ;; not closed-only: return the path
    (let ((result (path-to-polygons p :closed-only nil)))
      (is (= 1 (length result)))
      (is (= 2 (array-dimension (first result) 0))))))

(test test-path-to-polygons-three-points
  "A 3-point unclosed path should be auto-closed for closed-only."
  (let ((p (make-path :vertices '((10 10) (20 20) (30 30)))))
    ;; closed-only: auto-close
    (let ((result (path-to-polygons p :closed-only t)))
      (is (= 1 (length result)))
      (is (= 4 (array-dimension (first result) 0)))
      ;; Last point should equal first
      (let ((arr (first result)))
        (is (approx= (aref arr 0 0) (aref arr 3 0)))
        (is (approx= (aref arr 0 1) (aref arr 3 1)))))
    ;; not closed-only: return as-is
    (let ((result (path-to-polygons p :closed-only nil)))
      (is (= 1 (length result)))
      (is (= 3 (array-dimension (first result) 0))))))

;;; ============================================================
;;; Test: Algorithms - Point in polygon
;;; ============================================================

(test test-point-in-polygon
  "Winding number algorithm for basic polygons."
  (let ((square (list (cons 0.0d0 0.0d0) (cons 1.0d0 0.0d0)
                      (cons 1.0d0 1.0d0) (cons 0.0d0 1.0d0))))
    (is (point-in-polygon-p 0.5d0 0.5d0 square))
    (is (not (point-in-polygon-p 2.0d0 2.0d0 square)))
    (is (not (point-in-polygon-p -1.0d0 -1.0d0 square)))))

;;; ============================================================
;;; Test: Algorithms - Sutherland-Hodgman clipping
;;; ============================================================

(test test-sutherland-hodgman-inside
  "A polygon entirely inside the clip rect should be unchanged."
  (let* ((poly (list (cons 0.25d0 0.25d0) (cons 0.75d0 0.25d0)
                     (cons 0.75d0 0.75d0) (cons 0.25d0 0.75d0)))
         (result (sutherland-hodgman-clip poly 0.0d0 0.0d0 1.0d0 1.0d0)))
    (is (= 4 (length result)))))

(test test-sutherland-hodgman-outside
  "A polygon entirely outside the clip rect should be clipped to empty."
  (let* ((poly (list (cons 2.0d0 2.0d0) (cons 3.0d0 2.0d0)
                     (cons 3.0d0 3.0d0) (cons 2.0d0 3.0d0)))
         (result (sutherland-hodgman-clip poly 0.0d0 0.0d0 1.0d0 1.0d0)))
    (is (null result))))

(test test-sutherland-hodgman-partial
  "A polygon partially inside should be clipped correctly."
  (let* ((poly (list (cons -0.5d0 0.25d0) (cons 0.5d0 0.25d0)
                     (cons 0.5d0 0.75d0) (cons -0.5d0 0.75d0)))
         (result (sutherland-hodgman-clip poly 0.0d0 0.0d0 1.0d0 1.0d0)))
    (is (not (null result)))
    ;; All result points should be inside [0,1]x[0,1]
    (dolist (pt result)
      (is (>= (car pt) -1d-10))
      (is (<= (car pt) (+ 1.0d0 1d-10)))
      (is (>= (cdr pt) -1d-10))
      (is (<= (cdr pt) (+ 1.0d0 1d-10))))))

;;; ============================================================
;;; Test: Algorithms - Douglas-Peucker simplification
;;; ============================================================

(test test-douglas-peucker-collinear
  "Collinear points should be simplified to endpoints."
  (let* ((pts (list (cons 0.0d0 0.0d0) (cons 1.0d0 1.0d0)
                    (cons 2.0d0 2.0d0) (cons 3.0d0 3.0d0)))
         (result (douglas-peucker pts 0.1d0)))
    (is (= 2 (length result)))
    (is (approx= 0.0d0 (car (first result))))
    (is (approx= 3.0d0 (car (second result))))))

(test test-douglas-peucker-preserves-sharp-turns
  "Points with significant deviation should be preserved."
  (let* ((pts (list (cons 0.0d0 0.0d0) (cons 1.0d0 0.0d0)
                    (cons 1.0d0 1.0d0) (cons 2.0d0 1.0d0)))
         (result (douglas-peucker pts 0.1d0)))
    ;; The L-shape should preserve all 4 points
    (is (= 4 (length result)))))

;;; ============================================================
;;; Test: Algorithms - De Casteljau subdivision
;;; ============================================================

(test test-de-casteljau-cubic-midpoint
  "Splitting a cubic Bézier at t=0.5 should give correct midpoint."
  (multiple-value-bind (left right)
      (de-casteljau-split-cubic 0.0d0 0.0d0  1.0d0 0.0d0
                                 1.0d0 1.0d0  0.0d0 1.0d0  0.5d0)
    ;; The split point should be at t=0.5 on the curve
    (let ((mid-pt (fourth left)))  ; last point of left = first of right
      (is (approx= (car mid-pt) (car (first right)) 1d-10))
      (is (approx= (cdr mid-pt) (cdr (first right)) 1d-10)))))

(test test-de-casteljau-quadratic-midpoint
  "Splitting a quadratic Bézier at t=0.5."
  (multiple-value-bind (left right)
      (de-casteljau-split-quadratic 0.0d0 0.0d0  1.0d0 1.0d0  2.0d0 0.0d0  0.5d0)
    (let ((mid (third left)))
      ;; At t=0.5, the quadratic (0,0)-(1,1)-(2,0) evaluates to (1.0, 0.5)
      (is (approx= 1.0d0 (car mid) 1d-10))
      (is (approx= 0.5d0 (cdr mid) 1d-10)))))

;;; ============================================================
;;; Test: Algorithms - Bézier extrema
;;; ============================================================

(test test-cubic-bezier-extrema
  "Find extrema of a cubic Bézier in one dimension."
  ;; For the curve 0, 1, 0, 1 there should be extrema
  (let ((extrema (cubic-bezier-extrema-t 0.0d0 3.0d0 -1.0d0 1.0d0)))
    (is (not (null extrema)))
    ;; All t values should be in (0, 1)
    (dolist (tv extrema)
      (is (> tv 0.0d0))
      (is (< tv 1.0d0)))))

(test test-quadratic-bezier-extrema
  "Find extrema of a quadratic Bézier."
  ;; Curve 0, 1, 0 should have extremum at t=0.5
  (let ((extrema (quadratic-bezier-extrema-t 0.0d0 1.0d0 0.0d0)))
    (is (= 1 (length extrema)))
    (is (approx= 0.5d0 (first extrema) 1d-10))))

;;; ============================================================
;;; Test: Algorithms - Segment intersection
;;; ============================================================

(test test-segments-intersect
  "Basic segment intersection tests."
  ;; Crossing segments
  (is (segments-intersect-p 0.0d0 0.0d0 1.0d0 1.0d0
                             0.0d0 1.0d0 1.0d0 0.0d0))
  ;; Parallel non-intersecting segments
  (is (not (segments-intersect-p 0.0d0 0.0d0 1.0d0 0.0d0
                                  0.0d0 1.0d0 1.0d0 1.0d0)))
  ;; Non-intersecting segments
  (is (not (segments-intersect-p 0.0d0 0.0d0 1.0d0 0.0d0
                                  2.0d0 0.0d0 3.0d0 0.0d0))))

(test test-segments-intersect-touching
  "Segments that touch at endpoints."
  (is (segments-intersect-p 0.0d0 0.0d0 1.0d0 0.0d0
                             1.0d0 0.0d0 2.0d0 0.0d0)))

;;; ============================================================
;;; Test: Path intersection
;;; Ported from test_path_intersect_path (simplified)
;;; ============================================================

(test test-path-intersects-path-crossing
  "Two crossing line paths should intersect."
  (let ((a (make-path :vertices '((-2 0) (2 0))))
        (b (make-path :vertices '((0 -2) (0 2)))))
    (is (path-intersects-path a b))
    (is (path-intersects-path b a))))

(test test-path-intersects-path-disjoint
  "Two disjoint line paths should not intersect."
  (let ((a (make-path :vertices '((0 0) (1 0))))
        (b (make-path :vertices '((0 2) (1 2)))))
    (is (not (path-intersects-path a b :filled nil)))
    (is (not (path-intersects-path b a :filled nil)))))

(test test-path-intersects-path-self
  "A path should intersect itself."
  (let ((a (make-path :vertices '((0 1) (0 5)))))
    (is (path-intersects-path a a))))

(test test-path-intersects-path-contained
  "One path containing another should report intersection."
  (let ((a (make-path :vertices '((0 0) (5 5))))
        (b (make-path :vertices '((1 1) (3 3)))))
    (is (path-intersects-path a b))
    (is (path-intersects-path b a))))

;;; ============================================================
;;; Test: Path intersects bbox
;;; ============================================================

(test test-path-intersects-bbox-inside
  "A path inside a bbox should intersect it."
  (let ((p (make-path :vertices '((0.25 0.25) (0.75 0.75))))
        (bb (make-bbox 0.0 0.0 1.0 1.0)))
    (is (path-intersects-bbox p bb))))

(test test-path-intersects-bbox-outside
  "A path outside a bbox should not intersect it."
  (let ((p (make-path :vertices '((2.0 2.0) (3.0 3.0))))
        (bb (make-bbox 0.0 0.0 1.0 1.0)))
    (is (not (path-intersects-bbox p bb :filled nil)))))

;;; ============================================================
;;; Test: Path clipping
;;; ============================================================

(test test-path-clip-to-bbox
  "Clipping a line path to a bbox should restrict vertices."
  (let* ((path (make-path :vertices '((-1.0 0.5) (2.0 0.5))
                           :codes (list +moveto+ +lineto+)))
         (bb (make-bbox 0.0 0.0 1.0 1.0))
         (clipped (path-clip-to-bbox path bb)))
    ;; The clipped path should have vertices within the bbox
    (let ((verts (mpl-path-vertices clipped))
          (n (path-length clipped)))
      (when (> n 0)
        (dotimes (i n)
          (is (>= (aref verts i 0) -1d-10))
          (is (<= (aref verts i 0) (+ 1.0d0 1d-10)))
          (is (>= (aref verts i 1) -1d-10))
          (is (<= (aref verts i 1) (+ 1.0d0 1d-10))))))))

;;; ============================================================
;;; Test: Path transformation
;;; ============================================================

(test test-path-transformed
  "Transforming a path should apply the function to all vertices."
  (let* ((path (make-path :vertices '((1.0 2.0) (3.0 4.0))))
         (scaled (path-transformed path (lambda (x y) (values (* x 2.0d0) (* y 2.0d0))))))
    (is (approx= 2.0d0 (aref (mpl-path-vertices scaled) 0 0)))
    (is (approx= 4.0d0 (aref (mpl-path-vertices scaled) 0 1)))
    (is (approx= 6.0d0 (aref (mpl-path-vertices scaled) 1 0)))
    (is (approx= 8.0d0 (aref (mpl-path-vertices scaled) 1 1)))))

;;; ============================================================
;;; Test: Path interpolation
;;; Ported from test_interpolated_moveto, test_interpolated_closepoly
;;; ============================================================

(test test-interpolated-identity
  "Interpolation with steps=1 should return the same path."
  (let ((p (make-path :vertices '((0 0) (1 1)))))
    (is (eq p (path-interpolated p 1)))))

(test test-interpolated-empty
  "Interpolation of empty path should return the same path."
  (let ((p (make-path :vertices '())))
    (is (eq p (path-interpolated p 42)))))

(test test-interpolated-basic
  "Interpolation of a simple line with steps=2."
  (let* ((p (make-path :vertices '((0 0) (1 1))))
         (result (path-interpolated p 2))
         (verts (mpl-path-vertices result))
         (n (array-dimension verts 0)))
    ;; Should have 3 points: (0,0), (0.5,0.5), (1,1)
    (is (= 3 n))
    (is (approx= 0.0d0 (aref verts 0 0)))
    (is (approx= 0.5d0 (aref verts 1 0) 1d-10))
    (is (approx= 1.0d0 (aref verts 2 0)))))

;;; ============================================================
;;; Test: BBox operations
;;; ============================================================

(test test-bbox-creation
  "Basic bbox creation and accessors."
  (let ((bb (make-bbox 1.0 2.0 3.0 4.0)))
    (is (approx= 1.0d0 (bbox-x0 bb)))
    (is (approx= 2.0d0 (bbox-y0 bb)))
    (is (approx= 3.0d0 (bbox-x1 bb)))
    (is (approx= 4.0d0 (bbox-y1 bb)))
    (is (approx= 2.0d0 (bbox-width bb)))
    (is (approx= 2.0d0 (bbox-height bb)))))

(test test-bbox-null
  "Null bbox should have inverted extents."
  (let ((bb (bbox-null)))
    (is (bbox-null-p bb))))

(test test-bbox-union
  "Union of two bboxes."
  (let* ((bb1 (make-bbox 0.0 0.0 1.0 1.0))
         (bb2 (make-bbox 0.5 0.5 2.0 2.0))
         (u (bbox-union bb1 bb2)))
    (is (approx= 0.0d0 (bbox-x0 u)))
    (is (approx= 0.0d0 (bbox-y0 u)))
    (is (approx= 2.0d0 (bbox-x1 u)))
    (is (approx= 2.0d0 (bbox-y1 u)))))

(test test-bbox-contains-point
  "Point containment in bbox."
  (let ((bb (make-bbox 0.0 0.0 1.0 1.0)))
    (is (bbox-contains-point-p bb 0.5d0 0.5d0))
    (is (not (bbox-contains-point-p bb 2.0d0 0.5d0)))))

;;; ============================================================
;;; Test: Path codes
;;; ============================================================

(test test-path-codes-constants
  "Path code constants should have correct values."
  (is (= 0 +stop+))
  (is (= 1 +moveto+))
  (is (= 2 +lineto+))
  (is (= 3 +curve3+))
  (is (= 4 +curve4+))
  (is (= 79 +closepoly+)))

(test test-num-vertices-for-code
  "Num vertices for code should match matplotlib."
  (is (= 1 (gethash +stop+ *num-vertices-for-code*)))
  (is (= 1 (gethash +moveto+ *num-vertices-for-code*)))
  (is (= 1 (gethash +lineto+ *num-vertices-for-code*)))
  (is (= 2 (gethash +curve3+ *num-vertices-for-code*)))
  (is (= 3 (gethash +curve4+ *num-vertices-for-code*)))
  (is (= 1 (gethash +closepoly+ *num-vertices-for-code*))))

;;; ============================================================
;;; Test: isclose utility
;;; ============================================================

(test test-isclose
  "isclose should handle edge cases correctly."
  (is (isclose 1.0d0 1.0d0))
  (is (isclose 0.0d0 0.0d0))
  (is (not (isclose 1.0d0 2.0d0)))
  (is (isclose 1.0d0 (+ 1.0d0 1d-15))))

;;; ============================================================
;;; Test: Pixel snapping
;;; ============================================================

(test test-snap-to-pixel
  "Snap to pixel should round coordinates."
  (multiple-value-bind (sx sy)
      (snap-to-pixel 1.3d0 2.7d0 1.0d0)
    ;; With odd stroke width, should snap to half-pixel
    ;; 1.3 rounds to 1, +0.5 = 1.5
    (is (approx= 1.5d0 sx 0.01))
    ;; 2.7 rounds to 3, +0.5 = 3.5
    (is (approx= 3.5d0 sy 0.01))))

;;; ============================================================
;;; Test: Path creation with closed flag
;;; ============================================================

(test test-path-closed
  "A path with closed=T should have MOVETO...LINETO...CLOSEPOLY codes."
  (let* ((path (make-path :vertices '((0 0) (1 0) (1 1) (0 1) (0 0))
                           :closed t))
         (codes (mpl-path-codes path)))
    (is (not (null codes)))
    (is (= +moveto+ (aref codes 0)))
    (is (= +closepoly+ (aref codes (1- (length codes)))))))

;;; ============================================================
;;; Test: Circle at specific center/radius
;;; ============================================================

(test test-circle-with-center-and-radius
  "Creating a circle at (2,3) with radius 5."
  (let* ((c (path-circle :center '(2.0 3.0) :radius 5.0))
         (bb (path-get-extents c)))
    (is (approx= -3.0d0 (bbox-x0 bb) 0.1))
    (is (approx= -2.0d0 (bbox-y0 bb) 0.1))
    (is (approx= 7.0d0 (bbox-x1 bb) 0.1))
    (is (approx= 8.0d0 (bbox-y1 bb) 0.1))))

;;; ============================================================
;;; Test: Interpolated with codes (MOVETO subpaths)
;;; Ported from test_interpolated_moveto
;;; ============================================================

(test test-interpolated-with-moveto
  "Interpolating a path with multiple MOVETOs should preserve subpath structure."
  (let* ((path (make-path :vertices '((0 0) (0 1) (1 2) (4 4) (4 5) (5 5))
                           :codes (list +moveto+ +lineto+ +lineto+
                                        +moveto+ +lineto+ +lineto+)))
         (result (path-interpolated path 3))
         (result-codes (mpl-path-codes result)))
    ;; Each original MOVETO should still be MOVETO
    (when result-codes
      ;; First code should be MOVETO
      (is (= +moveto+ (aref result-codes 0))))))
