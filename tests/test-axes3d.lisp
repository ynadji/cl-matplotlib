;;;; test-axes3d.lisp — Tests for axes-3d (projection :3d), the 3D artists
;;;; and the 3D plotting functions.

(defpackage #:cl-matplotlib.tests.axes3d
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                #:axes-3d #:axis-3d #:add-subplot #:make-figure #:savefig #:subplots
                #:axes-get-xlim #:axes-get-ylim #:axes-get-zlim
                #:axes-set-xlim #:axes-set-zlim #:axes-base-view-lim #:axes-base-position
                #:axes-3d-elev #:axes-3d-azim #:axes-3d-roll #:axes-3d-proj-matrix
                #:axes-3d-zaxis #:axes-3d-get-proj #:view-init
                #:plot3d #:scatter3d #:plot-surface #:plot-trisurf #:bar3d
                #:axes-set-zlabel #:axes-base-artists #:axes-base-lines)
  (:export #:run-axes3d-tests))

(in-package #:cl-matplotlib.tests.axes3d)

(def-suite axes3d-suite :description "axes-3d test suite")
(in-suite axes3d-suite)

(defun %tmp (name ext) (format nil "/tmp/cl-mpl-test-3d-~A.~A" name ext))

(defun %3d-axes ()
  (let ((fig (make-figure)))
    (values (add-subplot fig 1 1 1 :projection :3d) fig)))

(defun %sinc-grid (n)
  (let ((x (make-array (list n n) :element-type 'double-float))
        (y (make-array (list n n) :element-type 'double-float))
        (z (make-array (list n n) :element-type 'double-float)))
    (dotimes (i n)
      (dotimes (j n)
        (let* ((xv (- (* 10.0d0 (/ j (1- n))) 5.0d0))
               (yv (- (* 10.0d0 (/ i (1- n))) 5.0d0))
               (r (sqrt (+ (* xv xv) (* yv yv)))))
          (setf (aref x i j) xv (aref y i j) yv
                (aref z i j) (if (zerop r) 1.0d0 (/ (sin r) r))))))
    (values x y z)))

(test creation-via-projection
  (multiple-value-bind (ax fig) (%3d-axes)
    (is (typep ax 'axes-3d))
    (is (member ax (cl-matplotlib.containers:figure-axes fig)))
    (is (typep (axes-3d-zaxis ax) 'axis-3d))
    ;; the 2D window is matplotlib's top view
    (let ((v (axes-base-view-lim ax)))
      (is (< (abs (- (cl-matplotlib.primitives:bbox-x0 v) -0.095d0)) 1d-12))
      (is (< (abs (- (cl-matplotlib.primitives:bbox-x1 v) 0.09d0)) 1d-12)))
    ;; default view
    (is (= 30.0d0 (axes-3d-elev ax)))
    (is (= -60.0d0 (axes-3d-azim ax)))
    (is (= 0.0d0 (axes-3d-roll ax)))))

(test subplots-projection-3d
  (let* ((axes (subplots (make-figure) 1 2 :projection :3d))
         (flat (if (arrayp axes)
                   (loop for i below (array-total-size axes) collect (row-major-aref axes i))
                   (if (listp axes) axes (list axes)))))
    (is (= 2 (length flat)))
    (is (every (lambda (a) (typep a 'axes-3d)) flat))))

(test limits-and-autoscale
  (let ((ax (%3d-axes)))
    (plot3d ax '(0 1 2) '(0 10 20) '(5 6 7))
    ;; data ± 5% margin, matplotlib's default 'data' autolimit mode
    (multiple-value-bind (lo hi) (axes-get-xlim ax)
      (is (< (abs (- lo -0.1d0)) 1d-9))
      (is (< (abs (- hi 2.1d0)) 1d-9)))
    (multiple-value-bind (lo hi) (axes-get-ylim ax)
      (is (< (abs (- lo -1.0d0)) 1d-9))
      (is (< (abs (- hi 21.0d0)) 1d-9)))
    ;; z has no margin on a 3D axes (Axes3D starts with zmargin 0)
    (multiple-value-bind (lo hi) (axes-get-zlim ax)
      (is (< (abs (- lo 5.0d0)) 1d-9))
      (is (< (abs (- hi 7.0d0)) 1d-9)))
    ;; explicit limits stick and turn autoscale off for that axis
    (axes-set-zlim ax :min 0 :max 10)
    (axes-set-xlim ax :min -5)
    (plot3d ax '(3) '(0) '(100))
    (is (equal (multiple-value-list (axes-get-zlim ax)) '(0.0d0 10.0d0)))
    (is (= -5.0d0 (axes-get-xlim ax)))
    ;; the 2D view window is untouched by 3D limits
    (is (< (abs (- (cl-matplotlib.primitives:bbox-x0 (axes-base-view-lim ax)) -0.095d0)) 1d-12))))

(test view-init-and-projection
  (let ((ax (%3d-axes)))
    (view-init ax :elev 20 :azim 45 :roll 20)
    (is (= 20.0d0 (axes-3d-elev ax)))
    (is (= 45.0d0 (axes-3d-azim ax)))
    (is (= 20.0d0 (axes-3d-roll ax)))
    ;; unit limits → the pinned matrix from test-proj3d
    (axes-set-xlim ax :min 0 :max 1)
    (cl-matplotlib.containers:axes-set-ylim ax :min 0 :max 1)
    (axes-set-zlim ax :min 0 :max 1)
    (let ((m (axes-3d-get-proj ax)))
      (is (< (abs (- (cl-matplotlib.primitives:mat4-ref m 0 0) -0.6648539947202956d0)) 1d-9))
      (is (< (abs (- (cl-matplotlib.primitives:mat4-ref m 3 3) 10.905966377153668d0)) 1d-9)))))

(test square-position-after-draw
  ;; Axes3D.apply_aspect: default 6.4x4.8 figure → [0.22375, 0.11, 0.5775, 0.77]
  (multiple-value-bind (ax fig) (%3d-axes)
    (plot3d ax '(0 1) '(0 1) '(0 1))
    (let ((out (%tmp "square" "png")))
      (savefig fig out)
      (when (probe-file out) (delete-file out)))
    (destructuring-bind (l b w h) (axes-base-position ax)
      (is (< (abs (- l 0.22375d0)) 1d-9))
      (is (< (abs (- b 0.11d0)) 1d-9))
      (is (< (abs (- w 0.5775d0)) 1d-9))
      (is (< (abs (- h 0.77d0)) 1d-9)))))

(test painter-order-for-surface
  ;; two horizontal squares: the higher one is nearer the default camera,
  ;; so after projection the lower one comes first in the verts list
  (let* ((ax (%3d-axes))
         (pc (make-instance 'cl-matplotlib.rendering:poly-3d-collection
                            :verts3d '(((0 0 1) (1 0 1) (1 1 1) (0 1 1))
                                       ((0 0 0) (1 0 0) (1 1 0) (0 1 0)))
                            :facecolors '("blue" "red"))))
    (cl-matplotlib.containers:axes-add-artist ax pc)
    (axes-set-xlim ax :min 0 :max 1)
    (cl-matplotlib.containers:axes-set-ylim ax :min 0 :max 1)
    (axes-set-zlim ax :min 0 :max 1)
    (let ((depth (cl-matplotlib.rendering:do-3d-projection pc (axes-3d-get-proj ax))))
      (is (numberp depth))
      ;; first drawn = red (z=0, farther)
      (is (< (abs (- (first (first (cl-matplotlib.rendering:collection-facecolors pc))) 1.0d0)) 1d-12))
      (is (= 2 (length (cl-matplotlib.rendering:poly-collection-verts pc)))))))

(test depthshade-monotone
  (let* ((ax (%3d-axes))
         (pc (scatter3d ax '(0 0.5 1) '(0 0.5 1) '(0 0.5 1) :c "black")))
    (cl-matplotlib.rendering:do-3d-projection pc (axes-3d-get-proj ax))
    (let ((alphas (mapcar #'fourth (cl-matplotlib.rendering:collection-facecolors pc))))
      ;; drawn back to front: alpha must not decrease along the draw order
      (is (apply #'<= alphas))
      (is (< (first alphas) (car (last alphas)))))))

(test surface-shading-and-cmap
  (multiple-value-bind (x y z) (%sinc-grid 12)
    (let* ((ax (%3d-axes))
           (shaded (plot-surface ax x y z :color "red"))
           (mapped (plot-surface ax x y z :cmap "viridis")))
      (cl-matplotlib.rendering:do-3d-projection shaded (axes-3d-get-proj ax))
      (cl-matplotlib.rendering:do-3d-projection mapped (axes-3d-get-proj ax))
      ;; 11x11 facets
      (is (= 121 (length (cl-matplotlib.rendering:poly-collection-verts shaded))))
      ;; shading keeps red hue but varies brightness across facets
      (let ((reds (mapcar #'first (cl-matplotlib.rendering:collection-facecolors shaded))))
        (is (every (lambda (c) (zerop (second c))) (cl-matplotlib.rendering:collection-facecolors shaded)))
        (is (> (- (reduce #'max reds) (reduce #'min reds)) 0.05d0)))
      ;; colormapped surface exposes a mappable for colorbar
      (is (cl-matplotlib.primitives:sm-cmap mapped))
      (is (cl-matplotlib.primitives:sm-norm mapped))
      (is (= 121 (length (cl-matplotlib.primitives:sm-array mapped)))))))

(test trisurf-and-bar3d
  (let* ((ax (%3d-axes))
         (tri (plot-trisurf ax '(0 1 0 1 0.5) '(0 0 1 1 0.5) '(0 1 1 0 2)))
         (bars (bar3d ax '(0 1 2) '(0 0 0) 0 0.5 0.5 '(1 2 3))))
    (cl-matplotlib.rendering:do-3d-projection tri (axes-3d-get-proj ax))
    (cl-matplotlib.rendering:do-3d-projection bars (axes-3d-get-proj ax))
    (is (plusp (length (cl-matplotlib.rendering:poly-collection-verts tri))))
    (is (every (lambda (p) (= 3 (length p))) (cl-matplotlib.rendering:poly-collection-verts tri)))
    ;; 3 bars × 6 faces
    (is (= 18 (length (cl-matplotlib.rendering:poly-collection-verts bars))))
    (multiple-value-bind (lo hi) (axes-get-zlim ax)
      (is (<= lo 0.0d0))
      (is (>= hi 3.0d0)))))

(test savefig-all-formats
  (multiple-value-bind (x y z) (%sinc-grid 10)
    (multiple-value-bind (ax fig) (%3d-axes)
      (plot-surface ax x y z :cmap "viridis")
      (plot3d ax '(-5 5) '(-5 5) '(0 1) :color "red")
      (scatter3d ax '(0 1) '(0 1) '(1 1))
      (axes-set-zlabel ax "z")
      (dolist (ext '("png" "svg" "pdf"))
        (let ((out (%tmp "formats" ext)))
          (finishes (savefig fig out))
          (is-true (probe-file out))
          (when (probe-file out) (delete-file out)))))))

(defun run-axes3d-tests ()
  "Run all axes-3d tests and report results."
  (let ((results (run 'axes3d-suite)))
    (explain! results)
    (unless (results-status results)
      (error "axes-3d tests failed!"))))
