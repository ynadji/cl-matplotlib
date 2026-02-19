;;;; image.lisp — AxesImage class with interpolation and data→RGBA conversion
;;;; Ported from matplotlib's image.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Interpolation methods
;;; ============================================================

(defparameter *interpolation-methods*
  '(:nearest :bilinear :bicubic :auto :none)
  "Supported image interpolation methods.")

;;; ============================================================
;;; AxesImage class
;;; ============================================================

(defclass axes-image (artist)
  ((data :initarg :data
         :initform nil
         :accessor image-data
         :documentation "Image data as a 2D or 3D array.
For grayscale: (rows cols). For RGB: (rows cols 3). For RGBA: (rows cols 4).")
   (extent :initarg :extent
           :initform nil
           :accessor image-extent
           :documentation "Extent as (xmin xmax ymin ymax) or nil for auto.")
   (interpolation :initarg :interpolation
                  :initform :nearest
                  :accessor image-interpolation
                  :documentation "Interpolation method: :nearest, :bilinear, :bicubic.")
   (origin :initarg :origin
           :initform :upper
           :accessor image-origin
           :documentation "Image origin: :upper or :lower.")
   (cmap :initarg :cmap
         :initform nil
         :accessor image-cmap
         :documentation "Colormap for scalar data (colormap instance or name).")
   (norm :initarg :norm
         :initform nil
         :accessor image-norm
         :documentation "Normalize instance for scalar data mapping.")
   (vmin :initarg :vmin
         :initform nil
         :accessor image-vmin
         :documentation "Minimum value for normalization.")
   (vmax :initarg :vmax
         :initform nil
         :accessor image-vmax
         :documentation "Maximum value for normalization.")
   (aspect :initarg :aspect
           :initform :auto
           :accessor image-aspect
           :documentation "Aspect ratio: :auto, :equal, or numeric.")
   (filternorm :initarg :filternorm
               :initform t
               :accessor image-filternorm
               :type boolean
               :documentation "Whether to normalize the filter.")
   (filterrad :initarg :filterrad
              :initform 4.0
              :accessor image-filterrad
              :type real
              :documentation "Filter radius for bicubic interpolation."))
  (:default-initargs :zorder 0)
  (:documentation "Image data holder for imshow.
Ported from matplotlib.image.AxesImage."))

(defmethod initialize-instance :after ((img axes-image) &key)
  "Validate image properties."
  (when (and (image-interpolation img)
             (not (member (image-interpolation img) *interpolation-methods*)))
    (warn "Unknown interpolation method: ~S" (image-interpolation img))))

;;; ============================================================
;;; Image utilities
;;; ============================================================

(defun image-shape (img)
  "Return the shape of the image data as (rows cols channels) or nil."
  (when (image-data img)
    (array-dimensions (image-data img))))

(defun image-rows (img)
  "Return the number of rows in the image."
  (when (image-data img)
    (array-dimension (image-data img) 0)))

(defun image-cols (img)
  "Return the number of columns in the image."
  (when (image-data img)
    (array-dimension (image-data img) 1)))

;;; ============================================================
;;; Nearest-neighbor interpolation
;;; ============================================================

(defun interpolate-nearest (data target-h target-w)
  "Nearest-neighbor interpolation of 2D array DATA to TARGET-H × TARGET-W.
DATA is a 2D array (H × W) of double-floats.
Returns a new 2D array of size (TARGET-H × TARGET-W)."
  (let* ((src-h (array-dimension data 0))
         (src-w (array-dimension data 1))
         (result (make-array (list target-h target-w)
                             :element-type 'double-float
                             :initial-element 0.0d0)))
    (when (and (> src-h 0) (> src-w 0)
               (> target-h 0) (> target-w 0))
      (let ((y-ratio (/ (float src-h 1.0d0) (float target-h 1.0d0)))
            (x-ratio (/ (float src-w 1.0d0) (float target-w 1.0d0))))
        (dotimes (i target-h)
          (let ((src-i (min (floor (* (+ i 0.5d0) y-ratio))
                            (1- src-h))))
            (dotimes (j target-w)
              (let ((src-j (min (floor (* (+ j 0.5d0) x-ratio))
                                (1- src-w))))
                (setf (aref result i j)
                      (aref data src-i src-j))))))))
    result))

(defun interpolate-nearest-rgba (data target-h target-w)
  "Nearest-neighbor interpolation for RGBA data (H × W × 4).
Returns a new (TARGET-H × TARGET-W × 4) array."
  (let* ((src-h (array-dimension data 0))
         (src-w (array-dimension data 1))
         (channels (array-dimension data 2))
         (result (make-array (list target-h target-w channels)
                             :element-type 'double-float
                             :initial-element 0.0d0)))
    (when (and (> src-h 0) (> src-w 0)
               (> target-h 0) (> target-w 0))
      (let ((y-ratio (/ (float src-h 1.0d0) (float target-h 1.0d0)))
            (x-ratio (/ (float src-w 1.0d0) (float target-w 1.0d0))))
        (dotimes (i target-h)
          (let ((src-i (min (floor (* (+ i 0.5d0) y-ratio))
                            (1- src-h))))
            (dotimes (j target-w)
              (let ((src-j (min (floor (* (+ j 0.5d0) x-ratio))
                                (1- src-w))))
                (dotimes (c channels)
                  (setf (aref result i j c)
                        (aref data src-i src-j c)))))))))
    result))

;;; ============================================================
;;; Bilinear interpolation
;;; ============================================================

(defun interpolate-bilinear (data target-h target-w)
  "Bilinear interpolation of 2D array DATA to TARGET-H × TARGET-W.
DATA is a 2D array (H × W) of double-floats.
Returns a new 2D array of size (TARGET-H × TARGET-W)."
  (let* ((src-h (array-dimension data 0))
         (src-w (array-dimension data 1))
         (result (make-array (list target-h target-w)
                             :element-type 'double-float
                             :initial-element 0.0d0)))
    (when (and (> src-h 0) (> src-w 0)
               (> target-h 0) (> target-w 0))
      (let ((y-ratio (if (> target-h 1)
                         (/ (float (1- src-h) 1.0d0) (float (1- target-h) 1.0d0))
                         0.0d0))
            (x-ratio (if (> target-w 1)
                         (/ (float (1- src-w) 1.0d0) (float (1- target-w) 1.0d0))
                         0.0d0)))
        (dotimes (i target-h)
          (let* ((y (* i y-ratio))
                 (y0 (min (floor y) (1- src-h)))
                 (y1 (min (1+ y0) (1- src-h)))
                 (fy (- y y0)))
            (dotimes (j target-w)
              (let* ((x (* j x-ratio))
                     (x0 (min (floor x) (1- src-w)))
                     (x1 (min (1+ x0) (1- src-w)))
                     (fx (- x x0))
                     ;; Four surrounding pixels
                     (v00 (aref data y0 x0))
                     (v01 (aref data y0 x1))
                     (v10 (aref data y1 x0))
                     (v11 (aref data y1 x1))
                     ;; Bilinear blend
                     (val (+ (* v00 (* (- 1.0d0 fy) (- 1.0d0 fx)))
                             (* v01 (* (- 1.0d0 fy) fx))
                             (* v10 (* fy (- 1.0d0 fx)))
                             (* v11 (* fy fx)))))
                (setf (aref result i j) val)))))))
    result))

(defun interpolate-bilinear-rgba (data target-h target-w)
  "Bilinear interpolation for RGBA data (H × W × C).
Returns a new (TARGET-H × TARGET-W × C) array."
  (let* ((src-h (array-dimension data 0))
         (src-w (array-dimension data 1))
         (channels (array-dimension data 2))
         (result (make-array (list target-h target-w channels)
                             :element-type 'double-float
                             :initial-element 0.0d0)))
    (when (and (> src-h 0) (> src-w 0)
               (> target-h 0) (> target-w 0))
      (let ((y-ratio (if (> target-h 1)
                         (/ (float (1- src-h) 1.0d0) (float (1- target-h) 1.0d0))
                         0.0d0))
            (x-ratio (if (> target-w 1)
                         (/ (float (1- src-w) 1.0d0) (float (1- target-w) 1.0d0))
                         0.0d0)))
        (dotimes (i target-h)
          (let* ((y (* i y-ratio))
                 (y0 (min (floor y) (1- src-h)))
                 (y1 (min (1+ y0) (1- src-h)))
                 (fy (- y y0)))
            (dotimes (j target-w)
              (let* ((x (* j x-ratio))
                     (x0 (min (floor x) (1- src-w)))
                     (x1 (min (1+ x0) (1- src-w)))
                     (fx (- x x0)))
                (dotimes (c channels)
                  (let* ((v00 (aref data y0 x0 c))
                         (v01 (aref data y0 x1 c))
                         (v10 (aref data y1 x0 c))
                         (v11 (aref data y1 x1 c))
                         (val (+ (* v00 (* (- 1.0d0 fy) (- 1.0d0 fx)))
                                 (* v01 (* (- 1.0d0 fy) fx))
                                 (* v10 (* fy (- 1.0d0 fx)))
                                 (* v11 (* fy fx)))))
                    (setf (aref result i j c) val)))))))))
    result))

;;; ============================================================
;;; Data → RGBA conversion
;;; ============================================================

(defun %image-data-to-rgba (data cmap norm)
  "Convert image data to RGBA double-float array (H × W × 4).
DATA can be:
  - 2D array (H × W): scalar data, mapped through NORM + CMAP
  - 3D array (H × W × 3): RGB data, alpha = 1.0
  - 3D array (H × W × 4): RGBA data, used as-is
CMAP is a colormap instance.
NORM is a normalize instance.
Returns a (H × W × 4) array of double-floats in [0, 1]."
  (let ((ndims (array-rank data)))
    (cond
      ;; 2D scalar data: normalize + colormap
      ((= ndims 2)
       (let* ((h (array-dimension data 0))
              (w (array-dimension data 1))
              (result (make-array (list h w 4)
                                  :element-type 'double-float
                                  :initial-element 1.0d0)))
         (dotimes (i h)
           (dotimes (j w)
             (let* ((val (float (aref data i j) 1.0d0))
                    (normalized (mpl.primitives:normalize-call norm val))
                    (rgba (mpl.primitives:colormap-call cmap normalized)))
               (setf (aref result i j 0) (float (aref rgba 0) 1.0d0))
               (setf (aref result i j 1) (float (aref rgba 1) 1.0d0))
               (setf (aref result i j 2) (float (aref rgba 2) 1.0d0))
               (setf (aref result i j 3) (float (aref rgba 3) 1.0d0)))))
         result))
      ;; 3D data: RGB or RGBA
      ((= ndims 3)
       (let* ((h (array-dimension data 0))
              (w (array-dimension data 1))
              (c (array-dimension data 2))
              (result (make-array (list h w 4)
                                  :element-type 'double-float
                                  :initial-element 1.0d0)))
         (dotimes (i h)
           (dotimes (j w)
             ;; Determine if values need normalization (> 1.0 → assume 0-255)
             (let ((r (float (aref data i j 0) 1.0d0))
                   (g (float (aref data i j 1) 1.0d0))
                   (b (float (aref data i j 2) 1.0d0))
                   (a (if (>= c 4)
                          (float (aref data i j 3) 1.0d0)
                          1.0d0)))
               ;; Normalize 0-255 to 0-1 if needed
               (when (or (> r 1.0d0) (> g 1.0d0) (> b 1.0d0))
                 (setf r (/ r 255.0d0)
                       g (/ g 255.0d0)
                       b (/ b 255.0d0))
                 (when (and (>= c 4) (> a 1.0d0))
                   (setf a (/ a 255.0d0))))
               (setf (aref result i j 0) (max 0.0d0 (min 1.0d0 r)))
               (setf (aref result i j 1) (max 0.0d0 (min 1.0d0 g)))
               (setf (aref result i j 2) (max 0.0d0 (min 1.0d0 b)))
               (setf (aref result i j 3) (max 0.0d0 (min 1.0d0 a))))))
         result))
      (t (error "Image data must be 2D or 3D, got rank ~D" ndims)))))

(defun %rgba-to-bytes (rgba-data)
  "Convert (H × W × 4) double-float RGBA data to flat (unsigned-byte 8) array.
Returns a plist (:data flat-array :width W :height H)."
  (let* ((h (array-dimension rgba-data 0))
         (w (array-dimension rgba-data 1))
         (flat (make-array (* h w 4)
                           :element-type '(unsigned-byte 8)
                           :initial-element 0)))
    (dotimes (i h)
      (dotimes (j w)
        (let ((idx (* 4 (+ j (* i w)))))
          (setf (aref flat (+ idx 0))
                (min 255 (max 0 (round (* (aref rgba-data i j 0) 255.0d0)))))
          (setf (aref flat (+ idx 1))
                (min 255 (max 0 (round (* (aref rgba-data i j 1) 255.0d0)))))
          (setf (aref flat (+ idx 2))
                (min 255 (max 0 (round (* (aref rgba-data i j 2) 255.0d0)))))
          (setf (aref flat (+ idx 3))
                (min 255 (max 0 (round (* (aref rgba-data i j 3) 255.0d0))))))))
    (list :data flat :width w :height h)))

(defun %apply-origin (rgba-data origin)
  "If ORIGIN is :lower, flip the image vertically (row 0 at bottom).
For :upper, no flip needed (Vecto renders row 0 at top by default).
Modifies in-place and returns the data."
  (when (eq origin :lower)
    (let* ((h (array-dimension rgba-data 0))
           (w (array-dimension rgba-data 1))
           (half-h (floor h 2)))
      (dotimes (i half-h)
        (let ((mirror (- h 1 i)))
          (dotimes (j w)
            (dotimes (c 4)
              (let ((tmp (aref rgba-data i j c)))
                (setf (aref rgba-data i j c) (aref rgba-data mirror j c))
                (setf (aref rgba-data mirror j c) tmp))))))))
  rgba-data)

;;; ============================================================
;;; AxesImage draw method
;;; ============================================================

(defmethod draw ((img axes-image) renderer)
  "Draw the image using RENDERER.
Converts data → RGBA, applies interpolation, renders via backend."
  (unless (artist-visible img)
    (return-from draw))
  (unless (image-data img)
    (return-from draw))
  ;; Resolve colormap
  (let* ((data (image-data img))
         (cmap (or (image-cmap img)
                   (mpl.primitives:get-colormap :viridis)))
         (cmap-obj (if (typep cmap 'mpl.primitives:colormap)
                       cmap
                       (mpl.primitives:get-colormap cmap)))
         ;; Resolve norm
         (norm (or (image-norm img)
                   (let ((n (mpl.primitives:make-normalize
                             :vmin (image-vmin img)
                             :vmax (image-vmax img))))
                     ;; Auto-detect vmin/vmax from 2D scalar data
                     (when (and (= (array-rank data) 2)
                                (or (null (mpl.primitives:norm-vmin n))
                                    (null (mpl.primitives:norm-vmax n))))
                       (let ((dmin most-positive-double-float)
                             (dmax most-negative-double-float))
                         (dotimes (i (array-dimension data 0))
                           (dotimes (j (array-dimension data 1))
                             (let ((v (float (aref data i j) 1.0d0)))
                               (when (< v dmin) (setf dmin v))
                               (when (> v dmax) (setf dmax v)))))
                         (when (null (mpl.primitives:norm-vmin n))
                           (setf (mpl.primitives:norm-vmin n) dmin))
                         (when (null (mpl.primitives:norm-vmax n))
                           (setf (mpl.primitives:norm-vmax n) dmax))))
                     n)))
         ;; Convert data to RGBA
         (rgba (%image-data-to-rgba data cmap-obj norm))
         ;; Apply origin (flip if :upper so row 0 = top)
         (origin (image-origin img))
         (interpolation (or (image-interpolation img) :nearest)))
    ;; Apply origin
    (%apply-origin rgba origin)
    ;; Determine target size and position
    (let* ((src-h (array-dimension rgba 0))
           (src-w (array-dimension rgba 1))
           (extent (image-extent img))
           (xmin (if extent (float (first extent) 1.0d0) 0.0d0))
           (xmax (if extent (float (second extent) 1.0d0) (float src-w 1.0d0)))
           (ymin (if extent (float (third extent) 1.0d0) 0.0d0))
           (ymax (if extent (float (fourth extent) 1.0d0) (float src-h 1.0d0)))
           ;; Get transform to convert data coords to display coords
           (transform (get-artist-transform img))
           ;; Transform extent corners to display coordinates
           (p-min (if transform
                      (mpl.primitives:transform-point
                       transform (list xmin ymin))
                      (vector xmin ymin)))
           (p-max (if transform
                      (mpl.primitives:transform-point
                       transform (list xmax ymax))
                      (vector xmax ymax)))
           (dx0 (aref p-min 0))
           (dy0 (aref p-min 1))
           (dx1 (aref p-max 0))
           (dy1 (aref p-max 1))
           ;; Target pixel dimensions (capped to avoid excessive memory)
           (target-w (min 2048 (max 1 (round (abs (- dx1 dx0))))))
           (target-h (min 2048 (max 1 (round (abs (- dy1 dy0))))))
           ;; Display position (top-left)
           (dest-x (round (min dx0 dx1)))
           (dest-y (round (min dy0 dy1))))
      ;; Apply interpolation to RGBA data
      (let ((interpolated
              (if (and (= target-w src-w) (= target-h src-h))
                  rgba  ; No interpolation needed
                  (case interpolation
                    (:bilinear (interpolate-bilinear-rgba rgba target-h target-w))
                    (otherwise (interpolate-nearest-rgba rgba target-h target-w))))))
        ;; Apply alpha from artist
        (when (artist-alpha img)
          (let ((a (float (artist-alpha img) 1.0d0)))
            (dotimes (i (array-dimension interpolated 0))
              (dotimes (j (array-dimension interpolated 1))
                (setf (aref interpolated i j 3)
                      (* (aref interpolated i j 3) a))))))
        ;; Convert to bytes and blit
        (let ((im (%rgba-to-bytes interpolated))
              (gc (make-gc :alpha 1.0)))
          (renderer-draw-image renderer gc dest-x dest-y im)))))
  (setf (artist-stale img) nil))
