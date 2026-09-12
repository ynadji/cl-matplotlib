;;;; pick.lisp — hit testing in display space: which trace is under the
;;;; cursor, which data point is nearest, which legend entry was clicked.
;;;; Everything works on the pixel geometry of the last render (line
;;;; vertices through their transforms, legend entry boxes recorded at
;;;; draw time), so 2D and projected 3D artists are handled alike.

(in-package #:cl-matplotlib.show)

(defun %point-segment-distance (px py ax ay bx by)
  "Distance from (PX PY) to the segment A-B."
  (let* ((dx (- bx ax)) (dy (- by ay))
         (len2 (+ (* dx dx) (* dy dy))))
    (if (zerop len2)
        (sqrt (+ (expt (- px ax) 2) (expt (- py ay) 2)))
        (let* ((tt (max 0.0d0 (min 1.0d0 (/ (+ (* (- px ax) dx) (* (- py ay) dy)) len2))))
               (cx (+ ax (* tt dx))) (cy (+ ay (* tt dy))))
          (sqrt (+ (expt (- px cx) 2) (expt (- py cy) 2)))))))

(defun %pickable-lines (ax)
  "The visible line artists of AX, front-most first."
  (remove-if-not (lambda (a) (and (typep a 'mpl.rendering:line-2d)
                                  (mpl.rendering:artist-visible a)))
                 (reverse (append (mpl.containers:axes-base-lines ax)
                                  (mpl.containers:axes-base-artists ax)))))

(defun %line-distance (artist px py)
  "Smallest distance from the pixel to ARTIST's segments (or vertices,
when it has a single point), in display pixels; NIL when it has no points."
  (let ((pts (%artist-display-points artist)))
    (cond ((null pts) nil)
          ((null (cdr pts))
           (sqrt (+ (expt (- px (car (first pts))) 2) (expt (- py (cdr (first pts))) 2))))
          (t (loop for (a b) on pts while b
                   minimize (%point-segment-distance px py (car a) (cdr a) (car b) (cdr b)))))))

(defun interactor-pick (it x-px y-px &key radius-px)
  "The line under the pixel: the visible line of the axes under the
cursor whose path passes within RADIUS-PX (default: the line's pick
radius in points at the figure dpi). Returns (values artist axes), or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when ax
        (let* ((fig (interactor-figure it))
               (px (float x-px 1.0d0))
               (py (float (%figure-y it y-px) 1.0d0))
               (pts->px (/ (mpl.containers:figure-dpi fig) 72.0d0))
               (best nil) (best-d nil))
          (dolist (line (%pickable-lines ax))
            (let ((d (%line-distance line px py))
                  (r (or radius-px (* pts->px (mpl.rendering:line-2d-pickradius line)))))
              (when (and d (<= d r) (or (null best-d) (< d best-d)))
                (setf best line best-d d))))
          (when best (values best ax)))))))

(defun interactor-nearest-point (it x-px y-px &key (radius-px 10))
  "The data vertex nearest the pixel, within RADIUS-PX, over the visible
lines of the axes under the cursor. Returns (values artist index x y z
axes) — Z is NIL for a 2D line — or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((ax (%hit-axes it x-px y-px)))
      (when ax
        (let ((px (float x-px 1.0d0))
              (py (float (%figure-y it y-px) 1.0d0))
              (best nil) (best-i nil) (best-d radius-px))
          (dolist (line (%pickable-lines ax))
            (loop for (x . y) in (%artist-display-points line)
                  for i from 0
                  for d = (sqrt (+ (expt (- px x) 2) (expt (- py y) 2)))
                  when (< d best-d) do (setf best line best-i i best-d d)))
          (when best
            (multiple-value-bind (x y z) (%artist-data-point best best-i)
              (values best best-i x y z ax))))))))

(defun interactor-legend-hit (it x-px y-px)
  "The handle artist whose legend entry contains the pixel, or NIL.
Legend entry boxes are recorded by the legend's draw (display pixels)."
  (bt:with-lock-held ((%interactor-lock it))
    (%ensure-first-render it)
    (let ((px (float x-px 1.0d0))
          (py (float (%figure-y it y-px) 1.0d0)))
      (dolist (ax (reverse (mpl.containers:figure-axes (interactor-figure it))))
        (let ((leg (mpl.containers:axes-base-legend ax)))
          (when (and leg (mpl.rendering:artist-visible leg))
            (dolist (entry (mpl.containers:legend-entry-bboxes leg))
              (destructuring-bind (handle x0 y0 x1 y1) entry
                (when (and (<= x0 px x1) (<= y0 py y1))
                  (return-from interactor-legend-hit (values handle ax)))))))))))

(defun interactor-cursor-info (it x-px y-px)
  "What the coordinate readout should show for the pixel, as a plist:
(:x :y) for a 2D axes, plus (:label :index :px :py :z) when a data vertex
is within reach; NIL outside every axes."
  (let ((info nil))
    (multiple-value-bind (x y ax) (interactor-cursor-coords it x-px y-px)
      (when ax (setf info (list :x x :y y))))
    (multiple-value-bind (artist index x y z ax) (interactor-nearest-point it x-px y-px)
      (when artist
        (setf info (append info
                           (list :label (let ((l (mpl.rendering:artist-label artist)))
                                          (if (and l (plusp (length l))) l "trace"))
                                 :index index :px x :py y :z z)))
        (when (and (null (getf info :x)) ax)
          ;; a 3D axes: the readout is the vertex itself
          (setf info (append info (list :x x :y y))))))
    info))
