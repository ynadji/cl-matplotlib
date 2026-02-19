;;;; marching-squares.lisp — Pure CL marching squares algorithm
;;;; Generates contour lines/filled regions from 2D scalar fields.
;;;; Replaces matplotlib's _contour.cpp C extension.
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Marching Squares — contour line generation
;;; ============================================================
;;;
;;; Algorithm overview:
;;; 1. For each grid cell (2x2 corners), classify corners as above/below level
;;; 2. Encode as 4-bit case index (0-15)
;;; 3. Look up edge crossings from case table
;;; 4. Interpolate crossing positions along edges
;;; 5. Connect segments into continuous paths
;;;
;;; Edge numbering:
;;;   Corner: 0=BL 1=BR 2=TR 3=TL  (bottom-left, etc.)
;;;   Edge:   0=bottom 1=right 2=top 3=left

;;; ============================================================
;;; Edge crossing lookup table
;;; ============================================================

(defparameter *ms-edge-table*
  ;; Each entry is a list of edge pairs: ((edge-a edge-b) ...)
  ;; Edge 0=bottom, 1=right, 2=top, 3=left
  ;; Case index = bit0*BL + bit1*BR + bit2*TR + bit3*TL
  ;; where bit=1 means corner >= level
  #(()               ; 0:  all below
    ((3 0))           ; 1:  BL above
    ((0 1))           ; 2:  BR above
    ((3 1))           ; 3:  BL+BR above
    ((1 2))           ; 4:  TR above
    ((3 0) (1 2))     ; 5:  BL+TR above (saddle)
    ((0 2))           ; 6:  BR+TR above
    ((3 2))           ; 7:  BL+BR+TR above
    ((2 3))           ; 8:  TL above
    ((2 0))           ; 9:  BL+TL above
    ((0 1) (2 3))     ; 10: BR+TL above (saddle)
    ((2 1))           ; 11: BL+BR+TL above
    ((1 3))           ; 12: TR+TL above
    ((1 0))           ; 13: BL+TR+TL above
    ((0 3))           ; 14: BR+TR+TL above
    ())               ; 15: all above
  "Edge crossing table for marching squares.
Each entry maps a 4-bit case to line segments connecting edges.")

;;; ============================================================
;;; Interpolation along cell edges
;;; ============================================================

(defun %ms-interpolate-edge (edge x0 y0 x1 y1 z-bl z-br z-tr z-tl level)
  "Compute the (x y) position where the contour crosses EDGE.
EDGE: 0=bottom, 1=right, 2=top, 3=left.
x0,y0 = bottom-left corner position.
x1,y1 = top-right corner position."
  (declare (type double-float x0 y0 x1 y1 z-bl z-br z-tr z-tl level))
  (flet ((lerp (a b za zb)
           ;; Linear interpolation: find t where za + t*(zb-za) = level
           (if (= za zb)
               (* 0.5d0 (+ a b))
               (+ a (* (/ (- level za) (- zb za)) (- b a))))))
    (ecase edge
      (0 ;; bottom edge: BL→BR, y=y0
       (list (lerp x0 x1 z-bl z-br) y0))
      (1 ;; right edge: BR→TR, x=x1
       (list x1 (lerp y0 y1 z-br z-tr)))
      (2 ;; top edge: TL→TR, y=y1
       (list (lerp x0 x1 z-tl z-tr) y1))
      (3 ;; left edge: BL→TL, x=x0
       (list x0 (lerp y0 y1 z-bl z-tl))))))

;;; ============================================================
;;; Saddle point disambiguation
;;; ============================================================

(defun %ms-disambiguate-saddle (z-bl z-br z-tr z-tl level)
  "Disambiguate saddle cases (5 and 10) using center value.
Returns T if center is above level (use non-default connection)."
  (let ((center (* 0.25d0 (+ z-bl z-br z-tr z-tl))))
    (>= center level)))

;;; ============================================================
;;; Single-level contour extraction
;;; ============================================================

(defun %ms-classify-cell (z-bl z-br z-tr z-tl level)
  "Classify a cell's corners relative to LEVEL. Returns 4-bit case index."
  (declare (type double-float z-bl z-br z-tr z-tl level))
  (logior (if (>= z-bl level) 1 0)
          (if (>= z-br level) 2 0)
          (if (>= z-tr level) 4 0)
          (if (>= z-tl level) 8 0)))

