;;;; image.lisp — AxesImage class
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
;;; AxesImage draw method
;;; ============================================================

(defmethod draw ((img axes-image) renderer)
  "Draw the image using RENDERER."
  (unless (artist-visible img)
    (return-from draw))
  (unless (image-data img)
    (return-from draw))
  (let ((gc (make-gc :alpha (or (artist-alpha img) 1.0)))
        (transform (get-artist-transform img)))
    ;; Calculate position from extent or default to (0, 0)
    (let* ((extent (image-extent img))
           (x (if extent (first extent) 0.0))
           (y (if extent (third extent) 0.0)))
      (renderer-draw-image renderer gc x y (image-data img))))
  (setf (artist-stale img) nil))

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
