;;;; path.lisp — Path class and operations
;;;; Ported from matplotlib's path.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.primitives)

;;; ============================================================
;;; Path code constants
;;; ============================================================

(defconstant +stop+ 0
  "Marker for end of entire path (currently not required and ignored).")
(defconstant +moveto+ 1
  "Pick up the pen and move to the given vertex.")
(defconstant +lineto+ 2
  "Draw a line from the current position to the given vertex.")
(defconstant +curve3+ 3
  "Draw a quadratic Bézier curve (1 control point, 1 endpoint).")
(defconstant +curve4+ 4
  "Draw a cubic Bézier curve (2 control points, 1 endpoint).")
(defconstant +closepoly+ 79
  "Draw a line segment to the start point of the current polyline.")

(defparameter *num-vertices-for-code*
  (let ((ht (make-hash-table)))
    (setf (gethash +stop+ ht) 1
          (gethash +moveto+ ht) 1
          (gethash +lineto+ ht) 1
          (gethash +curve3+ ht) 2
          (gethash +curve4+ ht) 3
          (gethash +closepoly+ ht) 1)
    ht)
  "Hash table mapping path codes to number of vertices consumed.")

;;; ============================================================
;;; BBox — Bounding Box
;;; ============================================================

(defstruct (bbox (:constructor %make-bbox))
  "An axis-aligned bounding box defined by (x0, y0) to (x1, y1)."
  (x0 0.0d0 :type double-float)
  (y0 0.0d0 :type double-float)
  (x1 0.0d0 :type double-float)
  (y1 0.0d0 :type double-float))

(defun make-bbox (x0 y0 x1 y1)
  "Create a bounding box from (X0, Y0) to (X1, Y1)."
  (%make-bbox :x0 (float x0 1.0d0) :y0 (float y0 1.0d0)
              :x1 (float x1 1.0d0) :y1 (float y1 1.0d0)))

(defun bbox-null ()
  "Return a null (empty) bounding box with inverted extents."
  (%make-bbox :x0 most-positive-double-float
              :y0 most-positive-double-float
              :x1 most-negative-double-float
              :y1 most-negative-double-float))

(defun bbox-null-p (bb)
  "Return T if BB is a null bounding box."
  (or (> (bbox-x0 bb) (bbox-x1 bb))
      (> (bbox-y0 bb) (bbox-y1 bb))))

(defun bbox-extents (bb)
  "Return the extents as (values x0 y0 x1 y1)."
  (values (bbox-x0 bb) (bbox-y0 bb) (bbox-x1 bb) (bbox-y1 bb)))

(defun bbox-width (bb)
  (- (bbox-x1 bb) (bbox-x0 bb)))

(defun bbox-height (bb)
  (- (bbox-y1 bb) (bbox-y0 bb)))

(defun bbox-union (bb1 bb2)
  "Return a new bbox that is the union of BB1 and BB2."
  (if (bbox-null-p bb1) bb2
      (if (bbox-null-p bb2) bb1
          (make-bbox (min (bbox-x0 bb1) (bbox-x0 bb2))
                     (min (bbox-y0 bb1) (bbox-y0 bb2))
                     (max (bbox-x1 bb1) (bbox-x1 bb2))
                     (max (bbox-y1 bb1) (bbox-y1 bb2))))))

(defun bbox-contains-point-p (bb x y)
  "Return T if the bounding box contains the point (X, Y)."
  (and (<= (bbox-x0 bb) x (bbox-x1 bb))
       (<= (bbox-y0 bb) y (bbox-y1 bb))))

;;; ============================================================
;;; Path class
;;; ============================================================

(defstruct (mpl-path (:constructor %make-mpl-path))
  "A series of possibly disconnected, possibly closed, line and curve segments.
Vertices is a 2D array (N, 2) of double-float.
Codes is a 1D array of (unsigned-byte 8) or NIL."
  (vertices (make-array '(0 2) :element-type 'double-float)
   :type (simple-array double-float (* 2)))
  (codes nil :type (or null (simple-array (unsigned-byte 8) (*))))
  (readonly nil :type boolean)
  (should-simplify nil :type boolean)
  (simplify-threshold 0.0d0 :type double-float)
  (interpolation-steps 1 :type fixnum))

;;; ============================================================
;;; Vertex array construction helpers
;;; ============================================================