(defun marching-squares-single-level (x-coords y-coords z-data level)
  "Extract contour line segments at LEVEL from the scalar field Z-DATA.

X-COORDS — 1D sequence of X positions (length NX).
Y-COORDS — 1D sequence of Y positions (length NY).
Z-DATA — 2D array (NY x NX) of scalar values.
LEVEL — contour level value.

Returns a list of segments, where each segment is a list of (x y) points
forming a connected contour path."
  (let* ((nx (length x-coords))
         (ny (length y-coords))
         (raw-segments nil))
    ;; Phase 1: Generate raw edge-crossing segments
    (loop for j from 0 below (1- ny) do
      (loop for i from 0 below (1- nx) do
        (let* ((x0 (float (elt x-coords i) 1.0d0))
               (x1 (float (elt x-coords (1+ i)) 1.0d0))
               (y0 (float (elt y-coords j) 1.0d0))
               (y1 (float (elt y-coords (1+ j)) 1.0d0))
               (z-bl (float (aref z-data j i) 1.0d0))
               (z-br (float (aref z-data j (1+ i)) 1.0d0))
               (z-tr (float (aref z-data (1+ j) (1+ i)) 1.0d0))
               (z-tl (float (aref z-data (1+ j) i) 1.0d0))
               (case-idx (%ms-classify-cell z-bl z-br z-tr z-tl level)))
          ;; Handle saddle cases by potentially swapping segments
          (let ((edges (aref *ms-edge-table* case-idx)))
            ;; For saddle cases 5 and 10, disambiguate
            (when (and (member case-idx '(5 10))
                       (%ms-disambiguate-saddle z-bl z-br z-tr z-tl level))
              ;; Swap the connections
              (setf edges (if (= case-idx 5)
                              '((3 2) (1 0))    ; alternative for case 5
                              '((0 3) (2 1))))) ; alternative for case 10
            ;; Generate segments from edge pairs
            (dolist (edge-pair edges)
              (let ((p1 (%ms-interpolate-edge
                         (first edge-pair) x0 y0 x1 y1
                         z-bl z-br z-tr z-tl level))
                    (p2 (%ms-interpolate-edge
                         (second edge-pair) x0 y0 x1 y1
                         z-bl z-br z-tr z-tl level)))
                (push (list p1 p2) raw-segments)))))))
    ;; Phase 2: Connect raw segments into continuous paths
    (%ms-connect-segments (nreverse raw-segments))))

;;; ============================================================
;;; Segment connectivity — join raw segments into paths
;;; ============================================================

(defun %ms-point-equal-p (p1 p2 &optional (tol 1.0d-10))
  "Check if two points are approximately equal."
  (and (< (abs (- (first p1) (first p2))) tol)
       (< (abs (- (second p1) (second p2))) tol)))

(defun %ms-connect-segments (segments)
  "Connect raw line segments into continuous polyline paths.
Each segment is ((x1 y1) (x2 y2)). Returns list of paths,
where each path is a list of (x y) points."
  (when (null segments)
    (return-from %ms-connect-segments nil))
  (let ((remaining (copy-list segments))
        (paths nil))
    (loop while remaining do
      ;; Start a new path with the first remaining segment
      (let* ((seg (pop remaining))
             (path (list (first seg) (second seg)))
             (changed t))
        ;; Keep extending the path in both directions
        (loop while (and changed remaining) do
          (setf changed nil)
          (let ((new-remaining nil))
            (dolist (s remaining)
              (let ((s-start (first s))
                    (s-end (second s))
                    (path-start (first path))
                    (path-end (car (last path))))
                (cond
                  ;; s-start matches path-end → extend forward
                  ((%ms-point-equal-p s-start path-end)
                   (setf path (append path (list s-end)))
                   (setf changed t))
                  ;; s-end matches path-end → extend forward (reversed)
                  ((%ms-point-equal-p s-end path-end)
                   (setf path (append path (list s-start)))
                   (setf changed t))
                  ;; s-end matches path-start → prepend
                  ((%ms-point-equal-p s-end path-start)
                   (setf path (cons s-start path))
                   (setf changed t))
                  ;; s-start matches path-start → prepend (reversed)
                  ((%ms-point-equal-p s-start path-start)
                   (setf path (cons s-end path))
                   (setf changed t))
                  ;; No match — keep for later
                  (t (push s new-remaining)))))
            (setf remaining (nreverse new-remaining))))
        (push path paths)))
    (nreverse paths)))

;;; ============================================================
;;; Multi-level contour extraction
;;; ============================================================

(defun marching-squares-levels (x-coords y-coords z-data levels)
  "Extract contour paths for multiple levels.
Returns a list of (level . paths) pairs, one per level."
  (mapcar (lambda (level)
            (cons (float level 1.0d0)
                  (marching-squares-single-level x-coords y-coords z-data
                                                 (float level 1.0d0))))
          levels))

;;; ============================================================
;;; Filled contour extraction (for contourf)
;;; ============================================================

(defun %ms-classify-cell-band (z-bl z-br z-tr z-tl lo hi)
  "For filled contours: classify corners as below-lo (0), in-band (1), above-hi (2).
Returns list of per-corner classifications."
  (flet ((classify (z)
           (cond ((< z lo) 0)
                 ((> z hi) 2)
                 (t 1))))
    (list (classify z-bl) (classify z-br)
          (classify z-tr) (classify z-tl))))

(defun marching-squares-filled (x-coords y-coords z-data level-lo level-hi)
  "Extract filled contour polygons for the band between LEVEL-LO and LEVEL-HI.

Returns a list of polygon vertex lists, where each polygon is a list
of (x y) points forming a closed region between the two levels.

Uses a simplified approach: generates the boundary contour at each level
and constructs filled regions from the grid cells that fall within the band."
  (let* ((nx (length x-coords))
         (ny (length y-coords))
         (polygons nil))
    ;; For each grid cell, check if it overlaps the band
    (loop for j from 0 below (1- ny) do
      (loop for i from 0 below (1- nx) do
        (let* ((x0 (float (elt x-coords i) 1.0d0))
               (x1 (float (elt x-coords (1+ i)) 1.0d0))
               (y0 (float (elt y-coords j) 1.0d0))
               (y1 (float (elt y-coords (1+ j)) 1.0d0))
               (z-bl (float (aref z-data j i) 1.0d0))
               (z-br (float (aref z-data j (1+ i)) 1.0d0))
               (z-tr (float (aref z-data (1+ j) (1+ i)) 1.0d0))
               (z-tl (float (aref z-data (1+ j) i) 1.0d0))
               (lo (float level-lo 1.0d0))
               (hi (float level-hi 1.0d0))
               (zmin (min z-bl z-br z-tr z-tl))
               (zmax (max z-bl z-br z-tr z-tl)))
          ;; Skip cells entirely outside the band
          (unless (or (> zmin hi) (< zmax lo))
            ;; Build polygon from clipped cell corners + edge crossings
            (let ((poly (%ms-cell-band-polygon
                         x0 y0 x1 y1 z-bl z-br z-tr z-tl lo hi)))
              (when (and poly (>= (length poly) 3))
                (push poly polygons)))))))
    (nreverse polygons)))

(defun %ms-cell-band-polygon (x0 y0 x1 y1 z-bl z-br z-tr z-tl lo hi)
  "Compute the polygon for a single cell clipped to the band [lo, hi].
Walks around the cell boundary, including corner points that are in-band
and interpolated crossing points where the contour crosses edges."
  (declare (type double-float x0 y0 x1 y1 z-bl z-br z-tr z-tl lo hi))
  (let ((points nil)
        ;; Corners in CCW order: BL, BR, TR, TL
        (corners (list (list x0 y0 z-bl)    ; BL = corner 0
                       (list x1 y0 z-br)    ; BR = corner 1
                       (list x1 y1 z-tr)    ; TR = corner 2
                       (list x0 y1 z-tl)))  ; TL = corner 3
        ;; Edge endpoints (corner indices):
        ;; edge 0: BL→BR, edge 1: BR→TR, edge 2: TR→TL, edge 3: TL→BL
        (edge-corners '((0 1) (1 2) (2 3) (3 0))))
    ;; Walk around the cell boundary
    (loop for (ci cj) in edge-corners
          for c-start = (nth ci corners)
          for c-end = (nth cj corners)
          for zs = (third c-start)
          for ze = (third c-end)
          do
             ;; Add start corner if it's in-band
             (when (and (>= zs lo) (<= zs hi))
               (push (list (first c-start) (second c-start)) points))
             ;; Add crossing with lo contour if edge crosses lo
             (when (or (and (< zs lo) (> ze lo))
                       (and (> zs lo) (< ze lo)))
               (let ((t-val (/ (- lo zs) (- ze zs))))
                 (push (list (+ (first c-start)
                                (* t-val (- (first c-end) (first c-start))))
                             (+ (second c-start)
                                (* t-val (- (second c-end) (second c-start)))))
                       points)))
             ;; Add crossing with hi contour if edge crosses hi
             (when (or (and (< zs hi) (> ze hi))
                       (and (> zs hi) (< ze hi)))
               (let ((t-val (/ (- hi zs) (- ze zs))))
                 (push (list (+ (first c-start)
                                (* t-val (- (first c-end) (first c-start))))
                             (+ (second c-start)
                                (* t-val (- (second c-end) (second c-start)))))
                       points))))
    ;; Remove duplicates and return
    (let ((result (nreverse points)))
      (when (and result (>= (length result) 3))
        result))))

;;; ============================================================
;;; Auto level selection
;;; ============================================================

(defun %nice-steps-for-range (data-range n)
  "Return candidate nice step sizes for DATA-RANGE targeting ~N levels.
Tries steps of the form k × 10^m for k in {1, 1.5, 2, 2.5, 5} and
picks the one that produces the closest to N levels."
  (let* ((magnitude (expt 10.0d0 (floor (log (/ data-range (float n 1.0d0)) 10.0d0))))
         (candidates (list (* 1.0d0 magnitude)
                           (* 1.5d0 magnitude)
                           (* 2.0d0 magnitude)
                           (* 2.5d0 magnitude)
                           (* 5.0d0 magnitude)
                           (* 1.0d0 magnitude 10.0d0)))
         (best-step (first candidates))
         (best-diff most-positive-fixnum))
    (dolist (step candidates)
      (let* ((first-level (* step (ceiling 0.0d0 step)))
             (count 0))
        (loop for level = first-level then (+ level step)
              while (<= level (+ data-range (* 0.5d0 step)))
              do (incf count))
        (let ((diff (abs (- count n))))
          (when (< diff best-diff)
            (setf best-diff diff
                  best-step step)))))
    best-step))

(defun auto-select-levels (zmin zmax &optional (n 7))
  "Auto-select N contour levels spanning [ZMIN, ZMAX].
Uses 'nice' step sizes (like matplotlib's MaxNLocator) to produce
visually clean level values.
Returns a list of level values."
  (when (= zmin zmax)
    (return-from auto-select-levels (list zmin)))
  (let* ((data-range (- zmax zmin))
         ;; Find a nice step that produces ~n levels
         (step (%nice-steps-for-range data-range n))
         ;; First level: smallest multiple of step >= zmin
         (first-level (* step (ceiling zmin step)))
         ;; Collect levels within [zmin - 0.5*step, zmax + 0.5*step]
         (levels nil))
    ;; Generate levels from first-level upward
    (loop for level = first-level then (+ level step)
          while (<= level (+ zmax (* 0.5d0 step)))
          do (push level levels))
    (if levels
        (nreverse levels)
        ;; Fallback: simple linear spacing
        (let ((s (/ data-range (float (1+ n) 1.0d0))))
          (loop for i from 1 to n
                collect (+ zmin (* i s)))))))

(defun auto-select-levels-filled (zmin zmax &optional (n 7))
  "Auto-select N+1 boundary levels for filled contours spanning [ZMIN, ZMAX].
Returns a list of N+1 evenly-spaced boundary values."
  (when (= zmin zmax)
    (return-from auto-select-levels-filled (list zmin zmax)))
  (let ((step (/ (- zmax zmin) (float n 1.0d0))))
    (loop for i from 0 to n
          collect (+ zmin (* i step)))))
