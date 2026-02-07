;;;; compare.lisp — Image comparison utilities for testing
;;;; Phase 8a: Pure CL image comparison (RMS + SSIM)
;;;;
;;;; Port of matplotlib.testing.compare, focused on PNG comparison.

(in-package #:cl-matplotlib.testing)

;;; ============================================================
;;; Image loading via pngload
;;; ============================================================

(defun load-png-as-array (path)
  "Load a PNG file and return pixel data as a 3D array (H W C).
Each channel value is (unsigned-byte 8). If the image is RGBA and
fully opaque, the alpha channel is kept but ignored in comparisons.
Returns (values data height width channels)."
  (let* ((png (pngload:load-file path))
         (data (pngload:data png))
         (h (pngload:height png))
         (w (pngload:width png)))
    ;; pngload returns (H W C) array of (unsigned-byte 8)
    ;; Handle different color types
    (let ((dims (array-dimensions data)))
      (cond
        ;; Truecolour-alpha or Truecolour: 3D array (H W 3-or-4)
        ((= (length dims) 3)
         (values data h w (third dims)))
        ;; Greyscale: 2D array (H W) — expand to (H W 1)
        ((= (length dims) 2)
         (let ((expanded (make-array (list h w 1) :element-type '(unsigned-byte 8))))
           (dotimes (j h)
             (dotimes (i w)
               (setf (aref expanded j i 0) (aref data j i))))
           (values expanded h w 1)))
        (t (error "Unexpected PNG data dimensions: ~A" dims))))))

;;; ============================================================
;;; RMS (Root Mean Square) difference
;;; ============================================================

(defun calculate-rms (expected-data actual-data)
  "Calculate per-pixel RMS difference between two image arrays.
Both arrays must be 3D (H W C) of (unsigned-byte 8).
Returns the RMS as a double-float in [0, 255] range.
Raises an error if image dimensions don't match."
  (let ((expected-dims (array-dimensions expected-data))
        (actual-dims (array-dimensions actual-data)))
    (unless (equal expected-dims actual-dims)
      (error "Image sizes do not match: expected ~A, actual ~A"
             expected-dims actual-dims))
    (let* ((h (first expected-dims))
           (w (second expected-dims))
           (c (third expected-dims))
           (n (* h w c))
           (sum-sq 0.0d0))
      (dotimes (j h)
        (dotimes (i w)
          (dotimes (k c)
            (let ((diff (- (the fixnum (aref expected-data j i k))
                          (the fixnum (aref actual-data j i k)))))
              (incf sum-sq (* (the fixnum diff) (the fixnum diff)))))))
      (sqrt (/ sum-sq (the fixnum n))))))

;;; ============================================================
;;; SSIM (Structural Similarity Index)
;;; ============================================================

;;; SSIM constants (for 8-bit images, L=255)
(defconstant +ssim-k1+ 0.01d0)
(defconstant +ssim-k2+ 0.03d0)
(defconstant +ssim-l+ 255.0d0)
(defparameter *ssim-c1* (expt (* +ssim-k1+ +ssim-l+) 2))  ; ~6.5025
(defparameter *ssim-c2* (expt (* +ssim-k2+ +ssim-l+) 2))  ; ~58.5225

(defun %image-to-grayscale (data h w c)
  "Convert image data to grayscale double-float 2D array.
Uses luminance formula: 0.2989*R + 0.5870*G + 0.1140*B"
  (let ((gray (make-array (list h w) :element-type 'double-float)))
    (dotimes (j h)
      (dotimes (i w)
        (setf (aref gray j i)
              (cond
                ((= c 1) (coerce (aref data j i 0) 'double-float))
                ((>= c 3)
                 (+ (* 0.2989d0 (aref data j i 0))
                    (* 0.5870d0 (aref data j i 1))
                    (* 0.1140d0 (aref data j i 2))))
                (t (coerce (aref data j i 0) 'double-float))))))
    gray))

(defun %compute-local-stats (gray j i window-size)
  "Compute local mean, variance for a window centered at (j,i).
Returns (values mean variance)."
  (let* ((h (array-dimension gray 0))
         (w (array-dimension gray 1))
         (half (floor window-size 2))
         (j0 (max 0 (- j half)))
         (j1 (min h (+ j half 1)))
         (i0 (max 0 (- i half)))
         (i1 (min w (+ i half 1)))
         (n 0)
         (sum 0.0d0)
         (sum-sq 0.0d0))
    (loop for jj from j0 below j1 do
      (loop for ii from i0 below i1 do
        (let ((v (aref gray jj ii)))
          (incf sum v)
          (incf sum-sq (* v v))
          (incf n))))
    (let* ((mean (/ sum n))
           (variance (- (/ sum-sq n) (* mean mean))))
      (values mean (max 0.0d0 variance)))))

(defun %compute-local-covariance (gray1 gray2 mean1 mean2 j i window-size)
  "Compute local covariance between two grayscale images at (j,i)."
  (let* ((h (array-dimension gray1 0))
         (w (array-dimension gray1 1))
         (half (floor window-size 2))
         (j0 (max 0 (- j half)))
         (j1 (min h (+ j half 1)))
         (i0 (max 0 (- i half)))
         (i1 (min w (+ i half 1)))
         (n 0)
         (sum 0.0d0))
    (loop for jj from j0 below j1 do
      (loop for ii from i0 below i1 do
        (incf sum (* (- (aref gray1 jj ii) mean1)
                     (- (aref gray2 jj ii) mean2)))
        (incf n)))
    (/ sum n)))

(defun calculate-ssim (expected-data actual-data &key (window-size 7) (step 4))
  "Calculate SSIM (Structural Similarity Index) between two images.
Both must be 3D arrays (H W C) of (unsigned-byte 8).
Returns SSIM as a double-float in [-1, 1], where 1 = identical.

Uses a sliding window approach with configurable window size and step
for performance. Default window-size=7, step=4 (sampling for speed)."
  (let ((expected-dims (array-dimensions expected-data))
        (actual-dims (array-dimensions actual-data)))
    (unless (equal expected-dims actual-dims)
      (error "Image sizes do not match: expected ~A, actual ~A"
             expected-dims actual-dims))
    (let* ((h (first expected-dims))
           (w (second expected-dims))
           (c (third expected-dims))
           (gray1 (%image-to-grayscale expected-data h w c))
           (gray2 (%image-to-grayscale actual-data h w c))
           (ssim-sum 0.0d0)
           (n-windows 0))
      ;; Slide window over image with step size
      (loop for j from 0 below h by step do
        (loop for i from 0 below w by step do
          (multiple-value-bind (mu1 var1) (%compute-local-stats gray1 j i window-size)
            (multiple-value-bind (mu2 var2) (%compute-local-stats gray2 j i window-size)
              (let* ((sigma12 (%compute-local-covariance gray1 gray2 mu1 mu2 j i window-size))
                     (numerator (* (+ (* 2.0d0 mu1 mu2) *ssim-c1*)
                                   (+ (* 2.0d0 sigma12) *ssim-c2*)))
                     (denominator (* (+ (* mu1 mu1) (* mu2 mu2) *ssim-c1*)
                                     (+ var1 var2 *ssim-c2*))))
                (incf ssim-sum (/ numerator denominator))
                (incf n-windows))))))
      (if (zerop n-windows)
          1.0d0  ; degenerate case: no windows
          (/ ssim-sum n-windows)))))

;;; ============================================================
;;; High-level comparison API
;;; ============================================================

(defparameter *image-tolerance* 2.0d0
  "Default RMS tolerance for image comparisons. Images with RMS
difference below this value are considered identical.
Matplotlib uses tol=0 by default, but small rendering differences
across platforms make a small tolerance practical.")

(defun compare-images (expected-path actual-path &key (tolerance *image-tolerance*))
  "Compare two PNG image files. Returns a plist with comparison results.

Keys in returned plist:
  :rms       — Root Mean Square pixel difference (0 = identical, 255 = max)
  :ssim      — Structural Similarity Index (-1 to 1, 1 = identical)
  :passed    — T if RMS <= tolerance, NIL otherwise
  :tolerance — The tolerance used
  :expected  — Path to expected image
  :actual    — Path to actual image

Example:
  (compare-images \"baseline.png\" \"output.png\")
  ;; => (:rms 0.5 :ssim 0.999 :passed T :tolerance 2.0 ...)"
  ;; Validate inputs
  (unless (probe-file expected-path)
    (error "Baseline image does not exist: ~A" expected-path))
  (unless (probe-file actual-path)
    (error "Actual image does not exist: ~A" actual-path))
  ;; Load images
  (multiple-value-bind (expected-data eh ew ec)
      (load-png-as-array expected-path)
    (declare (ignore eh ew ec))
    (multiple-value-bind (actual-data ah aw ac)
        (load-png-as-array actual-path)
      (declare (ignore ah aw ac))
      ;; Compute metrics
      (let* ((rms (calculate-rms expected-data actual-data))
             (ssim (calculate-ssim expected-data actual-data))
             (passed (<= rms tolerance)))
        (list :rms rms
              :ssim ssim
              :passed passed
              :tolerance tolerance
              :expected (namestring (truename expected-path))
              :actual (namestring (truename actual-path)))))))

;;; ============================================================
;;; Baseline directory management
;;; ============================================================

(defparameter *baseline-dir* nil
  "Base directory for baseline images. If NIL, defaults to
tests/baseline_images/ relative to the system source directory.")

(defun baseline-dir ()
  "Return the baseline images directory path, creating it if needed."
  (let ((dir (or *baseline-dir*
                 (merge-pathnames
                  #P"tests/baseline_images/"
                  (asdf:system-source-directory :cl-matplotlib-testing)))))
    (ensure-directories-exist dir)
    dir))

(defun find-baseline (suite-name test-name &key (extension "png"))
  "Find a baseline image for a given test.
Looks in: <baseline-dir>/<suite-name>/<test-name>.<extension>
Returns the pathname if found, NIL otherwise."
  (let ((path (merge-pathnames
               (make-pathname :directory (list :relative (string-downcase (string suite-name)))
                              :name (string-downcase (string test-name))
                              :type extension)
               (baseline-dir))))
    (when (probe-file path)
      path)))

(defun baseline-path (suite-name test-name &key (extension "png"))
  "Return the canonical baseline path for a test (may not exist yet).
Use this to save new baseline images."
  (let ((path (merge-pathnames
               (make-pathname :directory (list :relative (string-downcase (string suite-name)))
                              :name (string-downcase (string test-name))
                              :type extension)
               (baseline-dir))))
    (ensure-directories-exist path)
    path))

;;; ============================================================
;;; Save diff image (for debugging failures)
;;; ============================================================

(defun save-diff-image (expected-path actual-path output-path)
  "Save a visual diff image highlighting differences between two PNGs.
Pixel differences are amplified 10x and clamped to [0,255]."
  (multiple-value-bind (expected-data eh ew ec)
      (load-png-as-array expected-path)
    (multiple-value-bind (actual-data ah aw ac)
        (load-png-as-array actual-path)
      (declare (ignore ah aw ac))
      (let* ((h eh)
             (w ew)
             (c ec)
             (diff-png (make-instance 'zpng:png
                                      :width w :height h
                                      :color-type (if (= c 4) :truecolor-alpha :truecolor)))
             (diff-data (zpng:image-data diff-png)))
        ;; Write amplified difference
        (dotimes (j h)
          (dotimes (i w)
            (let ((out-c (if (= c 4) 4 3)))
              (dotimes (k (min c out-c))
                (let* ((d (abs (- (aref expected-data j i k)
                                  (aref actual-data j i k))))
                       (amplified (min 255 (* d 10))))
                  (setf (aref diff-data (+ (* (+ (* j w) i) out-c) k))
                        amplified)))
              ;; Set alpha to 255 if RGBA
              (when (= out-c 4)
                (setf (aref diff-data (+ (* (+ (* j w) i) out-c) 3)) 255)))))
        (zpng:write-png diff-png output-path)))))
