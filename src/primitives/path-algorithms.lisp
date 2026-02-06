;;;; path-algorithms.lisp — Pure CL geometry algorithms for path operations
;;;; Ported from matplotlib's C++ _path.h implementations
;;;; No CFFI or C dependencies.

(in-package #:cl-matplotlib.primitives)

;;; ============================================================
;;; Constants
;;; ============================================================

(defconstant +isclose-rtol+ 1d-10
  "Relative tolerance for floating point comparison (matches matplotlib).")

(defconstant +isclose-atol+ 1d-13
  "Absolute tolerance for floating point comparison (matches matplotlib).")

;;; ============================================================
;;; Utility functions
;;; ============================================================

(declaim (inline isclose))
(defun isclose (a b)
  "Check if two doubles are close (matches matplotlib's _path.h isclose)."
  (declare (type double-float a b)
           (optimize (speed 3) (safety 1)))
  (<= (abs (- a b))
      (max (* +isclose-rtol+ (max (abs a) (abs b)))
           +isclose-atol+)))

(declaim (inline lerp))
(defun lerp (a b t-param)
  "Linear interpolation between A and B at parameter T-PARAM."
  (declare (type double-float a b t-param)
           (optimize (speed 3) (safety 1)))
  (+ a (* t-param (- b a))))

;;; ============================================================
;;; Point-in-path: Crossings Multiply algorithm
;;; Ported from _path.h point_in_path_impl
;;; ============================================================

(defun point-in-polygon-p (px py vertices)
  "Test if point (PX, PY) is inside a polygon defined by VERTICES.
VERTICES is a simple vector of (x . y) cons cells or a list of (x y) pairs.
Uses the crossings-multiply algorithm (ray casting along +X axis).
Returns T if inside, NIL if outside."
  (declare (type double-float px py)
           (optimize (speed 3) (safety 1)))
  (let ((n (length vertices))
        (inside nil))
    (when (< n 3)
      (return-from point-in-polygon-p nil))
    (let ((j (1- n)))
      (dotimes (i n)
        (let ((xi (car (elt vertices i)))
              (yi (cdr (elt vertices i)))
              (xj (car (elt vertices j)))
              (yj (cdr (elt vertices j))))
          (declare (type double-float xi yi xj yj))
          ;; Check if the test ray crosses this edge
          (when (not (eql (>= yi py) (>= yj py)))
            ;; Check if the crossing is to the right of the test point
            (when (eql (>= (- (* (- yj py) (- xi xj))
                             (* (- xj px) (- yi yj)))
                          0.0d0)
                       (>= yj py))
              (setf inside (not inside))))
          (setf j i))))
    inside))

(defun point-in-path-crossings (px py path-vertices path-codes)
  "Test if point (PX, PY) is inside a path defined by VERTICES and CODES.
Uses the crossings-multiply algorithm from matplotlib's _path.h.
PATH-VERTICES is a 2D array (N, 2) of double-float.
PATH-CODES is a 1D array of (unsigned-byte 8) or NIL.
Returns T if inside, NIL if outside."
  (declare (type double-float px py)
           (optimize (speed 3) (safety 1)))
  (let* ((n (array-dimension path-vertices 0))
         (subpath-flag 0))
    (declare (type fixnum n)
             (type (integer 0 1) subpath-flag))
    (when (< n 3) (return-from point-in-path-crossings nil))
    ;; Iterate through path segments, tracking crossings per subpath
    (let ((sx 0.0d0) (sy 0.0d0)    ; subpath start
          (vtx0 0.0d0) (vty0 0.0d0) ; previous vertex (edge start)
          (vtx1 0.0d0) (vty1 0.0d0) ; current vertex (edge end)
          (inside-flag 0)
          (i 0))
      (declare (type double-float sx sy vtx0 vty0 vtx1 vty1)
               (type fixnum i)
               (type (integer 0 1) inside-flag))
      (labels ((get-x (idx) (aref path-vertices idx 0))
               (get-y (idx) (aref path-vertices idx 1))
               (get-code (idx)
                 (if path-codes
                     (aref path-codes idx)
                     (if (zerop idx) +moveto+ +lineto+)))
               (process-edge ()
                 ;; Check crossing
                 (let ((yflag0 (if (>= vty0 py) 1 0))
                       (yflag1 (if (>= vty1 py) 1 0)))
                   (declare (type (integer 0 1) yflag0 yflag1))
                   (when (/= yflag0 yflag1)
                     (when (eql (>= (- (* (- vty1 py) (- vtx0 vtx1))
                                      (* (- vtx1 px) (- vty0 vty1)))
                                   0.0d0)
                                (= yflag1 1))
                       (setf subpath-flag (logxor subpath-flag 1)))))))
        (loop while (< i n) do
          (let ((code (get-code i)))
            (cond
              ((= code +moveto+)
               ;; Close previous subpath if any
               (when (> i 0)
                 ;; Close to subpath start
                 (setf vtx0 vtx1 vty0 vty1)
                 (setf vtx1 sx vty1 sy)
                 (process-edge)
                 (setf inside-flag (logior inside-flag subpath-flag))
                 (setf subpath-flag 0))
               ;; Start new subpath
               (setf sx (get-x i) sy (get-y i))
               (setf vtx0 sx vty0 sy)
               (setf vtx1 sx vty1 sy))
              ((= code +lineto+)
               (setf vtx0 vtx1 vty0 vty1)
               (setf vtx1 (get-x i) vty1 (get-y i))
               (process-edge))
              ((= code +closepoly+)
               ;; Close to subpath start
               (setf vtx0 vtx1 vty0 vty1)
               (setf vtx1 sx vty1 sy)
               (process-edge)
               (setf inside-flag (logior inside-flag subpath-flag))
               (setf subpath-flag 0))
              ((= code +curve3+)
               ;; Approximate quadratic bezier as line segments
               (when (< (1+ i) n)
                 (let ((cx (get-x i)) (cy (get-y i))
                       (ex (get-x (1+ i))) (ey (get-y (1+ i))))
                   (declare (type double-float cx cy ex ey))
                   ;; Subdivide into 4 line segments
                   (dotimes (s 4)
                     (let* ((t1 (/ (float (1+ s) 1.0d0) 4.0d0))
                            (t0 (- 1.0d0 t1))
                            (qx (+ (* t0 t0 vtx1) (* 2.0d0 t0 t1 cx) (* t1 t1 ex)))
                            (qy (+ (* t0 t0 vty1) (* 2.0d0 t0 t1 cy) (* t1 t1 ey))))
                       (setf vtx0 vtx1 vty0 vty1)
                       (setf vtx1 qx vty1 qy)
                       (process-edge)))
                   (incf i)))) ; skip extra vertex
              ((= code +curve4+)
               ;; Approximate cubic bezier as line segments
               (when (< (+ i 2) n)
                 (let ((c1x (get-x i)) (c1y (get-y i))
                       (c2x (get-x (1+ i))) (c2y (get-y (1+ i)))
                       (ex (get-x (+ i 2))) (ey (get-y (+ i 2))))
                   (declare (type double-float c1x c1y c2x c2y ex ey))
                   ;; Subdivide into 8 line segments
                   (dotimes (s 8)
                     (let* ((t1 (/ (float (1+ s) 1.0d0) 8.0d0))
                            (t0 (- 1.0d0 t1))
                            (cx (+ (* t0 t0 t0 vtx1)
                                   (* 3.0d0 t0 t0 t1 c1x)
                                   (* 3.0d0 t0 t1 t1 c2x)
                                   (* t1 t1 t1 ex)))
                            (cy (+ (* t0 t0 t0 vty1)
                                   (* 3.0d0 t0 t0 t1 c1y)
                                   (* 3.0d0 t0 t1 t1 c2y)
                                   (* t1 t1 t1 ey))))
                       (setf vtx0 vtx1 vty0 vty1)
                       (setf vtx1 cx vty1 cy)
                       (process-edge)))
                   (incf i 2)))) ; skip extra vertices
              (t nil))) ; ignore STOP and unknown
          (incf i))
        ;; Close final subpath
        (setf vtx0 vtx1 vty0 vty1)
        (setf vtx1 sx vty1 sy)
        (process-edge)
        (setf inside-flag (logior inside-flag subpath-flag))
        (/= inside-flag 0)))))

;;; ============================================================
;;; Sutherland-Hodgman polygon clipping
;;; Ported from _path.h clip_path_to_rect
;;; ============================================================

(defun %clip-one-step (polygon is-inside-fn bisect-fn)
  "One step of Sutherland-Hodgman: clip POLYGON against one edge.
IS-INSIDE-FN: (point) -> bool, checks if point is inside the edge.
BISECT-FN: (s p) -> point, computes intersection with edge.
Points are (x . y) cons cells."
  (when (null polygon)
    (return-from %clip-one-step nil))
  (let ((result '())
        (s (car (last polygon))))
    (dolist (p polygon)
      (let ((s-inside (funcall is-inside-fn s))
            (p-inside (funcall is-inside-fn p)))
        ;; If endpoints straddle the edge, add intersection
        (when (not (eql s-inside p-inside))
          (push (funcall bisect-fn s p) result))
        ;; If p is inside, add it
        (when p-inside
          (push p result)))
      (setf s p))
    (nreverse result)))

(defun %bisect-x (edge-x s p)
  "Compute intersection of segment S-P with vertical line at EDGE-X."
  (declare (type double-float edge-x))
  (let* ((sx (car s)) (sy (cdr s))
         (px (car p)) (py (cdr p))
         (dx (- px sx))
         (dy (- py sy)))
    (declare (type double-float sx sy px py dx dy))
    (cons edge-x
          (+ sy (* dy (/ (- edge-x sx) dx))))))

(defun %bisect-y (edge-y s p)
  "Compute intersection of segment S-P with horizontal line at EDGE-Y."
  (declare (type double-float edge-y))
  (let* ((sx (car s)) (sy (cdr s))
         (px (car p)) (py (cdr p))
         (dx (- px sx))
         (dy (- py sy)))
    (declare (type double-float sx sy px py dx dy))
    (cons (+ sx (* dx (/ (- edge-y sy) dy)))
          edge-y)))

(defun sutherland-hodgman-clip (polygon xmin ymin xmax ymax)
  "Clip a polygon to the rectangle (XMIN, YMIN)-(XMAX, YMAX).
POLYGON is a list of (x . y) cons cells.
Returns a list of (x . y) cons cells, or NIL if completely clipped."
  (declare (type double-float xmin ymin xmax ymax))
  (let ((result polygon))
    ;; Clip against right edge (x <= xmax)
    (setf result
          (%clip-one-step result
                          (lambda (pt) (<= (the double-float (car pt)) xmax))
                          (lambda (s p) (%bisect-x xmax s p))))
    ;; Clip against left edge (x >= xmin)
    (setf result
          (%clip-one-step result
                          (lambda (pt) (>= (the double-float (car pt)) xmin))
                          (lambda (s p) (%bisect-x xmin s p))))
    ;; Clip against top edge (y <= ymax)
    (setf result
          (%clip-one-step result
                          (lambda (pt) (<= (the double-float (cdr pt)) ymax))
                          (lambda (s p) (%bisect-y ymax s p))))
    ;; Clip against bottom edge (y >= ymin)
    (setf result
          (%clip-one-step result
                          (lambda (pt) (>= (the double-float (cdr pt)) ymin))
                          (lambda (s p) (%bisect-y ymin s p))))
    result))

;;; ============================================================
;;; Douglas-Peucker path simplification
;;; ============================================================

(defun %perpendicular-distance (px py x1 y1 x2 y2)
  "Perpendicular distance from point (PX,PY) to line segment (X1,Y1)-(X2,Y2)."
  (declare (type double-float px py x1 y1 x2 y2)
           (optimize (speed 3) (safety 1)))
  (let ((dx (- x2 x1))
        (dy (- y2 y1)))
    (declare (type double-float dx dy))
    (if (and (zerop dx) (zerop dy))
        ;; Degenerate: segment is a point
        (sqrt (+ (* (- px x1) (- px x1)) (* (- py y1) (- py y1))))
        ;; Normal case: distance from point to line
        (/ (abs (- (* dy px) (* dx py) (* x2 y1) (- (* x1 y2))))
           (sqrt (+ (* dx dx) (* dy dy)))))))

(defun douglas-peucker (points tolerance)
  "Simplify a polyline using Douglas-Peucker algorithm.
POINTS is a list of (x . y) cons cells.
TOLERANCE is the maximum perpendicular distance threshold.
Returns a simplified list of (x . y) cons cells."
  (declare (type double-float tolerance))
  (when (<= (length points) 2)
    (return-from douglas-peucker points))
  (let* ((pts (coerce points 'vector))
         (n (length pts))
         (keep (make-array n :element-type 'bit :initial-element 0)))
    ;; Always keep first and last
    (setf (aref keep 0) 1
          (aref keep (1- n)) 1)
    ;; Recursive simplification
    (labels ((simplify (start end)
               (when (> (- end start) 1)
                 (let ((max-dist 0.0d0)
                       (max-idx start)
                       (x1 (car (aref pts start)))
                       (y1 (cdr (aref pts start)))
                       (x2 (car (aref pts end)))
                       (y2 (cdr (aref pts end))))
                   (declare (type double-float max-dist x1 y1 x2 y2)
                            (type fixnum max-idx))
                   ;; Find point with maximum distance
                   (loop for i from (1+ start) below end do
                     (let ((d (%perpendicular-distance
                               (car (aref pts i)) (cdr (aref pts i))
                               x1 y1 x2 y2)))
                       (declare (type double-float d))
                       (when (> d max-dist)
                         (setf max-dist d max-idx i))))
                   ;; If max distance exceeds tolerance, keep the point and recurse
                   (when (> max-dist tolerance)
                     (setf (aref keep max-idx) 1)
                     (simplify start max-idx)
                     (simplify max-idx end))))))
      (simplify 0 (1- n)))
    ;; Collect kept points
    (loop for i below n
          when (= (aref keep i) 1)
          collect (aref pts i))))

;;; ============================================================
;;; De Casteljau Bézier curve subdivision
;;; ============================================================

(defun de-casteljau-split-cubic (x0 y0 x1 y1 x2 y2 x3 y3 t-param)
  "Split a cubic Bézier curve at parameter T-PARAM using De Casteljau's algorithm.
Returns two curves as values: (left-points right-points).
Each is a list of 4 (x . y) control points."
  (declare (type double-float x0 y0 x1 y1 x2 y2 x3 y3 t-param)
           (optimize (speed 3) (safety 1)))
  (let* ((s (- 1.0d0 t-param))
         ;; First level
         (ax (* s x0))  (ay (* s y0))
         (bx (* t-param x1)) (by (* t-param y1))
         (p01x (+ ax bx)) (p01y (+ ay by))

         (ax2 (* s x1))  (ay2 (* s y1))
         (bx2 (* t-param x2)) (by2 (* t-param y2))
         (p12x (+ ax2 bx2)) (p12y (+ ay2 by2))

         (ax3 (* s x2))  (ay3 (* s y2))
         (bx3 (* t-param x3)) (by3 (* t-param y3))
         (p23x (+ ax3 bx3)) (p23y (+ ay3 by3))

         ;; Second level
         (p012x (+ (* s p01x) (* t-param p12x)))
         (p012y (+ (* s p01y) (* t-param p12y)))
         (p123x (+ (* s p12x) (* t-param p23x)))
         (p123y (+ (* s p12y) (* t-param p23y)))

         ;; Third level — the point on the curve
         (p0123x (+ (* s p012x) (* t-param p123x)))
         (p0123y (+ (* s p012y) (* t-param p123y))))
    (values
     ;; Left half: p0, p01, p012, p0123
     (list (cons x0 y0) (cons p01x p01y) (cons p012x p012y) (cons p0123x p0123y))
     ;; Right half: p0123, p123, p23, p3
     (list (cons p0123x p0123y) (cons p123x p123y) (cons p23x p23y) (cons x3 y3)))))

(defun de-casteljau-split-quadratic (x0 y0 x1 y1 x2 y2 t-param)
  "Split a quadratic Bézier curve at parameter T-PARAM using De Casteljau.
Returns two curves as values: (left-points right-points).
Each is a list of 3 (x . y) control points."
  (declare (type double-float x0 y0 x1 y1 x2 y2 t-param)
           (optimize (speed 3) (safety 1)))
  (let* ((s (- 1.0d0 t-param))
         ;; First level
         (p01x (+ (* s x0) (* t-param x1)))
         (p01y (+ (* s y0) (* t-param y1)))
         (p12x (+ (* s x1) (* t-param x2)))
         (p12y (+ (* s y1) (* t-param y2)))
         ;; Second level — point on curve
         (p012x (+ (* s p01x) (* t-param p12x)))
         (p012y (+ (* s p01y) (* t-param p12y))))
    (values
     (list (cons x0 y0) (cons p01x p01y) (cons p012x p012y))
     (list (cons p012x p012y) (cons p12x p12y) (cons x2 y2)))))

;;; ============================================================
;;; Bézier curve extrema calculation for bounds
;;; ============================================================

(defun cubic-bezier-extrema-t (p0 p1 p2 p3)
  "Find parameter values where a 1D cubic Bézier has zero derivative.
Returns a list of t values in (0, 1)."
  (declare (type double-float p0 p1 p2 p3)
           (optimize (speed 3) (safety 1)))
  ;; Derivative: 3(1-t)²(p1-p0) + 6(1-t)t(p2-p1) + 3t²(p3-p2)
  ;; = at² + bt + c where:
  (let* ((a (+ (- p3 p2) (- p1 p0) (* -2.0d0 (- p2 p1))))  ; simplification
         (c (* 3.0d0 a))  ; 3(p3 - 3p2 + 3p1 - p0) ... let's do it properly
         ;; f'(t) = 3[(1-t)²(p1-p0) + 2(1-t)t(p2-p1) + t²(p3-p2)]
         ;; Expanding: 3[(-p0+3p1-3p2+p3)t² + 2(p0-2p1+p2)t + (p1-p0)]
         (a-coeff (* 3.0d0 (+ (- p0) (* 3.0d0 p1) (* -3.0d0 p2) p3)))
         (b-coeff (* 6.0d0 (+ p0 (* -2.0d0 p1) p2)))
         (c-coeff (* 3.0d0 (- p1 p0)))
         (result '()))
    (declare (ignore a c))
    (if (isclose a-coeff 0.0d0)
        ;; Linear case
        (unless (isclose b-coeff 0.0d0)
          (let ((t-val (/ (- c-coeff) b-coeff)))
            (when (and (> t-val 0.0d0) (< t-val 1.0d0))
              (push t-val result))))
        ;; Quadratic case
        (let ((discriminant (- (* b-coeff b-coeff) (* 4.0d0 a-coeff c-coeff))))
          (when (>= discriminant 0.0d0)
            (let ((sqrt-d (sqrt discriminant))
                  (denom (* 2.0d0 a-coeff)))
              (let ((t1 (/ (+ (- b-coeff) sqrt-d) denom))
                    (t2 (/ (- (- b-coeff) sqrt-d) denom)))
                (when (and (> t1 0.0d0) (< t1 1.0d0))
                  (push t1 result))
                (when (and (> t2 0.0d0) (< t2 1.0d0)
                           (not (isclose t1 t2)))
                  (push t2 result)))))))
    result))

(defun quadratic-bezier-extrema-t (p0 p1 p2)
  "Find parameter values where a 1D quadratic Bézier has zero derivative.
Returns a list of t values in (0, 1)."
  (declare (type double-float p0 p1 p2)
           (optimize (speed 3) (safety 1)))
  ;; Derivative: 2(1-t)(p1-p0) + 2t(p2-p1) = 0
  ;; => 2[(p0-2p1+p2)t + (p1-p0)] = 0
  (let ((denom (+ p0 (* -2.0d0 p1) p2)))
    (if (isclose denom 0.0d0)
        '()
        (let ((t-val (/ (- p0 p1) denom)))
          (if (and (> t-val 0.0d0) (< t-val 1.0d0))
              (list t-val)
              '())))))

(defun cubic-bezier-point-at (t-param x0 y0 x1 y1 x2 y2 x3 y3)
  "Evaluate a cubic Bézier at parameter T-PARAM. Returns (values x y)."
  (declare (type double-float t-param x0 y0 x1 y1 x2 y2 x3 y3)
           (optimize (speed 3) (safety 1)))
  (let* ((s (- 1.0d0 t-param))
         (s2 (* s s))
         (s3 (* s2 s))
         (t2 (* t-param t-param))
         (t3 (* t2 t-param)))
    (values
     (+ (* s3 x0) (* 3.0d0 s2 t-param x1) (* 3.0d0 s t2 x2) (* t3 x3))
     (+ (* s3 y0) (* 3.0d0 s2 t-param y1) (* 3.0d0 s t2 y2) (* t3 y3)))))

(defun quadratic-bezier-point-at (t-param x0 y0 x1 y1 x2 y2)
  "Evaluate a quadratic Bézier at parameter T-PARAM. Returns (values x y)."
  (declare (type double-float t-param x0 y0 x1 y1 x2 y2)
           (optimize (speed 3) (safety 1)))
  (let* ((s (- 1.0d0 t-param))
         (s2 (* s s))
         (t2 (* t-param t-param)))
    (values
     (+ (* s2 x0) (* 2.0d0 s t-param x1) (* t2 x2))
     (+ (* s2 y0) (* 2.0d0 s t-param y1) (* t2 y2)))))

;;; ============================================================
;;; Segment intersection test
;;; Ported from _path.h segments_intersect
;;; ============================================================

(defun segments-intersect-p (x1 y1 x2 y2 x3 y3 x4 y4)
  "Return T if segment (X1,Y1)-(X2,Y2) intersects segment (X3,Y3)-(X4,Y4).
Matches matplotlib's _path.h segments_intersect."
  (declare (type double-float x1 y1 x2 y2 x3 y3 x4 y4)
           (optimize (speed 3) (safety 1)))
  (let ((den (- (* (- y4 y3) (- x2 x1))
                (* (- x4 x3) (- y2 y1)))))
    (if (isclose den 0.0d0)
        ;; Parallel or collinear
        (let ((t-area (- (* x2 y3) (* x3 y2)
                         (* x1 (- y3 y2))
                         (- (* y1 (- x3 x2))))))
          (if (isclose t-area 0.0d0)
              ;; Collinear — check overlap
              (if (and (= x1 x2) (= x2 x3))
                  ;; Vertical segments
                  (or (and (<= (min y1 y2) (min y3 y4)) (<= (min y3 y4) (max y1 y2)))
                      (and (<= (min y3 y4) (min y1 y2)) (<= (min y1 y2) (max y3 y4))))
                  ;; General collinear
                  (or (and (<= (min x1 x2) (min x3 x4)) (<= (min x3 x4) (max x1 x2)))
                      (and (<= (min x3 x4) (min x1 x2)) (<= (min x1 x2) (max x3 x4)))))
              ;; Parallel, not collinear
              nil))
        ;; General case
        (let* ((n1 (- (* (- x4 x3) (- y1 y3))
                      (* (- y4 y3) (- x1 x3))))
               (n2 (- (* (- x2 x1) (- y1 y3))
                      (* (- y2 y1) (- x1 x3))))
               (u1 (/ n1 den))
               (u2 (/ n2 den)))
          (and (or (> u1 0.0d0) (isclose u1 0.0d0))
               (or (< u1 1.0d0) (isclose u1 1.0d0))
               (or (> u2 0.0d0) (isclose u2 0.0d0))
               (or (< u2 1.0d0) (isclose u2 1.0d0)))))))

;;; ============================================================
;;; Segment-rectangle intersection
;;; Ported from _path.h segment_intersects_rectangle
;;; ============================================================

(defun segment-intersects-rectangle-p (x1 y1 x2 y2 cx cy w h)
  "Return T if segment (X1,Y1)-(X2,Y2) intersects rectangle centered at (CX,CY)
with width W and height H."
  (declare (type double-float x1 y1 x2 y2 cx cy w h)
           (optimize (speed 3) (safety 1)))
  (and (< (abs (- (+ x1 x2) (* 2.0d0 cx))) (+ (abs (- x1 x2)) w))
       (< (abs (- (+ y1 y2) (* 2.0d0 cy))) (+ (abs (- y1 y2)) h))
       (< (* 2.0d0 (abs (- (* (- x1 cx) (- y1 y2))
                            (* (- y1 cy) (- x1 x2)))))
          (+ (* w (abs (- y1 y2)))
             (* h (abs (- x1 x2)))))))

;;; ============================================================
;;; Pixel grid snapping (for crisp rendering)
;;; ============================================================

(defun snap-to-pixel (x y &optional (stroke-width 1.0d0))
  "Snap coordinates to pixel grid for crisp rendering.
Returns (values snapped-x snapped-y).
STROKE-WIDTH affects the snapping offset (odd widths snap to half-pixels)."
  (declare (type double-float x y stroke-width)
           (optimize (speed 3) (safety 1)))
  (let ((offset (if (oddp (round stroke-width)) 0.5d0 0.0d0)))
    (values (+ (fround x) offset)
            (+ (fround y) offset))))

;;; ============================================================
;;; Simple linear interpolation (from cbook)
;;; ============================================================

(defun simple-linear-interpolation (vertices steps)
  "Interpolate between rows of a 2D vertex array.
VERTICES is a (N, 2) array. STEPS is the number of subdivisions per segment.
Returns a new ((N-1)*STEPS + 1, 2) array."
  (declare (type fixnum steps))
  (let* ((n (array-dimension vertices 0))
         (new-n (1+ (* (1- n) steps)))
         (result (make-array (list new-n 2) :element-type 'double-float)))
    (dotimes (seg (1- n))
      (let ((x0 (aref vertices seg 0))
            (y0 (aref vertices seg 1))
            (x1 (aref vertices (1+ seg) 0))
            (y1 (aref vertices (1+ seg) 1)))
        (dotimes (s steps)
          (let* ((t-param (/ (float s 1.0d0) (float steps 1.0d0)))
                 (idx (+ (* seg steps) s)))
            (setf (aref result idx 0) (lerp x0 x1 t-param)
                  (aref result idx 1) (lerp y0 y1 t-param))))))
    ;; Last point
    (setf (aref result (1- new-n) 0) (aref vertices (1- n) 0)
          (aref result (1- new-n) 1) (aref vertices (1- n) 1))
    result))
