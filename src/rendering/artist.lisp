;;;; artist.lisp — Artist base class and draw protocol
;;;; Ported from matplotlib's artist.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Draw protocol — generic function
;;; ============================================================

(defgeneric draw (artist renderer)
  (:documentation "Draw ARTIST using RENDERER.
Each artist subclass must implement a method for this generic function.
The renderer provides primitive drawing operations (draw-path, draw-text, etc.)."))

(defgeneric get-path (artist)
  (:documentation "Return the path (mpl-path) that defines this artist's geometry."))

(defgeneric get-patch-transform (artist)
  (:documentation "Return the transform mapping patch coordinates to data coordinates.
Defaults to identity."))

(defgeneric get-artist-transform (artist)
  (:documentation "Return the full transform for this artist (patch-transform + data-transform)."))

(defgeneric get-extents (artist)
  (:documentation "Return the bounding box (bbox) of this artist."))

(defgeneric stale-p (artist)
  (:documentation "Return T if the artist needs redrawing."))

;;; ============================================================
;;; Artist base class
;;; ============================================================

(defclass artist ()
  ((transform :initarg :transform
              :initform nil
              :accessor artist-transform
              :documentation "Affine2D transform for this artist.")
   (transform-set-p :initform nil
                     :accessor artist-transform-set-p
                     :documentation "Whether the transform has been explicitly set.")
   (alpha :initarg :alpha
          :initform nil
          :accessor artist-alpha
          :type (or null (double-float 0.0d0 1.0d0))
          :documentation "Transparency: 0.0 = fully transparent, 1.0 = opaque.")
   (visible :initarg :visible
            :initform t
            :accessor artist-visible
            :type boolean
            :documentation "Whether this artist is visible.")
   (clip-box :initarg :clip-box
             :initform nil
             :accessor artist-clip-box
             :documentation "Bounding box for clipping (bbox struct).")
   (clip-path :initarg :clip-path
              :initform nil
              :accessor artist-clip-path
              :documentation "Path for clipping (mpl-path struct).")
   (clip-on :initarg :clip-on
            :initform t
            :accessor artist-clip-on
            :type boolean
            :documentation "Whether clipping is enabled.")
   (label :initarg :label
          :initform ""
          :accessor artist-label
          :type string
          :documentation "String label for this artist (used in legends).")
   (zorder :initarg :zorder
           :initform 0
           :accessor artist-zorder
           :type real
           :documentation "Drawing order: lower zorder artists are drawn first.")
   (animated :initarg :animated
             :initform nil
             :accessor artist-animated
             :type boolean
             :documentation "Whether this artist is used in animation.")
   (picker :initarg :picker
           :initform nil
           :accessor artist-picker
           :documentation "Picker function or tolerance for event handling.")
   (url :initarg :url
        :initform nil
        :accessor artist-url
        :type (or null string)
        :documentation "URL associated with this artist.")
   (gid :initarg :gid
        :initform nil
        :accessor artist-gid
        :type (or null string)
        :documentation "Group ID for SVG output.")
   (rasterized :initarg :rasterized
               :initform nil
               :accessor artist-rasterized
               :type boolean
               :documentation "Whether to force rasterized (bitmap) rendering.")
   (sketch-params :initarg :sketch-params
                  :initform nil
                  :accessor artist-sketch-params
                  :documentation "Sketch effect parameters: (scale length randomness) or nil.")
   (stale :initform t
          :accessor artist-stale
          :type boolean
          :documentation "Whether this artist needs to be redrawn.")
   (axes :initform nil
         :accessor artist-axes
         :documentation "The Axes instance this artist belongs to.")
   (figure :initform nil
           :accessor artist-figure
           :documentation "The Figure instance this artist belongs to.")
   (children :initform nil
             :accessor artist-children
             :documentation "Child artists contained by this artist."))
  (:documentation "Abstract base class for all objects that render into a FigureCanvas.
Ported from matplotlib.artist.Artist. All visible elements in a figure
are subclasses of Artist."))

(defmethod initialize-instance :after ((a artist) &key)
  "Initialize common artist properties."
  ;; Defaults are all handled by slot initforms
  (values))

;;; ============================================================
;;; Default method implementations
;;; ============================================================

(defmethod draw ((a artist) renderer)
  "Default draw method — does nothing. Subclasses must override."
  (declare (ignore renderer))
  (values))

(defmethod get-patch-transform ((a artist))
  "Default patch transform is identity."
  mpl.primitives:*identity-transform*)

(defmethod get-artist-transform ((a artist))
  "Return the artist's transform, defaulting to identity."
  (or (artist-transform a) mpl.primitives:*identity-transform*))

(defmethod get-extents ((a artist))
  "Default: return null bbox."
  (mpl.primitives:bbox-null))

(defmethod stale-p ((a artist))
  (artist-stale a))

;;; ============================================================
;;; Artist property helpers
;;; ============================================================

(defmethod (setf artist-alpha) :after (value (a artist))
  "Mark artist stale when alpha changes."
  (declare (ignore value))
  (setf (artist-stale a) t))

(defmethod (setf artist-visible) :after (value (a artist))
  "Mark artist stale when visibility changes."
  (declare (ignore value))
  (setf (artist-stale a) t))

(defmethod (setf artist-transform) :after (value (a artist))
  "Mark transform as explicitly set."
  (declare (ignore value))
  (setf (artist-transform-set-p a) t)
  (setf (artist-stale a) t))

(defmethod (setf artist-zorder) :after (value (a artist))
  "Mark artist stale when zorder changes."
  (declare (ignore value))
  (setf (artist-stale a) t))

(defun artist-set (artist &rest properties)
  "Set multiple properties on ARTIST at once.
PROPERTIES is a plist of keyword/value pairs.
Example: (artist-set line :color \"red\" :linewidth 2.0)"
  (loop for (key value) on properties by #'cddr
        do (case key
             (:alpha (setf (artist-alpha artist) value))
             (:visible (setf (artist-visible artist) value))
             (:label (setf (artist-label artist) value))
             (:zorder (setf (artist-zorder artist) value))
             (:transform (setf (artist-transform artist) value))
             (:clip-box (setf (artist-clip-box artist) value))
             (:clip-path (setf (artist-clip-path artist) value))
             (:clip-on (setf (artist-clip-on artist) value))
             (:animated (setf (artist-animated artist) value))
             (:picker (setf (artist-picker artist) value))
             (:url (setf (artist-url artist) value))
             (:gid (setf (artist-gid artist) value))
             (:rasterized (setf (artist-rasterized artist) value))
             (:sketch-params (setf (artist-sketch-params artist) value))
             (otherwise (error "Unknown artist property: ~S" key))))
  artist)

;;; ============================================================
;;; Mock renderer for testing
;;; ============================================================

(defclass mock-renderer ()
  ((calls :initform nil
          :accessor mock-renderer-calls
          :documentation "List of recorded draw calls."))
  (:documentation "A mock renderer that records draw calls for testing."))

(defun make-mock-renderer ()
  "Create a new mock renderer for testing."
  (make-instance 'mock-renderer))

(defun mock-renderer-record (renderer call-type &rest args)
  "Record a draw call on the mock renderer."
  (push (cons call-type args) (mock-renderer-calls renderer)))

(defgeneric renderer-draw-path (renderer gc path transform &key fill stroke)
  (:documentation "Draw a path on the renderer."))

(defgeneric renderer-draw-text (renderer gc x y text &key angle)
  (:documentation "Draw text on the renderer."))

(defgeneric renderer-draw-image (renderer gc x y image)
  (:documentation "Draw an image on the renderer."))

(defmethod renderer-draw-path ((r mock-renderer) gc path transform &key fill stroke)
  (mock-renderer-record r :draw-path gc path transform :fill fill :stroke stroke))

(defmethod renderer-draw-text ((r mock-renderer) gc x y text &key angle)
  (mock-renderer-record r :draw-text gc x y text :angle angle))

(defmethod renderer-draw-image ((r mock-renderer) gc x y image)
  (mock-renderer-record r :draw-image gc x y image))

;;; ============================================================
;;; Graphics context (simplified)
;;; ============================================================

(defclass graphics-context ()
  ((foreground :initarg :foreground :initform nil :accessor gc-foreground)
   (background :initarg :background :initform nil :accessor gc-background)
   (linewidth :initarg :linewidth :initform 1.0 :accessor gc-linewidth :type real)
   (linestyle :initarg :linestyle :initform :solid :accessor gc-linestyle)
   (alpha :initarg :alpha :initform 1.0 :accessor gc-alpha :type real)
   (capstyle :initarg :capstyle :initform :butt :accessor gc-capstyle)
   (joinstyle :initarg :joinstyle :initform :miter :accessor gc-joinstyle)
   (clip-rectangle :initarg :clip-rectangle :initform nil :accessor gc-clip-rectangle)
   (clip-path :initarg :clip-path :initform nil :accessor gc-clip-path)
   (antialiased :initarg :antialiased :initform t :accessor gc-antialiased :type boolean)
   (dashes :initarg :dashes :initform nil :accessor gc-dashes)
   (hatch :initarg :hatch :initform nil :accessor gc-hatch)
   (url :initarg :url :initform nil :accessor gc-url))
  (:documentation "Graphics context — state for drawing operations.
Ported from matplotlib.backend_bases.GraphicsContextBase."))

(defun make-gc (&rest args &key foreground background linewidth linestyle
                               alpha capstyle joinstyle clip-rectangle clip-path
                               antialiased dashes hatch url)
  "Create a new graphics context with the given properties."
  (declare (ignore foreground background linewidth linestyle
                   alpha capstyle joinstyle clip-rectangle clip-path
                   antialiased dashes hatch url))
  (apply #'make-instance 'graphics-context args))
