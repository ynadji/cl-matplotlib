;;;; text.lisp — Text class
;;;; Ported from matplotlib's text.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Text class
;;; ============================================================

(defclass text-artist (artist)
  ((x :initarg :x :initform 0.0d0 :accessor text-x :type double-float
      :documentation "X position of the text anchor.")
   (y :initarg :y :initform 0.0d0 :accessor text-y :type double-float
      :documentation "Y position of the text anchor.")
   (text :initarg :text :initform "" :accessor text-text :type string
         :documentation "The text content.")
   (color :initarg :color :initform "black" :accessor text-color
          :documentation "Text color.")
   (fontsize :initarg :fontsize :initform 12.0 :accessor text-fontsize :type real
             :documentation "Font size in points.")
   (fontfamily :initarg :fontfamily :initform "sans-serif" :accessor text-fontfamily
               :type string
               :documentation "Font family name.")
   (fontweight :initarg :fontweight :initform :normal :accessor text-fontweight
               :documentation "Font weight: :normal, :bold, :light, etc.")
   (fontstyle :initarg :fontstyle :initform :normal :accessor text-fontstyle
              :documentation "Font style: :normal, :italic, :oblique.")
   (rotation :initarg :rotation :initform 0.0 :accessor text-rotation :type real
             :documentation "Text rotation in degrees.")
   (horizontalalignment :initarg :horizontalalignment
                        :initform :left
                        :accessor text-horizontalalignment
                        :documentation "Horizontal alignment: :left, :center, :right.")
   (verticalalignment :initarg :verticalalignment
                      :initform :baseline
                      :accessor text-verticalalignment
                      :documentation "Vertical alignment: :top, :center, :bottom, :baseline.")
   (multialignment :initarg :multialignment
                   :initform nil
                   :accessor text-multialignment
                   :documentation "Alignment for multi-line text: :left, :center, :right or nil.")
   (linespacing :initarg :linespacing
                :initform 1.2
                :accessor text-linespacing
                :type real
                :documentation "Line spacing multiplier.")
   (wrap :initarg :wrap :initform nil :accessor text-wrap :type boolean
         :documentation "Whether to wrap long lines.")
   (rotation-mode :initarg :rotation-mode
                  :initform nil
                  :accessor text-rotation-mode
                  :documentation "Rotation mode: nil, :default, :anchor.")
   (usetex :initarg :usetex
           :initform nil
           :accessor text-usetex
           :type boolean
           :documentation "Whether to use TeX for rendering."))
  (:default-initargs :zorder 3)
  (:documentation "Handle storing and drawing of text in window or data coordinates.
Ported from matplotlib.text.Text."))

(defmethod initialize-instance :after ((txt text-artist) &key)
  "Ensure numeric coordinates are doubles."
  (setf (text-x txt) (float (text-x txt) 1.0d0)
        (text-y txt) (float (text-y txt) 1.0d0)))

;;; ============================================================
;;; Text draw method
;;; ============================================================

(defmethod draw ((txt text-artist) renderer)
  "Draw the text using RENDERER."
  (unless (artist-visible txt)
    (return-from draw))
  (when (zerop (length (text-text txt)))
    (return-from draw))
  (let ((gc (make-gc :foreground (text-color txt)
                     :linewidth (text-fontsize txt)
                     :alpha (or (artist-alpha txt) 1.0))))
    (renderer-draw-text renderer gc
                        (text-x txt) (text-y txt)
                        (text-text txt)
                        :angle (text-rotation txt)))
  (setf (artist-stale txt) nil))

;;; ============================================================
;;; Convenience accessors (aliases matching matplotlib)
;;; ============================================================

(defun text-ha (txt)
  "Shorthand for horizontal alignment."
  (text-horizontalalignment txt))

(defun text-va (txt)
  "Shorthand for vertical alignment."
  (text-verticalalignment txt))

(defun text-set-position (txt x y)
  "Set the text position."
  (setf (text-x txt) (float x 1.0d0)
        (text-y txt) (float y 1.0d0))
  (setf (artist-stale txt) t)
  txt)
