;;;; test-image.lisp — Tests for image display (imshow) and interpolation
;;;; Phase 5e — FiveAM test suite

(defpackage #:cl-matplotlib.tests.image
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rendering
                ;; AxesImage class
                #:axes-image #:image-data #:image-extent #:image-interpolation
                #:image-origin #:image-cmap #:image-norm #:image-vmin #:image-vmax
                #:image-aspect
                #:image-shape #:image-rows #:image-cols
                #:*interpolation-methods*
                ;; Interpolation
                #:interpolate-nearest #:interpolate-bilinear
                #:interpolate-nearest-rgba #:interpolate-bilinear-rgba
                ;; Artist protocol
                #:artist-alpha #:artist-visible #:artist-stale #:artist-zorder
                #:artist-transform)
  (:import-from #:cl-matplotlib.containers
                ;; Axes / Figure
                #:mpl-axes #:axes-base
                #:add-subplot #:axes-get-xlim #:axes-get-ylim
                #:axes-base-images
                ;; Figure
                #:mpl-figure #:make-figure #:savefig
                ;; imshow
                #:imshow #:axes-add-image)
  (:import-from #:cl-matplotlib.primitives
                ;; Colormap
                #:colormap #:get-colormap #:colormap-call
                ;; Normalize
                #:normalize #:make-normalize #:normalize-call
                #:norm-vmin #:norm-vmax)
  (:export #:run-image-tests))

(in-package #:cl-matplotlib.tests.image)

(def-suite image-suite :description "Image display and interpolation test suite")
(in-suite image-suite)

;;; ============================================================
;;; Test helpers
;;; ============================================================

(defun make-2d-array (h w &optional (init-fn (lambda (i j) (declare (ignore i j)) 0.0d0)))
  "Create an H×W double-float array, filling with INIT-FN(i, j)."
  (let ((arr (make-array (list h w) :element-type 'double-float :initial-element 0.0d0)))
    (dotimes (i h arr)
      (dotimes (j w)
        (setf (aref arr i j) (float (funcall init-fn i j) 1.0d0))))))

(defun make-3d-array (h w c &optional (init-fn (lambda (i j k) (declare (ignore i j k)) 0.0d0)))
  "Create an H×W×C double-float array."
  (let ((arr (make-array (list h w c) :element-type 'double-float :initial-element 0.0d0)))
    (dotimes (i h arr)
      (dotimes (j w)
        (dotimes (k c)
          (setf (aref arr i j k) (float (funcall init-fn i j k) 1.0d0)))))))

(defun make-test-axes ()
  "Create a figure + axes for testing."
  (let ((fig (make-figure)))
    (add-subplot fig 1 1 1)))

(defun approx= (a b &optional (eps 1.0d-6))
  "Approximate float equality."
  (< (abs (- a b)) eps))

;;; ============================================================
;;; AxesImage class tests
;;; ============================================================

(test axes-image-creation
  "Test basic AxesImage creation."
  (let ((img (make-instance 'axes-image)))
    (is (null (image-data img)))
    (is (null (image-extent img)))
    (is (eq :nearest (image-interpolation img)))
    (is (eq :upper (image-origin img)))
    (is (null (image-cmap img)))
    (is (null (image-norm img)))
    (is (null (image-vmin img)))
    (is (null (image-vmax img)))
    (is (eq :auto (image-aspect img)))
    (is (= 0 (artist-zorder img)))))

(test axes-image-with-data
  "Test AxesImage creation with 2D data."
  (let* ((data (make-2d-array 10 20))
         (img (make-instance 'axes-image :data data)))
    (is (eq data (image-data img)))
    (is (equal '(10 20) (image-shape img)))
    (is (= 10 (image-rows img)))
    (is (= 20 (image-cols img)))))

(test axes-image-with-3d-data
  "Test AxesImage creation with 3D RGB data."
  (let* ((data (make-3d-array 10 20 3))
         (img (make-instance 'axes-image :data data)))
    (is (equal '(10 20 3) (image-shape img)))
    (is (= 10 (image-rows img)))
    (is (= 20 (image-cols img)))))

(test axes-image-with-rgba-data
  "Test AxesImage creation with 4-channel RGBA data."
  (let* ((data (make-3d-array 8 12 4))
         (img (make-instance 'axes-image :data data)))
    (is (equal '(8 12 4) (image-shape img)))
    (is (= 8 (image-rows img)))
    (is (= 12 (image-cols img)))))

(test axes-image-properties
  "Test AxesImage with custom properties."
  (let ((img (make-instance 'axes-image
                             :interpolation :bilinear
                             :origin :lower
                             :extent '(0.0 10.0 0.0 5.0)
                             :aspect :equal
                             :vmin 0.0
                             :vmax 1.0)))
    (is (eq :bilinear (image-interpolation img)))
    (is (eq :lower (image-origin img)))
    (is (equal '(0.0 10.0 0.0 5.0) (image-extent img)))
    (is (eq :equal (image-aspect img)))
    (is (= 0.0 (image-vmin img)))
    (is (= 1.0 (image-vmax img)))))

(test axes-image-no-data-shape
  "Test image-shape/rows/cols with no data."
  (let ((img (make-instance 'axes-image)))
    (is (null (image-shape img)))
    (is (null (image-rows img)))
    (is (null (image-cols img)))))

;;; ============================================================
;;; Nearest-neighbor interpolation tests
;;; ============================================================

(test nearest-identity
  "Test nearest-neighbor interpolation with same size (identity)."
  (let* ((data (make-2d-array 4 4 (lambda (i j) (+ (* i 4.0) j))))
         (result (interpolate-nearest data 4 4)))
    (is (equal '(4 4) (array-dimensions result)))
    (dotimes (i 4)
      (dotimes (j 4)
        (is (approx= (aref data i j) (aref result i j)))))))

(test nearest-upscale
  "Test nearest-neighbor upscaling 2×2 → 4×4."
  (let* ((data (make-2d-array 2 2 (lambda (i j)
                                     (cond ((and (= i 0) (= j 0)) 1.0)
                                           ((and (= i 0) (= j 1)) 2.0)
                                           ((and (= i 1) (= j 0)) 3.0)
                                           (t 4.0)))))
         (result (interpolate-nearest data 4 4)))
    (is (equal '(4 4) (array-dimensions result)))
    ;; Top-left quadrant should be 1.0
    (is (approx= 1.0d0 (aref result 0 0)))
    (is (approx= 1.0d0 (aref result 0 1)))
    ;; Top-right quadrant should be 2.0
    (is (approx= 2.0d0 (aref result 0 2)))
    (is (approx= 2.0d0 (aref result 0 3)))
    ;; Bottom-left quadrant should be 3.0
    (is (approx= 3.0d0 (aref result 2 0)))
    (is (approx= 3.0d0 (aref result 3 0)))
    ;; Bottom-right quadrant should be 4.0
    (is (approx= 4.0d0 (aref result 2 2)))
    (is (approx= 4.0d0 (aref result 3 3)))))

(test nearest-downscale
  "Test nearest-neighbor downscaling 4×4 → 2×2."
  (let* ((data (make-2d-array 4 4 (lambda (i j)
                                     (float (+ (* i 4) j) 1.0d0))))
         (result (interpolate-nearest data 2 2)))
    (is (equal '(2 2) (array-dimensions result)))
    ;; Each output pixel samples from center of its corresponding 2x2 block
    (is (numberp (aref result 0 0)))
    (is (numberp (aref result 1 1)))))

(test nearest-asymmetric
  "Test nearest-neighbor with non-square dimensions."
  (let* ((data (make-2d-array 3 6 (lambda (i j) (float (* i j) 1.0d0))))
         (result (interpolate-nearest data 6 12)))
    (is (equal '(6 12) (array-dimensions result)))))

(test nearest-rgba
  "Test nearest-neighbor RGBA interpolation."
  (let* ((data (make-3d-array 2 2 4
                              (lambda (i j c)
                                (float (+ (* i 8) (* j 4) c) 1.0d0))))
         (result (interpolate-nearest-rgba data 4 4)))
    (is (equal '(4 4 4) (array-dimensions result)))
    ;; Check corners replicated correctly
    (dotimes (c 4)
      (is (approx= (aref data 0 0 c) (aref result 0 0 c))))))

;;; ============================================================
;;; Bilinear interpolation tests
;;; ============================================================

(test bilinear-identity
  "Test bilinear interpolation with same size (identity)."
  (let* ((data (make-2d-array 4 4 (lambda (i j)
                                     (float (+ (* i 4) j) 1.0d0))))
         (result (interpolate-bilinear data 4 4)))
    (is (equal '(4 4) (array-dimensions result)))
    (dotimes (i 4)
      (dotimes (j 4)
        (is (approx= (aref data i j) (aref result i j) 0.01d0))))))

(test bilinear-upscale
  "Test bilinear upscaling produces smooth interpolation."
  (let* ((data (make-2d-array 2 2 (lambda (i j)
                                     (cond ((and (= i 0) (= j 0)) 0.0)
                                           ((and (= i 0) (= j 1)) 1.0)
                                           ((and (= i 1) (= j 0)) 1.0)
                                           (t 2.0)))))
         (result (interpolate-bilinear data 3 3)))
    (is (equal '(3 3) (array-dimensions result)))
    ;; Corners should match originals
    (is (approx= 0.0d0 (aref result 0 0) 0.01d0))
    (is (approx= 1.0d0 (aref result 0 2) 0.01d0))
    (is (approx= 1.0d0 (aref result 2 0) 0.01d0))
    (is (approx= 2.0d0 (aref result 2 2) 0.01d0))
    ;; Center should be average = 1.0
    (is (approx= 1.0d0 (aref result 1 1) 0.01d0))))

(test bilinear-gradient
  "Test bilinear interpolation of a linear gradient."
  (let* ((data (make-2d-array 2 2 (lambda (i j) (float j 1.0d0))))
         (result (interpolate-bilinear data 2 5)))
    (is (equal '(2 5) (array-dimensions result)))
    ;; Should produce linearly increasing values across columns
    (is (approx= 0.0d0 (aref result 0 0) 0.01d0))
    (is (approx= 1.0d0 (aref result 0 4) 0.01d0))
    ;; Middle values should be intermediate
    (is (> (aref result 0 2) (aref result 0 1)))))

(test bilinear-rgba
  "Test bilinear RGBA interpolation."
  (let* ((data (make-3d-array 2 2 4
                              (lambda (i j c)
                                (declare (ignore c))
                                (float (+ i j) 1.0d0))))
         (result (interpolate-bilinear-rgba data 3 3)))
    (is (equal '(3 3 4) (array-dimensions result)))
    ;; Corners should match
    (is (approx= 0.0d0 (aref result 0 0 0) 0.01d0))
    (is (approx= 2.0d0 (aref result 2 2 0) 0.01d0))
    ;; Center should be average
    (is (approx= 1.0d0 (aref result 1 1 0) 0.01d0))))

(test bilinear-single-pixel
  "Test bilinear interpolation of a 1×1 input."
  (let* ((data (make-2d-array 1 1 (lambda (i j) (declare (ignore i j)) 5.0)))
         (result (interpolate-bilinear data 3 3)))
    (is (equal '(3 3) (array-dimensions result)))
    ;; All pixels should be 5.0
    (dotimes (i 3)
      (dotimes (j 3)
        (is (approx= 5.0d0 (aref result i j) 0.01d0))))))

;;; ============================================================
;;; imshow tests
;;; ============================================================

(test imshow-basic
  "Test basic imshow with 2D scalar data."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 10 10 (lambda (i j) (* 0.01 (+ i j)))))
         (img (imshow ax data)))
    (is (typep img 'axes-image))
    (is (eq data (image-data img)))
    (is (eq :nearest (image-interpolation img)))
    (is (eq :upper (image-origin img)))
    ;; Should be added to axes images list
    (is (= 1 (length (axes-base-images ax))))
    (is (eq img (first (axes-base-images ax))))))

(test imshow-with-colormap
  "Test imshow with explicit colormap."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5 (lambda (i j) (float (* i j) 1.0d0))))
         (img (imshow ax data :cmap :viridis)))
    (is (typep img 'axes-image))
    (is (typep (image-cmap img) 'colormap))))

(test imshow-with-bilinear
  "Test imshow with bilinear interpolation."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5 (lambda (i j) (float (* i j) 1.0d0))))
         (img (imshow ax data :interpolation :bilinear)))
    (is (eq :bilinear (image-interpolation img)))))

(test imshow-with-extent
  "Test imshow with custom extent."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5))
         (ext '(-1.0 1.0 -1.0 1.0))
         (img (imshow ax data :extent ext)))
    (is (equal ext (image-extent img)))))

(test imshow-with-origin-lower
  "Test imshow with origin :lower."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5))
         (img (imshow ax data :origin :lower)))
    (is (eq :lower (image-origin img)))))

(test imshow-default-extent
  "Test imshow default extent is (0 W 0 H)."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 10 20))
         (img (imshow ax data)))
    (let ((ext (image-extent img)))
      (is (approx= 0.0d0 (first ext)))
      (is (approx= 20.0d0 (second ext)))
      (is (approx= 0.0d0 (third ext)))
      (is (approx= 10.0d0 (fourth ext))))))

(test imshow-updates-datalim
  "Test that imshow updates axes data limits."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 10 20)))
    (imshow ax data)
    ;; View limits should include the image extent
    (multiple-value-bind (xmin xmax) (axes-get-xlim ax)
      (is (<= xmin 0.0d0))
      (is (>= xmax 20.0d0)))
    (multiple-value-bind (ymin ymax) (axes-get-ylim ax)
      (is (<= ymin 0.0d0))
      (is (>= ymax 10.0d0)))))

(test imshow-with-vmin-vmax
  "Test imshow with explicit vmin/vmax."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5 (lambda (i j) (float (+ i j) 1.0d0))))
         (img (imshow ax data :vmin 0.0 :vmax 10.0)))
    (is (= 0.0 (image-vmin img)))
    (is (= 10.0 (image-vmax img)))))

(test imshow-with-alpha
  "Test imshow with alpha transparency."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5))
         (img (imshow ax data :alpha 0.5)))
    (is (approx= 0.5d0 (artist-alpha img)))))

(test imshow-aspect-auto
  "Test imshow with aspect :auto (default)."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5))
         (img (imshow ax data)))
    (is (eq :auto (image-aspect img)))))

(test imshow-aspect-equal
  "Test imshow with aspect :equal."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5))
         (img (imshow ax data :aspect :equal)))
    (is (eq :equal (image-aspect img)))))

(test imshow-rgb-data
  "Test imshow with 3D RGB array."
  (let* ((ax (make-test-axes))
         (data (make-3d-array 5 5 3 (lambda (i j c)
                                       (declare (ignore c))
                                       (float (* i j 0.1) 1.0d0))))
         (img (imshow ax data)))
    (is (typep img 'axes-image))
    (is (equal '(5 5 3) (image-shape img)))))

(test imshow-rgba-data
  "Test imshow with 3D RGBA array."
  (let* ((ax (make-test-axes))
         (data (make-3d-array 5 5 4 (lambda (i j c)
                                       (declare (ignore i j c))
                                       0.5d0)))
         (img (imshow ax data)))
    (is (typep img 'axes-image))
    (is (equal '(5 5 4) (image-shape img)))))

(test imshow-multiple-images
  "Test multiple imshow calls on same axes."
  (let* ((ax (make-test-axes))
         (data1 (make-2d-array 5 5))
         (data2 (make-2d-array 5 5)))
    (imshow ax data1)
    (imshow ax data2)
    (is (= 2 (length (axes-base-images ax))))))

(test imshow-zorder
  "Test imshow zorder parameter."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5))
         (img (imshow ax data :zorder 3)))
    (is (= 3 (artist-zorder img)))))

(test imshow-transform-set
  "Test that imshow sets the artist transform to transData."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5))
         (img (imshow ax data)))
    (is (not (null (artist-transform img))))))

;;; ============================================================
;;; Rendering integration tests
;;; ============================================================

(test imshow-renders-to-png
  "Test that imshow renders to a PNG file."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (data (make-2d-array 10 10 (lambda (i j) (float (+ i j) 1.0d0))))
         (png-path "/tmp/cl-mpl-test-imshow.png"))
    (imshow ax data :cmap :viridis)
    (savefig fig png-path)
    (is (probe-file png-path))))

(test imshow-bilinear-renders
  "Test that bilinear interpolation renders correctly."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (data (make-2d-array 5 5 (lambda (i j)
                                     (float (* i j 0.05) 1.0d0))))
         (png-path "/tmp/cl-mpl-test-imshow-bilinear.png"))
    (imshow ax data :interpolation :bilinear :cmap :viridis)
    (savefig fig png-path)
    (is (probe-file png-path))))

(test imshow-rgb-renders
  "Test that RGB data renders to PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (data (make-3d-array 10 10 3
                              (lambda (i j c)
                                (case c
                                  (0 (/ (float i) 9.0))   ; Red gradient
                                  (1 (/ (float j) 9.0))   ; Green gradient
                                  (2 0.5)))))              ; Blue constant
         (png-path "/tmp/cl-mpl-test-imshow-rgb.png"))
    (imshow ax data)
    (savefig fig png-path)
    (is (probe-file png-path))))

(test imshow-origin-lower-renders
  "Test :lower origin renders correctly."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5
                              (lambda (i j)
                                (declare (ignore j))
                                (float i 1.0d0))))
         (img (imshow ax data :origin :lower :cmap :viridis)))
    (is (typep img 'axes-image))
    (is (eq :lower (image-origin img)))))

(test imshow-custom-extent-renders
  "Test custom extent renders."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5 (lambda (i j) (float (* i j) 1.0d0))))
         (img (imshow ax data :extent '(-5.0 5.0 -5.0 5.0) :cmap :viridis)))
    (is (typep img 'axes-image))
    (is (equal '(-5.0 5.0 -5.0 5.0) (image-extent img)))))

;;; ============================================================
;;; Interpolation method selection
;;; ============================================================

(test interpolation-methods-list
  "Test that supported interpolation methods are defined."
  (is (member :nearest *interpolation-methods*))
  (is (member :bilinear *interpolation-methods*))
  (is (member :none *interpolation-methods*)))

;;; ============================================================
;;; Edge cases
;;; ============================================================

(test imshow-single-pixel
  "Test imshow with a 1×1 array."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 1 1 (lambda (i j) (declare (ignore i j)) 0.5d0)))
         (img (imshow ax data)))
    (is (typep img 'axes-image))
    (is (= 1 (image-rows img)))
    (is (= 1 (image-cols img)))))

(test imshow-uniform-data
  "Test imshow with uniform data (all same value)."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 5 5 (lambda (i j) (declare (ignore i j)) 42.0d0)))
         (img (imshow ax data)))
    (is (typep img 'axes-image))))

(test imshow-large-array
  "Test imshow with a larger array."
  (let* ((ax (make-test-axes))
         (data (make-2d-array 100 100
                              (lambda (i j) (sin (float (+ (* i 0.1) (* j 0.1)) 1.0d0)))))
         (img (imshow ax data)))
    (is (= 100 (image-rows img)))
    (is (= 100 (image-cols img)))))

(test nearest-empty-preserves-dimensions
  "Test that interpolation handles edge dimensions."
  (let ((data (make-2d-array 3 3 (lambda (i j) (float (+ i j) 1.0d0)))))
    ;; Upscale to 1×1
    (let ((result (interpolate-nearest data 1 1)))
      (is (equal '(1 1) (array-dimensions result))))
    ;; Upscale to large
    (let ((result (interpolate-nearest data 10 10)))
      (is (equal '(10 10) (array-dimensions result))))))

(test bilinear-preserves-endpoints
  "Test that bilinear preserves corner values."
  (let* ((data (make-2d-array 3 3 (lambda (i j) (float (+ (* i 10) j) 1.0d0))))
         (result (interpolate-bilinear data 5 5)))
    ;; Top-left corner
    (is (approx= (aref data 0 0) (aref result 0 0) 0.01d0))
    ;; Top-right corner
    (is (approx= (aref data 0 2) (aref result 0 4) 0.01d0))
    ;; Bottom-left corner
    (is (approx= (aref data 2 0) (aref result 4 0) 0.01d0))
    ;; Bottom-right corner
    (is (approx= (aref data 2 2) (aref result 4 4) 0.01d0))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-image-tests ()
  "Run all image tests and report results."
  (let ((results (run 'image-suite)))
    (explain! results)
    (unless (every #'fiveam::test-passed-p results)
      (error "Image tests FAILED"))))
