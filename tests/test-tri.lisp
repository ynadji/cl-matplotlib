;;;; test-tri.lisp — Delaunay triangulation + tri* plot types.

(defpackage #:cl-matplotlib.tests.tri
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                #:delaunay-triangulate #:ensure-triangulation
                #:triangulation-triangles
                #:make-figure #:add-subplot
                #:triplot #:tripcolor #:tricontour #:tricontourf)
  (:export #:run-tri-tests))

(in-package #:cl-matplotlib.tests.tri)

(def-suite tri-suite :description "Triangulation machinery")
(in-suite tri-suite)

(test delaunay-square
  ;; four corners triangulate into exactly two triangles
  (let ((tris (delaunay-triangulate '(0.0 1.0 1.0 0.0) '(0.0 0.0 1.0 1.0))))
    (is (= 2 (length tris)))))

(test delaunay-triangle-count
  ;; interior-rich point set: 2n - 2 - h triangles for h hull points;
  ;; verify against the Euler bound and empty-circumcircle spot checks
  (let* ((n 30)
         (xs (loop for i from 0 below n
                   collect (* (/ (mod (* i 37) 97) 97.0d0) 10.0d0)))
         (ys (loop for i from 0 below n
                   collect (* (/ (mod (* i 53) 89) 89.0d0) 8.0d0)))
         (tris (delaunay-triangulate xs ys)))
    (is (>= (length tris) (- n 2)))
    (is (<= (length tris) (- (* 2 n) 5)))
    ;; empty circumcircle: no point strictly inside any triangle's circle
    (let ((px (coerce xs 'vector)) (py (coerce ys 'vector)))
      (loop for (i j k) in (subseq tris 0 (min 10 (length tris)))
            do (multiple-value-bind (cx cy r2)
                   (cl-matplotlib.containers::%circumcircle
                    (aref px i) (aref py i) (aref px j) (aref py j)
                    (aref px k) (aref py k))
                 (when cx
                   (dotimes (p (length px))
                     (unless (member p (list i j k))
                       (is (>= (+ (expt (- (aref px p) cx) 2)
                                  (expt (- (aref py p) cy) 2))
                               (* r2 (- 1.0d0 1d-9))))))))))))

(test explicit-triangles-respected
  (let ((tri (ensure-triangulation '(0 1 0.5) '(0 0 1) '((0 1 2)))))
    (is (equal '((0 1 2)) (triangulation-triangles tri)))))

(test tri-plots-render
  (let* ((n 25)
         (xs (loop for i from 0 below n
                   collect (* (/ (mod (* i 37) 97) 97.0d0) 10.0d0)))
         (ys (loop for i from 0 below n
                   collect (* (/ (mod (* i 53) 89) 89.0d0) 8.0d0)))
         (zs (mapcar (lambda (x y) (* (sin x) (cos y))) xs ys)))
    (let* ((fig (make-figure)) (ax (add-subplot fig 1 1 1)))
      (finishes (triplot ax xs ys)))
    (let* ((fig (make-figure)) (ax (add-subplot fig 1 1 1)))
      (finishes (tripcolor ax xs ys zs)))
    (let* ((fig (make-figure)) (ax (add-subplot fig 1 1 1)))
      (finishes (tricontour ax xs ys zs :n-levels 5)))
    (let* ((fig (make-figure)) (ax (add-subplot fig 1 1 1)))
      (finishes (tricontourf ax xs ys zs :n-levels 5)))))

(defun run-tri-tests ()
  (let ((results (run 'tri-suite)))
    (explain! results)
    (unless (results-status results)
      (error "tri tests failed"))
    results))
