;;;; delaunay.lisp — Bowyer-Watson Delaunay triangulation for the tri*
;;;; plot family. Point count is plot-scale (hundreds), so the simple
;;;; O(n^2)-ish incremental algorithm is plenty.
;;;;
;;;; Degeneracies: the in-circumcircle predicate uses a relative epsilon;
;;;; on exactly co-circular points (regular grids) the diagonal choice may
;;;; differ from Qhull's (matplotlib). That changes triangle edges, not
;;;; the covered area — invisible for tripcolor/tricontour.

(in-package #:cl-matplotlib.containers)

(defstruct (triangulation (:constructor %make-triangulation (x y triangles)))
  "Triangulation of points (X[i], Y[i]) into index triples TRIANGLES."
  x y triangles)

(defun %circumcircle (ax ay bx by cx cy)
  "(values ccx ccy r2) of the circumcircle of triangle ABC, or NIL for
degenerate (collinear) triangles."
  (let ((d (* 2.0d0 (+ (* ax (- by cy)) (* bx (- cy ay)) (* cx (- ay by))))))
    (when (> (abs d) 1d-12)
      (let* ((a2 (+ (* ax ax) (* ay ay)))
             (b2 (+ (* bx bx) (* by by)))
             (c2 (+ (* cx cx) (* cy cy)))
             (ux (/ (+ (* a2 (- by cy)) (* b2 (- cy ay)) (* c2 (- ay by))) d))
             (uy (/ (+ (* a2 (- cx bx)) (* b2 (- ax cx)) (* c2 (- bx ax))) d)))
        (values ux uy (+ (expt (- ax ux) 2) (expt (- ay uy) 2)))))))

(defun delaunay-triangulate (xs ys)
  "Bowyer-Watson Delaunay triangulation of the points (XS[i], YS[i]).
Returns a list of (i j k) index triples."
  (let* ((n (length xs))
         (px (map 'vector (lambda (v) (float v 1.0d0)) xs))
         (py (map 'vector (lambda (v) (float v 1.0d0)) ys)))
    (when (< n 3)
      (return-from delaunay-triangulate '()))
    ;; super-triangle enclosing all points
    (let* ((xmin (reduce #'min px)) (xmax (reduce #'max px))
           (ymin (reduce #'min py)) (ymax (reduce #'max py))
           (dmax (max (- xmax xmin) (- ymax ymin) 1d-9))
           (midx (/ (+ xmin xmax) 2.0d0))
           (midy (/ (+ ymin ymax) 2.0d0))
           ;; super vertices get indices n, n+1, n+2
           (sx (vector (- midx (* 20.0d0 dmax)) midx (+ midx (* 20.0d0 dmax))))
           (sy (vector (- midy dmax) (+ midy (* 20.0d0 dmax)) (- midy dmax)))
           (all-x (concatenate 'vector px sx))
           (all-y (concatenate 'vector py sy))
           ;; triangle entries: (i j k ccx ccy r2)
           (triangles (list (multiple-value-bind (cx cy r2)
                                (%circumcircle (aref all-x n) (aref all-y n)
                                               (aref all-x (+ n 1))
                                               (aref all-y (+ n 1))
                                               (aref all-x (+ n 2))
                                               (aref all-y (+ n 2)))
                              (list n (+ n 1) (+ n 2) cx cy r2)))))
      (flet ((in-circumcircle-p (tri x y)
               (destructuring-bind (i j k cx cy r2) tri
                 (declare (ignore i j k))
                 (and cx
                      (< (+ (expt (- x cx) 2) (expt (- y cy) 2))
                         (* r2 (+ 1.0d0 1d-12)))))))
        (dotimes (p n)
          (let* ((x (aref all-x p)) (y (aref all-y p))
                 (bad '()) (good '()))
            (dolist (tri triangles)
              (if (in-circumcircle-p tri x y)
                  (push tri bad)
                  (push tri good)))
            ;; boundary of the cavity: edges of bad triangles that are
            ;; not shared between two bad triangles
            (let ((edge-counts (make-hash-table :test #'equal)))
              (dolist (tri bad)
                (destructuring-bind (i j k cx cy r2) tri
                  (declare (ignore cx cy r2))
                  (dolist (e (list (if (< i j) (list i j) (list j i))
                                   (if (< j k) (list j k) (list k j))
                                   (if (< i k) (list i k) (list k i))))
                    (incf (gethash e edge-counts 0)))))
              (let ((new-tris '()))
                (maphash (lambda (e count)
                           (when (= count 1)
                             (destructuring-bind (i j) e
                               (multiple-value-bind (cx cy r2)
                                   (%circumcircle (aref all-x i) (aref all-y i)
                                                  (aref all-x j) (aref all-y j)
                                                  x y)
                                 (push (list i j p cx cy r2) new-tris)))))
                         edge-counts)
                (setf triangles (nconc new-tris good))))))
        ;; drop triangles touching the super vertices
        (loop for (i j k) in triangles
              when (and (< i n) (< j n) (< k n))
                collect (list i j k))))))

(defun ensure-triangulation (x y &optional triangles)
  "A triangulation struct from points and optional explicit TRIANGLES
(sequence of (i j k)); computes Delaunay when TRIANGLES is NIL."
  (%make-triangulation
   (map 'vector (lambda (v) (float v 1.0d0)) x)
   (map 'vector (lambda (v) (float v 1.0d0)) y)
   (if triangles
       (map 'list (lambda (tri) (coerce tri 'list)) triangles)
       (delaunay-triangulate x y))))
