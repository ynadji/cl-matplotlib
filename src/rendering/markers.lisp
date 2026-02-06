;;;; markers.lisp — MarkerStyle class and marker path generation
;;;; Ported from matplotlib's markers.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Marker registry
;;; ============================================================

(defparameter *marker-names*
  '((:o . "circle")
    (:s . "square")
    (:^ . "triangle_up")
    (:v . "triangle_down")
    (:< . "triangle_left")
    (:> . "triangle_right")
    (:d . "diamond")
    (:plus . "plus")
    (:x . "x")
    (:star . "star")
    (:vline . "vline")
    (:hline . "hline")
    (:point . "point")
    (:none . "nothing"))
  "Known marker types as keyword/name pairs.
Note: We use :plus, :star, :vline, :hline, :point instead of :+, :*, :|, :_, :.
because those characters cause issues with the CL reader.")

(defparameter *filled-markers*
  '(:point :o :v :^ :< :> :s :d :star)
  "Markers that have a fill area.")

;;; ============================================================
;;; MarkerStyle class
;;; ============================================================

(defclass marker-style ()
  ((marker :initarg :marker
           :initform :o
           :accessor marker-style-marker
           :documentation "The marker type keyword.")
   (fillstyle :initarg :fillstyle
              :initform :full
              :accessor marker-style-fillstyle
              :documentation "Fill style: :full, :left, :right, :bottom, :top, :none.")
   (path :initform nil
         :accessor marker-style-path
         :documentation "Cached marker path.")
   (marker-transform :initform nil
                     :accessor marker-style-transform
                     :documentation "Transform to apply to the marker path.")
   (filled-p :initform t
             :accessor marker-style-filled-p
             :type boolean
             :documentation "Whether this marker is filled.")
   (joinstyle :initform :round
              :accessor marker-style-joinstyle
              :documentation "Join style for the marker.")
   (capstyle :initform :butt
             :accessor marker-style-capstyle
             :documentation "Cap style for the marker."))
  (:documentation "A class representing marker types.
Instances are effectively immutable after creation.
Ported from matplotlib.markers.MarkerStyle."))

(defmethod initialize-instance :after ((ms marker-style) &key)
  "Generate the marker path based on the marker type."
  (setf (marker-style-filled-p ms) (not (eq (marker-style-fillstyle ms) :none)))
  (%recache-marker ms))

(defun %recache-marker (ms)
  "Regenerate the marker path and transform."
  (let ((marker (marker-style-marker ms)))
    (case marker
      (:o (%set-marker-circle ms))
      (:s (%set-marker-square ms))
      (:^ (%set-marker-triangle-up ms))
      (:v (%set-marker-triangle-down ms))
      (:< (%set-marker-triangle-left ms))
      (:> (%set-marker-triangle-right ms))
      (:d (%set-marker-diamond ms))
      (:plus (%set-marker-plus ms))
      (:x (%set-marker-x ms))
      (:star (%set-marker-star ms))
      (:vline (%set-marker-vline ms))
      (:hline (%set-marker-hline ms))
      (:point (%set-marker-point ms))
      (:none (%set-marker-nothing ms))
      (otherwise
       ;; Unknown marker — try to use it as nothing
       (%set-marker-nothing ms)))))

;;; ============================================================
;;; Individual marker generators
;;; ============================================================

(defun %set-marker-circle (ms)
  "Set up circle marker (o)."
  (setf (marker-style-path ms) (mpl.primitives:path-unit-circle)
        (marker-style-transform ms) (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))))

(defun %set-marker-point (ms)
  "Set up point marker (.)."
  (setf (marker-style-path ms) (mpl.primitives:path-unit-circle)
        (marker-style-transform ms) (mpl.primitives:make-affine-2d :scale '(0.25d0 0.25d0))))

(defun %set-marker-square (ms)
  "Set up square marker (s)."
  (setf (marker-style-path ms) (mpl.primitives:path-unit-rectangle)
        (marker-style-transform ms) (mpl.primitives:make-affine-2d :translate '(-0.5d0 -0.5d0)))
  (setf (marker-style-joinstyle ms) :miter))

(defun %set-marker-diamond (ms)
  "Set up diamond marker (d)."
  (setf (marker-style-path ms) (mpl.primitives:path-unit-rectangle))
  (let ((tr (mpl.primitives:make-affine-2d :translate '(-0.5d0 -0.5d0))))
    (mpl.primitives:affine-2d-rotate-deg tr 45.0d0)
    (setf (marker-style-transform ms) tr))
  (setf (marker-style-joinstyle ms) :miter))

(defun %make-triangle-path ()
  "Create the basic triangle path: vertices at (0,1), (-1,-1), (1,-1)."
  (mpl.primitives:make-path
   :vertices '((0.0 1.0) (-1.0 -1.0) (1.0 -1.0) (0.0 1.0))
   :closed t))

(defun %set-marker-triangle-up (ms)
  "Set up triangle-up marker (^)."
  (setf (marker-style-path ms) (%make-triangle-path)
        (marker-style-transform ms) (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0)))
  (setf (marker-style-joinstyle ms) :miter))

(defun %set-marker-triangle-down (ms)
  "Set up triangle-down marker (v)."
  (setf (marker-style-path ms) (%make-triangle-path))
  (let ((tr (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))))
    (mpl.primitives:affine-2d-rotate-deg tr 180.0d0)
    (setf (marker-style-transform ms) tr))
  (setf (marker-style-joinstyle ms) :miter))

(defun %set-marker-triangle-left (ms)
  "Set up triangle-left marker (<)."
  (setf (marker-style-path ms) (%make-triangle-path))
  (let ((tr (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))))
    (mpl.primitives:affine-2d-rotate-deg tr 90.0d0)
    (setf (marker-style-transform ms) tr))
  (setf (marker-style-joinstyle ms) :miter))

(defun %set-marker-triangle-right (ms)
  "Set up triangle-right marker (>)."
  (setf (marker-style-path ms) (%make-triangle-path))
  (let ((tr (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))))
    (mpl.primitives:affine-2d-rotate-deg tr 270.0d0)
    (setf (marker-style-transform ms) tr))
  (setf (marker-style-joinstyle ms) :miter))

(defun %set-marker-plus (ms)
  "Set up plus marker (+)."
  (let* ((verts '((0.0 -1.0) (0.0 1.0)    ; vertical bar
                  (0.0 0.0) (-1.0 0.0)     ; horizontal bar start
                  (-1.0 0.0) (1.0 0.0)))
         (codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+
                      mpl.primitives:+moveto+ mpl.primitives:+lineto+
                      mpl.primitives:+moveto+ mpl.primitives:+lineto+))
         ;; Build proper plus with 4 segments (as in matplotlib)
         (plus-verts '((0.0 -1.0) (0.0 1.0)
                       (0.0 0.0) (-1.0 0.0)
                       (0.0 0.0) (1.0 0.0)))
         (plus-codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+
                           mpl.primitives:+moveto+ mpl.primitives:+lineto+
                           mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
    (declare (ignore verts codes))
    (setf (marker-style-path ms)
          (mpl.primitives:make-path :vertices plus-verts :codes plus-codes)
          (marker-style-transform ms)
          (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))
          (marker-style-filled-p ms) nil)))

(defun %set-marker-x (ms)
  "Set up x marker (x)."
  (let* ((x-verts '((-1.0 -1.0) (1.0 1.0)
                     (-1.0 1.0) (1.0 -1.0)))
         (x-codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+
                        mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
    (setf (marker-style-path ms)
          (mpl.primitives:make-path :vertices x-verts :codes x-codes)
          (marker-style-transform ms)
          (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))
          (marker-style-filled-p ms) nil)))

(defun %set-marker-star (ms)
  "Set up star marker (*) — 5-pointed star."
  ;; Create a 5-pointed star using the unit circle
  (let* ((n 5)
         (inner-radius 0.381966d0) ;; golden ratio derived
         (verts (loop for i below (* 2 n)
                      for angle = (* (/ pi n) i)
                      for r = (if (evenp i) 1.0d0 inner-radius)
                      collect (list (* r (sin angle)) (* r (cos angle)))))
         ;; Close it
         (closed-verts (append verts (list (first verts)))))
    (setf (marker-style-path ms)
          (mpl.primitives:make-path :vertices closed-verts :closed t)
          (marker-style-transform ms)
          (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0)))
    (setf (marker-style-joinstyle ms) :bevel)))

(defun %set-marker-vline (ms)
  "Set up vertical line marker (|)."
  (setf (marker-style-path ms)
        (mpl.primitives:make-path :vertices '((0.0 -1.0) (0.0 1.0)))
        (marker-style-transform ms)
        (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))
        (marker-style-filled-p ms) nil))

(defun %set-marker-hline (ms)
  "Set up horizontal line marker (_)."
  (setf (marker-style-path ms)
        (mpl.primitives:make-path :vertices '((-1.0 0.0) (1.0 0.0)))
        (marker-style-transform ms)
        (mpl.primitives:make-affine-2d :scale '(0.5d0 0.5d0))
        (marker-style-filled-p ms) nil))

(defun %set-marker-nothing (ms)
  "Set up nothing marker (none)."
  (setf (marker-style-path ms)
        (mpl.primitives:make-path :vertices '())
        (marker-style-transform ms) nil
        (marker-style-filled-p ms) nil))

;;; ============================================================
;;; Public API: make-marker-path
;;; ============================================================

(defun make-marker-path (marker-keyword)
  "Return the path for the given marker keyword.
Example: (make-marker-path :o) → circle path."
  (let ((ms (make-instance 'marker-style :marker marker-keyword)))
    (marker-style-path ms)))

(defun make-marker-style (marker &key (fillstyle :full))
  "Create a new MarkerStyle instance."
  (make-instance 'marker-style :marker marker :fillstyle fillstyle))