(defun %coerce-vertices (input)
  "Convert various input formats to a (simple-array double-float (* 2)).
Accepts: 2D array, list of (x y) lists/vectors, or already correct type."
  (etypecase input
    ;; Already a 2D double-float array
    ((simple-array double-float (* 2)) input)
    ;; General 2D array — copy with coercion
    (array
     (let* ((dims (array-dimensions input))
            (rows (first dims))
            (cols (if (> (length dims) 1) (second dims) 0)))
       (when (and (> (length dims) 1) (/= cols 2))
         (error "Vertices array must have shape (N, 2), got ~S" dims))
       (when (= (length dims) 1)
         ;; 1D array — might be empty
         (if (zerop rows)
             (return-from %coerce-vertices
               (make-array '(0 2) :element-type 'double-float))
             (error "Vertices must be 2D, got 1D array of length ~D" rows)))
       (let ((result (make-array (list rows 2) :element-type 'double-float)))
         (dotimes (r rows)
           (setf (aref result r 0) (float (aref input r 0) 1.0d0)
                 (aref result r 1) (float (aref input r 1) 1.0d0)))
         result)))
    ;; List of (x y) lists/vectors
    (list
     (if (null input)
         (make-array '(0 2) :element-type 'double-float)
         (let* ((n (length input))
                (result (make-array (list n 2) :element-type 'double-float)))
           (loop for row in input
                 for i from 0
                 do (etypecase row
                      (list
                       (setf (aref result i 0) (float (first row) 1.0d0)
                             (aref result i 1) (float (second row) 1.0d0)))
                      (vector
                       (setf (aref result i 0) (float (elt row 0) 1.0d0)
                             (aref result i 1) (float (elt row 1) 1.0d0)))))
           result)))))

(defun %coerce-codes (input n)
  "Convert codes input to a (simple-array (unsigned-byte 8) (*)).
INPUT can be a vector, list, or NIL."
  (when (null input)
    (return-from %coerce-codes nil))
  (etypecase input
    ((simple-array (unsigned-byte 8) (*)) input)
    (vector
     (let ((result (make-array n :element-type '(unsigned-byte 8))))
       (dotimes (i n)
         (setf (aref result i) (aref input i)))
       result))
    (list
     (let ((result (make-array n :element-type '(unsigned-byte 8))))
       (loop for code in input
             for i from 0
             do (setf (aref result i) code))
       result))))

;;; ============================================================
;;; Path constructor
;;; ============================================================

(defun make-path (&key vertices codes (closed nil) (readonly nil) (interpolation-steps 1))
  "Create a new Path with the given VERTICES and CODES.
VERTICES: 2D array-like of (N, 2) points.
CODES: 1D array-like of (unsigned-byte 8) path codes, or NIL.
CLOSED: If T and CODES is NIL, treat as closed polygon.
READONLY: If T, path is immutable."
  (let* ((verts (%coerce-vertices vertices))
         (n (array-dimension verts 0))
         (code-arr nil))
    ;; Handle codes
    (cond
      ;; Explicit codes provided
      ((and codes (> n 0))
       ;; Validate length BEFORE coercing
       (let ((codes-len (etypecase codes
                          (list (length codes))
                          (vector (length codes)))))
         (unless (= codes-len n)
           (error "'codes' must have the same length as 'vertices'. ~
                   Your vertices have shape (~D, 2) but your codes have shape (~D)"
                  n codes-len)))
       (setf code-arr (%coerce-codes codes n))
       (when (and (> (length code-arr) 0) (/= (aref code-arr 0) +moveto+))
         (error "The first element of 'codes' must be equal to 'MOVETO' (~D). ~
                 Your first code is ~D"
                +moveto+ (aref code-arr 0))))
      ;; Closed path without explicit codes
      ;; All N original vertices get MOVETO/LINETO codes, then an extra
      ;; CLOSEPOLY entry is appended (with a copy of the first vertex).
      ;; CLOSEPOLY tells the renderer to draw back to the last MOVETO
      ;; position, so putting it on an original vertex would skip that
      ;; vertex (e.g. 4 vertices → triangle instead of rectangle).
      ((and closed (> n 0))
       (let* ((n+1 (1+ n))
              (new-verts (make-array (list n+1 2) :element-type 'double-float)))
         ;; Copy original vertices
         (dotimes (i n)
           (setf (aref new-verts i 0) (aref verts i 0)
                 (aref new-verts i 1) (aref verts i 1)))
         ;; Closing vertex = copy of first vertex
         (setf (aref new-verts n 0) (aref verts 0 0)
               (aref new-verts n 1) (aref verts 0 1))
         (setf verts new-verts)
         (setf code-arr (make-array n+1 :element-type '(unsigned-byte 8)))
         (setf (aref code-arr 0) +moveto+)
         (loop for i from 1 below n do
           (setf (aref code-arr i) +lineto+))
         (setf (aref code-arr n) +closepoly+))))
    ;; Create the path
    (%make-mpl-path :vertices verts
                    :codes code-arr
                    :readonly readonly
                    :interpolation-steps interpolation-steps
                    :should-simplify nil
                    :simplify-threshold 0.0d0)))

(defun path-length (path)
  "Return the number of vertices in PATH."
  (array-dimension (mpl-path-vertices path) 0))

;;; ============================================================
;;; Path iteration
;;; ============================================================

(defun path-iter-segments (path &key (curves t))
  "Iterate over all curve segments in PATH.
Returns a list of (vertices code) pairs where vertices is a list of (x y) points.
If CURVES is NIL, Bézier curves are flattened to line segments."
  (let* ((verts (mpl-path-vertices path))
         (codes (mpl-path-codes path))
         (n (array-dimension verts 0))
         (result '())
         (i 0))
    (when (zerop n) (return-from path-iter-segments nil))
    ;; If no codes, synthesize MOVETO + LINETOs
    (unless codes
      (setf codes (make-array n :element-type '(unsigned-byte 8)))
      (setf (aref codes 0) +moveto+)
      (loop for j from 1 below n do (setf (aref codes j) +lineto+)))
    (loop while (< i n) do
      (let ((code (aref codes i)))
        (cond
          ((= code +stop+) (return))
          ((= code +moveto+)
           (push (list (list (aref verts i 0) (aref verts i 1)) code) result)
           (incf i))
          ((= code +lineto+)
           (push (list (list (aref verts i 0) (aref verts i 1)) code) result)
           (incf i))
          ((= code +closepoly+)
           (push (list (list (aref verts i 0) (aref verts i 1)) code) result)
           (incf i))
          ((and (= code +curve3+) curves)
           ;; Quadratic Bézier: need 2 vertices total (this + next)
           (if (< (1+ i) n)
               (progn
                 (push (list (list (aref verts i 0) (aref verts i 1)
                                   (aref verts (1+ i) 0) (aref verts (1+ i) 1))
                             code)
                       result)
                 (incf i 2))
               (incf i)))
          ((and (= code +curve4+) curves)
           ;; Cubic Bézier: need 3 vertices total (this + next two)
           (if (< (+ i 2) n)
               (progn
                 (push (list (list (aref verts i 0) (aref verts i 1)
                                   (aref verts (1+ i) 0) (aref verts (1+ i) 1)
                                   (aref verts (+ i 2) 0) (aref verts (+ i 2) 1))
                             code)
                       result)
                 (incf i 3))
               (incf i)))
          ((and (= code +curve3+) (not curves))
           ;; Flatten quadratic Bézier to line segments
           (when (< (1+ i) n)
             (push (list (list (aref verts (1+ i) 0) (aref verts (1+ i) 1)) +lineto+) result)
             (incf i 2)))
          ((and (= code +curve4+) (not curves))
           ;; Flatten cubic Bézier to line segments
           (when (< (+ i 2) n)
             (push (list (list (aref verts (+ i 2) 0) (aref verts (+ i 2) 1)) +lineto+) result)
             (incf i 3)))
          (t (incf i)))))
    (nreverse result)))

;;; ============================================================
;;; Path extents (bounding box)
;;; ============================================================

(defun path-get-extents (path)
  "Get the bounding box of PATH. Returns a BBOX.
Takes into account Bézier curve extrema, not just control points."
  (let* ((verts (mpl-path-vertices path))
         (codes (mpl-path-codes path))
         (n (array-dimension verts 0)))
    (when (zerop n)
      (return-from path-get-extents (bbox-null)))
    (if (or (null codes)
            ;; Optimization: if only lines, just look at MOVETO/LINETO vertices
            (not (some (lambda (c) (or (= c +curve3+) (= c +curve4+)))
                       (loop for i below n collect (aref codes i)))))
        ;; Fast path: only line segments
        (let ((min-x most-positive-double-float)
              (min-y most-positive-double-float)
              (max-x most-negative-double-float)
              (max-y most-negative-double-float))
          (dotimes (i n)
            (let ((code (if codes (aref codes i) (if (zerop i) +moveto+ +lineto+))))
              ;; Only count MOVETO and LINETO vertices
              (when (or (= code +moveto+) (= code +lineto+))
                (let ((x (aref verts i 0))
                      (y (aref verts i 1)))
                  (when (and (not (float-features:float-nan-p x))
                             (not (float-features:float-nan-p y)))
                    (setf min-x (min min-x x) max-x (max max-x x)
                          min-y (min min-y y) max-y (max max-y y)))))))
          (if (> min-x max-x)
              (bbox-null)
              (make-bbox min-x min-y max-x max-y)))
        ;; Slow path: handle Bézier curves
        (let ((min-x most-positive-double-float)
              (min-y most-positive-double-float)
              (max-x most-negative-double-float)
              (max-y most-negative-double-float)
              (i 0)
              (prev-x 0.0d0) (prev-y 0.0d0))
          (declare (type double-float min-x min-y max-x max-y prev-x prev-y))
          (labels ((update (x y)
                     (when (and (not (float-features:float-nan-p x))
                                (not (float-features:float-nan-p y)))
                       (setf min-x (min min-x x) max-x (max max-x x)
                             min-y (min min-y y) max-y (max max-y y)))))
            (loop while (< i n) do
              (let ((code (aref codes i)))
                (cond
                  ((or (= code +moveto+) (= code +lineto+))
                   (let ((x (aref verts i 0)) (y (aref verts i 1)))
                     (update x y)
                     (setf prev-x x prev-y y))
                   (incf i))
                  ((= code +curve3+)
                   (when (< (1+ i) n)
                     (let ((cx (aref verts i 0)) (cy (aref verts i 1))
                           (ex (aref verts (1+ i) 0)) (ey (aref verts (1+ i) 1)))
                       ;; Endpoints
                       (update ex ey)
                       ;; Find extrema in x
                       (dolist (tv (quadratic-bezier-extrema-t prev-x cx ex))
                         (multiple-value-bind (qx qy)
                             (quadratic-bezier-point-at tv prev-x prev-y cx cy ex ey)
                           (update qx qy)))
                       ;; Find extrema in y
                       (dolist (tv (quadratic-bezier-extrema-t prev-y cy ey))
                         (multiple-value-bind (qx qy)
                             (quadratic-bezier-point-at tv prev-x prev-y cx cy ex ey)
                           (update qx qy)))
                       (setf prev-x ex prev-y ey))
                     (incf i 2)))
                  ((= code +curve4+)
                   (when (< (+ i 2) n)
                     (let ((c1x (aref verts i 0)) (c1y (aref verts i 1))
                           (c2x (aref verts (1+ i) 0)) (c2y (aref verts (1+ i) 1))
                           (ex (aref verts (+ i 2) 0)) (ey (aref verts (+ i 2) 1)))
                       ;; Endpoints
                       (update ex ey)
                       ;; Find extrema in x
                       (dolist (tv (cubic-bezier-extrema-t prev-x c1x c2x ex))
                         (multiple-value-bind (cx cy)
                             (cubic-bezier-point-at tv prev-x prev-y c1x c1y c2x c2y ex ey)
                           (update cx cy)))
                       ;; Find extrema in y
                       (dolist (tv (cubic-bezier-extrema-t prev-y c1y c2y ey))
                         (multiple-value-bind (cx cy)
                             (cubic-bezier-point-at tv prev-x prev-y c1x c1y c2x c2y ex ey)
                           (update cx cy)))
                       (setf prev-x ex prev-y ey))
                     (incf i 3)))
                  ((= code +closepoly+)
                   (incf i))
                  ((= code +stop+)
                   (return))
                  (t (incf i))))))
          (if (> min-x max-x)
              (bbox-null)
              (make-bbox min-x min-y max-x max-y))))))

;;; ============================================================
;;; Point-in-path tests
;;; ============================================================

(defun path-contains-point (path point &key (radius 0.0d0))
  "Return T if the area enclosed by PATH contains POINT.
POINT is a vector or list of (x y).
RADIUS adds margin (positive expands, negative shrinks)."
  (declare (ignore radius)) ;; TODO: implement radius support
  (let ((px (float (if (listp point) (first point) (elt point 0)) 1.0d0))
        (py (float (if (listp point) (second point) (elt point 1)) 1.0d0)))
    ;; NaN points are never inside any path
    (when (or (float-features:float-nan-p px) (float-features:float-nan-p py))
      (return-from path-contains-point nil))
    (point-in-path-crossings px py
                              (mpl-path-vertices path)
                              (mpl-path-codes path))))

(defun path-contains-points (path points &key (radius 0.0d0))
  "Return a boolean vector indicating which POINTS are inside PATH.
POINTS is a list of (x y) pairs or a 2D array."
  (let* ((pts (etypecase points
                (list points)
                (array (loop for i below (array-dimension points 0)
                             collect (list (aref points i 0) (aref points i 1))))))
         (n (length pts))
         (result (make-array n :element-type 'boolean :initial-element nil)))
    (loop for pt in pts
          for i from 0
          do (setf (aref result i) (path-contains-point path pt :radius radius)))
    result))

;;; ============================================================
;;; Path intersection tests
;;; ============================================================

(defun %path-to-line-segments (path)
  "Convert PATH to a list of line segments: ((x1 y1 x2 y2) ...).
Bézier curves are flattened."
  (let* ((verts (mpl-path-vertices path))
         (codes (mpl-path-codes path))
         (n (array-dimension verts 0))
         (segments '())
         (i 0)
         (prev-x 0.0d0) (prev-y 0.0d0)
         (start-x 0.0d0) (start-y 0.0d0))
    (loop while (< i n) do
      (let ((code (if codes (aref codes i) (if (zerop i) +moveto+ +lineto+))))
        (cond
          ((= code +moveto+)
           (setf prev-x (aref verts i 0) prev-y (aref verts i 1))
           (setf start-x prev-x start-y prev-y)
           (incf i))
          ((= code +lineto+)
           (let ((x (aref verts i 0)) (y (aref verts i 1)))
             (push (list prev-x prev-y x y) segments)
             (setf prev-x x prev-y y))
           (incf i))
          ((= code +closepoly+)
           (push (list prev-x prev-y start-x start-y) segments)
           (setf prev-x start-x prev-y start-y)
           (incf i))
          ((= code +curve3+)
           ;; Flatten quadratic Bézier
           (when (< (1+ i) n)
             (let ((cx (aref verts i 0)) (cy (aref verts i 1))
                   (ex (aref verts (1+ i) 0)) (ey (aref verts (1+ i) 1)))
               (dotimes (s 4)
                 (let* ((t0 (/ (float s 1.0d0) 4.0d0))
                        (t1 (/ (float (1+ s) 1.0d0) 4.0d0)))
                   (multiple-value-bind (x0 y0)
                       (quadratic-bezier-point-at t0 prev-x prev-y cx cy ex ey)
                     (multiple-value-bind (x1 y1)
                         (quadratic-bezier-point-at t1 prev-x prev-y cx cy ex ey)
                       (push (list x0 y0 x1 y1) segments)))))
               (setf prev-x ex prev-y ey))
             (incf i 2)))
          ((= code +curve4+)
           ;; Flatten cubic Bézier
           (when (< (+ i 2) n)
             (let ((c1x (aref verts i 0)) (c1y (aref verts i 1))
                   (c2x (aref verts (1+ i) 0)) (c2y (aref verts (1+ i) 1))
                   (ex (aref verts (+ i 2) 0)) (ey (aref verts (+ i 2) 1)))
               (dotimes (s 8)
                 (let* ((t0 (/ (float s 1.0d0) 8.0d0))
                        (t1 (/ (float (1+ s) 1.0d0) 8.0d0)))
                   (multiple-value-bind (x0 y0)
                       (cubic-bezier-point-at t0 prev-x prev-y c1x c1y c2x c2y ex ey)
                     (multiple-value-bind (x1 y1)
                         (cubic-bezier-point-at t1 prev-x prev-y c1x c1y c2x c2y ex ey)
                       (push (list x0 y0 x1 y1) segments)))))
               (setf prev-x ex prev-y ey))
             (incf i 3)))
          (t (incf i)))))
    (nreverse segments)))

(defun path-intersects-path (path1 path2 &key (filled t))
  "Return T if PATH1 intersects PATH2.
If FILLED is T, also returns T if one path completely encloses the other."
  (let ((segs1 (%path-to-line-segments path1))
        (segs2 (%path-to-line-segments path2)))
    ;; Check segment-segment intersections
    (dolist (s1 segs1)
      (dolist (s2 segs2)
        (let ((x1 (first s1)) (y1 (second s1))
              (x2 (third s1)) (y2 (fourth s1))
              (x3 (first s2)) (y3 (second s2))
              (x4 (third s2)) (y4 (fourth s2)))
          ;; Skip zero-length segments
          (when (and (not (isclose (+ (* (- x1 x2) (- x1 x2))
                                      (* (- y1 y2) (- y1 y2))) 0.0d0))
                     (not (isclose (+ (* (- x3 x4) (- x3 x4))
                                      (* (- y3 y4) (- y3 y4))) 0.0d0)))
            (when (segments-intersect-p x1 y1 x2 y2 x3 y3 x4 y4)
              (return-from path-intersects-path t))))))
    ;; If filled, check containment
    (when filled
      (let ((verts2 (mpl-path-vertices path2)))
        (when (> (array-dimension verts2 0) 0)
          (when (path-contains-point path1 (list (aref verts2 0 0) (aref verts2 0 1)))
            (return-from path-intersects-path t))))
      (let ((verts1 (mpl-path-vertices path1)))
        (when (> (array-dimension verts1 0) 0)
          (when (path-contains-point path2 (list (aref verts1 0 0) (aref verts1 0 1)))
            (return-from path-intersects-path t)))))
    nil))

(defun path-intersects-bbox (path bb &key (filled t))
  "Return T if PATH intersects bounding box BB."
  (let* ((x0 (bbox-x0 bb)) (y0 (bbox-y0 bb))
         (x1 (bbox-x1 bb)) (y1 (bbox-y1 bb))
         (cx (* 0.5d0 (+ x0 x1)))
         (cy (* 0.5d0 (+ y0 y1)))
         (w (abs (- x0 x1)))
         (h (abs (- y0 y1)))
         (segs (%path-to-line-segments path)))
    ;; Check if first vertex is inside bbox
    (let ((verts (mpl-path-vertices path)))
      (when (> (array-dimension verts 0) 0)
        (let ((vx (aref verts 0 0)) (vy (aref verts 0 1)))
          (when (and (<= (* 2.0d0 (abs (- vx cx))) w)
                     (<= (* 2.0d0 (abs (- vy cy))) h))
            (return-from path-intersects-bbox t)))))
    ;; Check segment-rectangle intersections
    (dolist (seg segs)
      (when (segment-intersects-rectangle-p
             (first seg) (second seg) (third seg) (fourth seg)
             cx cy w h)
        (return-from path-intersects-bbox t)))
    ;; If filled, check containment
    (when filled
      (when (path-contains-point path (list cx cy))
        (return-from path-intersects-bbox t)))
    nil))

;;; ============================================================
;;; Path transformation
;;; ============================================================

(defun path-transformed (path transform-fn)
  "Return a new Path with vertices transformed by TRANSFORM-FN.
TRANSFORM-FN takes (x y) and returns (values new-x new-y)."
  (let* ((verts (mpl-path-vertices path))
         (n (array-dimension verts 0))
         (new-verts (make-array (list n 2) :element-type 'double-float)))
    (dotimes (i n)
      (multiple-value-bind (nx ny)
          (funcall transform-fn (aref verts i 0) (aref verts i 1))
        (setf (aref new-verts i 0) (float nx 1.0d0)
              (aref new-verts i 1) (float ny 1.0d0))))
    (make-path :vertices new-verts
               :codes (mpl-path-codes path)
               :interpolation-steps (mpl-path-interpolation-steps path))))

;;; ============================================================
;;; Path clipping
;;; ============================================================

(defun path-clip-to-bbox (path bb &key (inside t))
  "Clip PATH to bounding box BB. Returns a new path.
If INSIDE is T, clips to inside of box; otherwise to outside."
  (declare (ignore inside))
  (let* ((xmin (bbox-x0 bb)) (ymin (bbox-y0 bb))
         (xmax (bbox-x1 bb)) (ymax (bbox-y1 bb)))
    ;; Convert path to polygons, clip each, reconstruct compound path
    (let ((polygons (path-to-polygon-points path))
          (clipped-paths '()))
      (dolist (poly polygons)
        (let ((clipped (sutherland-hodgman-clip poly xmin ymin xmax ymax)))
          (when clipped
            ;; Close the polygon
            (when (and clipped
                       (not (and (= (car (first clipped)) (car (car (last clipped))))
                                 (= (cdr (first clipped)) (cdr (car (last clipped)))))))
              (setf clipped (append clipped (list (first clipped)))))
            (let* ((n (length clipped))
                   (verts (make-array (list n 2) :element-type 'double-float))
                   (codes nil))
              (loop for pt in clipped
                    for i from 0
                    do (setf (aref verts i 0) (float (car pt) 1.0d0)
                             (aref verts i 1) (float (cdr pt) 1.0d0)))
              (push (make-path :vertices verts :codes codes) clipped-paths)))))
      (if clipped-paths
          (path-make-compound-path (nreverse clipped-paths))
          (make-path :vertices '())))))

(defun path-to-polygon-points (path)
  "Convert PATH to a list of polygons. Each polygon is a list of (x . y) cons cells."
  (let* ((verts (mpl-path-vertices path))
         (codes (mpl-path-codes path))
         (n (array-dimension verts 0))
         (polygons '())
         (current-polygon '())
         (i 0))
    (loop while (< i n) do
      (let ((code (if codes (aref codes i) (if (zerop i) +moveto+ +lineto+))))
        (cond
          ((= code +moveto+)
           (when current-polygon
             (push (nreverse current-polygon) polygons)
             (setf current-polygon nil))
           (push (cons (aref verts i 0) (aref verts i 1)) current-polygon)
           (incf i))
          ((= code +lineto+)
           (push (cons (aref verts i 0) (aref verts i 1)) current-polygon)
           (incf i))
          ((= code +closepoly+)
           (when current-polygon
             ;; Close back to first point
             (let ((first-pt (car (last current-polygon))))
               (push first-pt current-polygon))
             (push (nreverse current-polygon) polygons)
             (setf current-polygon nil))
           (incf i))
          ((= code +curve3+)
           ;; Flatten quadratic
           (when (and current-polygon (< (1+ i) n))
             (let ((prev-pt (first current-polygon))
                   (cx (aref verts i 0)) (cy (aref verts i 1))
                   (ex (aref verts (1+ i) 0)) (ey (aref verts (1+ i) 1)))
               (dotimes (s 4)
                 (let ((t-val (/ (float (1+ s) 1.0d0) 4.0d0)))
                   (multiple-value-bind (qx qy)
                       (quadratic-bezier-point-at t-val
                                                   (car prev-pt) (cdr prev-pt)
                                                   cx cy ex ey)
                     (push (cons qx qy) current-polygon)))))
             (incf i 2)))
          ((= code +curve4+)
           ;; Flatten cubic
           (when (and current-polygon (< (+ i 2) n))
             (let ((prev-pt (first current-polygon))
                   (c1x (aref verts i 0)) (c1y (aref verts i 1))
                   (c2x (aref verts (1+ i) 0)) (c2y (aref verts (1+ i) 1))
                   (ex (aref verts (+ i 2) 0)) (ey (aref verts (+ i 2) 1)))
               (dotimes (s 8)
                 (let ((t-val (/ (float (1+ s) 1.0d0) 8.0d0)))
                   (multiple-value-bind (bx by)
                       (cubic-bezier-point-at t-val
                                               (car prev-pt) (cdr prev-pt)
                                               c1x c1y c2x c2y ex ey)
                     (push (cons bx by) current-polygon)))))
             (incf i 3)))
          (t (incf i)))))
    (when current-polygon
      (push (nreverse current-polygon) polygons))
    (nreverse polygons)))

;;; ============================================================
;;; Path conversion: to-polygons
;;; ============================================================

(defun path-to-polygons (path &key (closed-only t))
  "Convert PATH to a list of polygon arrays.
Each polygon is a (N, 2) array of double-float vertices.
If CLOSED-ONLY is T, only closed polygons returned; unclosed are closed explicitly."
  (let* ((verts (mpl-path-vertices path))
         (n (array-dimension verts 0))
         (result '()))
    (when (zerop n) (return-from path-to-polygons nil))
    ;; Simple case: no codes
    (when (null (mpl-path-codes path))
      (cond
        (closed-only
         (when (< n 3) (return-from path-to-polygons nil))
         ;; Check if already closed
         (if (and (= (aref verts 0 0) (aref verts (1- n) 0))
                  (= (aref verts 0 1) (aref verts (1- n) 1)))
             (return-from path-to-polygons (list verts))
             ;; Close it
             (let ((closed (make-array (list (1+ n) 2) :element-type 'double-float)))
               (dotimes (i n)
                 (setf (aref closed i 0) (aref verts i 0)
                       (aref closed i 1) (aref verts i 1)))
               (setf (aref closed n 0) (aref verts 0 0)
                     (aref closed n 1) (aref verts 0 1))
               (return-from path-to-polygons (list closed)))))
        (t
         (return-from path-to-polygons (list verts)))))
    ;; Complex case: with codes. Convert subpaths
    (let ((polygon-points (path-to-polygon-points path)))
      (dolist (poly polygon-points)
        (let ((pn (length poly)))
          (when (if closed-only (>= pn 3) (>= pn 1))
            (let ((arr-len pn))
              ;; If closed-only and not already closed, add closing point
              (when (and closed-only
                         (not (and (= (car (first poly)) (car (car (last poly))))
                                   (= (cdr (first poly)) (cdr (car (last poly)))))))
                (incf arr-len))
              (let ((arr (make-array (list arr-len 2) :element-type 'double-float)))
                (loop for pt in poly
                      for i from 0
                      do (setf (aref arr i 0) (float (car pt) 1.0d0)
                               (aref arr i 1) (float (cdr pt) 1.0d0)))
                ;; Close if needed
                (when (> arr-len pn)
                  (setf (aref arr (1- arr-len) 0) (float (car (first poly)) 1.0d0)
                        (aref arr (1- arr-len) 1) (float (cdr (first poly)) 1.0d0)))
                (push arr result)))))))
    (nreverse result)))

;;; ============================================================
;;; Path interpolation
;;; ============================================================

(defun path-interpolated (path steps)
  "Return a new Path with each line segment divided into STEPS parts."
  (when (or (= steps 1) (zerop (path-length path)))
    (return-from path-interpolated path))
  (let* ((verts (mpl-path-vertices path))
         (codes (mpl-path-codes path))
         (n (array-dimension verts 0)))
    ;; Handle closepoly: replace closepoly vertices with first vertex
    (let ((work-verts verts))
      (when codes
        ;; Check for CLOSEPOLY and fix vertices
        (let ((has-closepoly nil))
          (dotimes (i n)
            (when (= (aref codes i) +closepoly+)
              (setf has-closepoly t)))
          (when has-closepoly
            (setf work-verts (make-array (list n 2) :element-type 'double-float))
            (dotimes (i n)
              (if (= (aref codes i) +closepoly+)
                  ;; Use the first vertex of the subpath
                  (let ((first-v (loop for j from (1- i) downto 0
                                       when (= (aref codes j) +moveto+)
                                       return j
                                       finally (return 0))))
                    (setf (aref work-verts i 0) (aref verts first-v 0)
                          (aref work-verts i 1) (aref verts first-v 1)))
                  (setf (aref work-verts i 0) (aref verts i 0)
                        (aref work-verts i 1) (aref verts i 1)))))))
      ;; Interpolate vertices
      (let ((new-verts (simple-linear-interpolation work-verts steps)))
        ;; Interpolate codes
        (if codes
            (let* ((new-n (array-dimension new-verts 0))
                   (new-codes (make-array new-n :element-type '(unsigned-byte 8)
                                                :initial-element +lineto+)))
              ;; Place original codes at their positions
              (dotimes (i n)
                (let ((new-idx (* i steps)))
                  (when (< new-idx new-n)
                    (setf (aref new-codes new-idx) (aref codes i)))))
              (make-path :vertices new-verts :codes new-codes))
            (make-path :vertices new-verts))))))

;;; ============================================================
;;; Path cleaned
;;; ============================================================

(defun path-cleaned (path &key (remove-nans nil) (curves t))
  "Return a cleaned copy of PATH.
If REMOVE-NANS is T, remove NaN vertices.
If CURVES is NIL, flatten all curves to line segments."
  (let* ((segments (path-iter-segments path :curves curves))
         (all-verts '())
         (all-codes '()))
    (when (null segments)
      ;; Return path with just a STOP
      (let ((v (make-array '(1 2) :element-type 'double-float :initial-element 0.0d0))
            (c (make-array 1 :element-type '(unsigned-byte 8) :initial-element +stop+)))
        (return-from path-cleaned (make-path :vertices v :codes c))))
    (dolist (seg segments)
      (let ((seg-verts (first seg))
            (code (second seg)))
        (cond
          ((or (= code +moveto+) (= code +lineto+) (= code +closepoly+))
           (let ((x (first seg-verts)) (y (second seg-verts)))
             (if (and remove-nans (or (float-features:float-nan-p x)
                                       (float-features:float-nan-p y)))
                 nil ; skip NaN
                 (progn
                   (push (list x y) all-verts)
                   (push code all-codes)))))
          ((= code +curve3+)
           ;; 4 values: cx cy ex ey
           (push (list (first seg-verts) (second seg-verts)) all-verts)
           (push code all-codes)
           (push (list (third seg-verts) (fourth seg-verts)) all-verts)
           (push code all-codes))
          ((= code +curve4+)
           ;; 6 values: c1x c1y c2x c2y ex ey
           (push (list (first seg-verts) (second seg-verts)) all-verts)
           (push code all-codes)
           (push (list (third seg-verts) (fourth seg-verts)) all-verts)
           (push code all-codes)
           (push (list (fifth seg-verts) (sixth seg-verts)) all-verts)
           (push code all-codes)))))
    ;; Add STOP
    (push (list 0.0d0 0.0d0) all-verts)
    (push +stop+ all-codes)
    (let* ((all-verts (nreverse all-verts))
           (all-codes (nreverse all-codes))
           (n (length all-verts))
           (v (make-array (list n 2) :element-type 'double-float))
           (c (make-array n :element-type '(unsigned-byte 8))))
      ;; Filter NaN segments if remove-nans
      (loop for vert in all-verts
            for code in all-codes
            for i from 0
            do (setf (aref v i 0) (float (first vert) 1.0d0)
                     (aref v i 1) (float (second vert) 1.0d0)
                     (aref c i) code))
      (make-path :vertices v :codes c))))

;;; ============================================================
;;; Path constructors
;;; ============================================================

(defun path-make-compound-path (paths)
  "Concatenate a list of Paths into a single Path, removing all STOPs."
  (when (null paths)
    (return-from path-make-compound-path
      (make-path :vertices (make-array '(0 2) :element-type 'double-float))))
  ;; Count total vertices
  (let ((total 0))
    (dolist (p paths)
      (incf total (path-length p)))
    (when (zerop total)
      (return-from path-make-compound-path
        (make-path :vertices (make-array '(0 2) :element-type 'double-float)
                   :codes (make-array 0 :element-type '(unsigned-byte 8)))))
    (let ((all-verts (make-array (list total 2) :element-type 'double-float))
          (all-codes (make-array total :element-type '(unsigned-byte 8)))
          (offset 0))
      (dolist (p paths)
        (let* ((v (mpl-path-vertices p))
               (c (mpl-path-codes p))
               (n (path-length p)))
          (dotimes (i n)
            (setf (aref all-verts (+ offset i) 0) (aref v i 0)
                  (aref all-verts (+ offset i) 1) (aref v i 1))
            (if c
                (setf (aref all-codes (+ offset i)) (aref c i))
                ;; No codes: MOVETO first, then LINETO
                (setf (aref all-codes (+ offset i))
                      (if (zerop i) +moveto+ +lineto+))))
          (incf offset n)))
      ;; Remove STOPs
      (let ((keep-count 0))
        (dotimes (i total)
          (when (/= (aref all-codes i) +stop+)
            (incf keep-count)))
        (if (= keep-count total)
            (make-path :vertices all-verts :codes all-codes)
            (let ((new-v (make-array (list keep-count 2) :element-type 'double-float))
                  (new-c (make-array keep-count :element-type '(unsigned-byte 8)))
                  (j 0))
              (dotimes (i total)
                (when (/= (aref all-codes i) +stop+)
                  (setf (aref new-v j 0) (aref all-verts i 0)
                        (aref new-v j 1) (aref all-verts i 1)
                        (aref new-c j) (aref all-codes i))
                  (incf j)))
              (make-path :vertices new-v :codes new-c)))))))

;;; ============================================================
;;; Unit shapes
;;; ============================================================

(let ((cached nil))
  (defun path-unit-rectangle ()
    "Return a Path of the unit rectangle from (0,0) to (1,1)."
    (or cached
        (setf cached
              (make-path :vertices '((0.0 0.0) (1.0 0.0) (1.0 1.0) (0.0 1.0) (0.0 0.0))
                         :closed t :readonly t)))))

(defun path-unit-circle ()
  "Return the readonly Path of the unit circle.
Approximated using 8 cubic Bézier curves."
  (path-circle :center '(0.0d0 0.0d0) :radius 1.0d0 :readonly t))

(defun path-circle (&key (center '(0.0d0 0.0d0)) (radius 1.0d0) (readonly nil))
  "Return a Path representing a circle of given RADIUS and CENTER."
  (let* ((r (float radius 1.0d0))
         (cx (float (if (listp center) (first center) (elt center 0)) 1.0d0))
         (cy (float (if (listp center) (second center) (elt center 1)) 1.0d0))
         (magic 0.2652031d0)
         (sqrthalf (sqrt 0.5d0))
         (magic45 (* sqrthalf magic))
         ;; 26 vertices: 8 cubic Bézier segments + MOVETO + CLOSEPOLY
         (raw-verts (list
                     (list 0.0d0 -1.0d0)
                     ;; Segment 1
                     (list magic -1.0d0)
                     (list (- sqrthalf magic45) (- (- sqrthalf) magic45))
                     (list sqrthalf (- sqrthalf))
                     ;; Segment 2
                     (list (+ sqrthalf magic45) (+ (- sqrthalf) magic45))
                     (list 1.0d0 (- magic))
                     (list 1.0d0 0.0d0)
                     ;; Segment 3
                     (list 1.0d0 magic)
                     (list (+ sqrthalf magic45) (- sqrthalf magic45))
                     (list sqrthalf sqrthalf)
                     ;; Segment 4
                     (list (- sqrthalf magic45) (+ sqrthalf magic45))
                     (list magic 1.0d0)
                     (list 0.0d0 1.0d0)
                     ;; Segment 5
                     (list (- magic) 1.0d0)
                     (list (+ (- sqrthalf) magic45) (+ sqrthalf magic45))
                     (list (- sqrthalf) sqrthalf)
                     ;; Segment 6
                     (list (- (- sqrthalf) magic45) (- sqrthalf magic45))
                     (list -1.0d0 magic)
                     (list -1.0d0 0.0d0)
                     ;; Segment 7
                     (list -1.0d0 (- magic))
                     (list (- (- sqrthalf) magic45) (+ (- sqrthalf) magic45))
                     (list (- sqrthalf) (- sqrthalf))
                     ;; Segment 8
                     (list (+ (- sqrthalf) magic45) (- (- sqrthalf) magic45))
                     (list (- magic) -1.0d0)
                     (list 0.0d0 -1.0d0)
                     ;; Close
                     (list 0.0d0 -1.0d0)))
         (n (length raw-verts))
         (verts (make-array (list n 2) :element-type 'double-float))
         (codes (make-array n :element-type '(unsigned-byte 8) :initial-element +curve4+)))
    ;; Scale and translate vertices
    (loop for pt in raw-verts
          for i from 0
          do (setf (aref verts i 0) (+ (* (first pt) r) cx)
                   (aref verts i 1) (+ (* (second pt) r) cy)))
    ;; Set codes
    (setf (aref codes 0) +moveto+)
    (setf (aref codes (1- n)) +closepoly+)
    (make-path :vertices verts :codes codes :readonly readonly)))

;;; ============================================================
;;; Arc and Wedge
;;; ============================================================

(defun path-arc (theta1 theta2 &key (n nil) (is-wedge nil))
  "Return a Path for the unit circle arc from THETA1 to THETA2 (degrees).
If N is provided, it is the number of spline segments.
If IS-WEDGE is T, the arc is a wedge (pie slice)."
  (let* ((halfpi (* pi 0.5d0))
         (eta1 (float theta1 1.0d0))
         (eta2-raw (- (float theta2 1.0d0)
                      (* 360.0d0 (floor (/ (- (float theta2 1.0d0) eta1) 360.0d0)))))
         (eta2 (if (and (/= (float theta2 1.0d0) eta1) (<= eta2-raw eta1))
                   (+ eta2-raw 360.0d0)
                   eta2-raw)))
    ;; Convert to radians
    (setf eta1 (* eta1 (/ pi 180.0d0))
          eta2 (* eta2 (/ pi 180.0d0)))
    ;; Number of curve segments
    (let ((nseg (or n (max 1 (expt 2 (ceiling (/ (- eta2 eta1) halfpi)))))))
      (when (< nseg 1)
        (error "n must be >= 1 or NIL"))
      (let* ((deta (/ (- eta2 eta1) nseg))
             (t-val (tan (* 0.5d0 deta)))
             (alpha (* (sin deta) (/ (- (sqrt (+ 4.0d0 (* 3.0d0 t-val t-val))) 1.0d0) 3.0d0)))
             (steps-arr (loop for i from 0 to nseg
                              collect (+ eta1 (* i deta))))
             (cos-eta (mapcar #'cos steps-arr))
             (sin-eta (mapcar #'sin steps-arr)))
        ;; Build vertices
        (let* ((length (if is-wedge (+ (* nseg 3) 4) (+ (* nseg 3) 1)))
               (verts (make-array (list length 2) :element-type 'double-float
                                                  :initial-element 0.0d0))
               (codes (make-array length :element-type '(unsigned-byte 8)
                                         :initial-element +curve4+))
               (vertex-offset 0)
               (end length))
          (if is-wedge
              (progn
                (setf (aref verts 0 0) 0.0d0 (aref verts 0 1) 0.0d0)
                (setf (aref verts 1 0) (first cos-eta) (aref verts 1 1) (first sin-eta))
                (setf (aref codes 0) +moveto+ (aref codes 1) +lineto+)
                (setf (aref codes (- length 2)) +lineto+
                      (aref codes (- length 1)) +closepoly+)
                (setf vertex-offset 2 end (- length 2)))
              (progn
                (setf (aref verts 0 0) (first cos-eta)
                      (aref verts 0 1) (first sin-eta))
                (setf (aref codes 0) +moveto+)
                (setf vertex-offset 1 end length)))
          ;; Fill in Bézier control points
          (dotimes (seg nseg)
            (let* ((xa (nth seg cos-eta))
                   (ya (nth seg sin-eta))
                   (xa-dot (- ya))  ; derivative of cos = -sin
                   (ya-dot xa)      ; derivative of sin = cos
                   (xb (nth (1+ seg) cos-eta))
                   (yb (nth (1+ seg) sin-eta))
                   (xb-dot (- yb))
                   (yb-dot xb)
                   (idx (+ vertex-offset (* seg 3))))
              (when (< idx end)
                (setf (aref verts idx 0) (+ xa (* alpha xa-dot))
                      (aref verts idx 1) (+ ya (* alpha ya-dot))))
              (when (< (1+ idx) end)
                (setf (aref verts (1+ idx) 0) (- xb (* alpha xb-dot))
                      (aref verts (1+ idx) 1) (- yb (* alpha yb-dot))))
              (when (< (+ idx 2) end)
                (setf (aref verts (+ idx 2) 0) xb
                      (aref verts (+ idx 2) 1) yb))))
          (make-path :vertices verts :codes codes :readonly t))))))

(defun path-wedge (theta1 theta2 &key (n nil))
  "Return a Path for the unit circle wedge from THETA1 to THETA2 (degrees)."
  (path-arc theta1 theta2 :n n :is-wedge t))

(defun path-annular-wedge (theta1 theta2 &key (inner-radius 0.5d0) (n nil))
  "Return a Path for an annular (donut) wedge with unit outer radius.
INNER-RADIUS is the inner circle radius (0 < inner-radius < 1).
The path traces: outer arc (theta1->theta2), line to inner arc end,
inner arc reversed (theta2->theta1), close."
  (let* ((ir (float inner-radius 1.0d0))
         ;; Generate outer and inner arcs as simple arcs (not wedges)
         (outer-arc (path-arc theta1 theta2 :n n))
         (inner-arc (path-arc theta1 theta2 :n n))
         ;; Extract vertices
         (outer-v (mpl-path-vertices outer-arc))
         (outer-c (mpl-path-codes outer-arc))
         (outer-n (array-dimension outer-v 0))
         (inner-v (mpl-path-vertices inner-arc))
         (inner-n (array-dimension inner-v 0))
         ;; Total: outer arc + LINETO to inner end + reversed inner (minus start) + CLOSEPOLY
         (total (+ outer-n 1 (1- inner-n) 1))
         (verts (make-array (list total 2) :element-type 'double-float :initial-element 0.0d0))
         (codes (make-array total :element-type '(unsigned-byte 8) :initial-element +curve4+))
         (idx 0))
    ;; Copy outer arc vertices and codes
    (dotimes (i outer-n)
      (setf (aref verts idx 0) (aref outer-v i 0)
            (aref verts idx 1) (aref outer-v i 1)
            (aref codes idx) (aref outer-c i))
      (incf idx))
    ;; LINETO inner arc end (last vertex of inner arc, scaled by inner-radius)
    (let ((last-inner (1- inner-n)))
      (setf (aref verts idx 0) (* ir (aref inner-v last-inner 0))
            (aref verts idx 1) (* ir (aref inner-v last-inner 1))
            (aref codes idx) +lineto+)
      (incf idx))
    ;; Inner arc reversed (skip last vertex, already LINETO target)
    ;; Reversing cubic Bezier vertices reverses curve direction correctly
    (loop for i from (- inner-n 2) downto 0 do
      (setf (aref verts idx 0) (* ir (aref inner-v i 0))
            (aref verts idx 1) (* ir (aref inner-v i 1))
            (aref codes idx) +curve4+)
      (incf idx))
    ;; CLOSEPOLY
    (setf (aref verts idx 0) 0.0d0
          (aref verts idx 1) 0.0d0
          (aref codes idx) +closepoly+)
    (make-path :vertices verts :codes codes :readonly t)))

;;; ============================================================
;;; Path copy / deepcopy
;;; ============================================================

(defun path-copy (path)
  "Return a shallow copy of PATH."
  (%make-mpl-path :vertices (mpl-path-vertices path)
                  :codes (mpl-path-codes path)
                  :readonly nil
                  :should-simplify (mpl-path-should-simplify path)
                  :simplify-threshold (mpl-path-simplify-threshold path)
                  :interpolation-steps (mpl-path-interpolation-steps path)))

(defun path-deepcopy (path)
  "Return a deep copy of PATH. The copy is never readonly."
  (let* ((v (mpl-path-vertices path))
         (c (mpl-path-codes path))
         (n (array-dimension v 0))
         (new-v (make-array (list n 2) :element-type 'double-float))
         (new-c (when c (make-array (length c) :element-type '(unsigned-byte 8)))))
    (dotimes (i n)
      (setf (aref new-v i 0) (aref v i 0)
            (aref new-v i 1) (aref v i 1)))
    (when c
      (dotimes (i (length c))
        (setf (aref new-c i) (aref c i))))
    (%make-mpl-path :vertices new-v
                    :codes new-c
                    :readonly nil
                    :should-simplify (mpl-path-should-simplify path)
                    :simplify-threshold (mpl-path-simplify-threshold path)
                    :interpolation-steps (mpl-path-interpolation-steps path))))

;;; ============================================================
;;; Create closed path helper
;;; ============================================================

(defun path-create-closed (vertices-list)
  "Create a closed polygonal path going through VERTICES-LIST.
Unlike (make-path :closed t), this adds the closing vertex automatically."
  (let* ((n (length vertices-list))
         (closed-verts (append vertices-list (list (first vertices-list)))))
    (make-path :vertices closed-verts :closed t)))
