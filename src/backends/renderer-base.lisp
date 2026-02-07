;;;; renderer-base.lisp — RendererBase protocol definition
;;;; Ported from matplotlib's backend_bases.py RendererBase class.
;;;; Defines the generic function protocol that all backends must implement.

(in-package #:cl-matplotlib.backends)

;;; ============================================================
;;; RendererBase protocol — generic functions
;;; ============================================================

(defgeneric draw-path (renderer gc path transform &optional rgbface)
  (:documentation
   "Draw a path using the given affine transform.

RENDERER — the backend renderer instance.
GC — a graphics-context with line style, color, clip, etc.
PATH — an mpl-path struct (vertices + codes).
TRANSFORM — an affine transform applied to path vertices.
RGBFACE — optional RGBA fill color (list of 3-4 floats), or NIL for no fill."))

(defgeneric draw-image (renderer gc x y im)
  (:documentation
   "Draw an RGBA image IM at position (X, Y).

IM is a flat (simple-array (unsigned-byte 8) (*)) in RGBA row-major order.
The image dimensions must be provided as (width . height) in the image metadata
or passed alongside. X, Y are in display coordinates."))

(defgeneric draw-text (renderer gc x y s prop angle &optional ismath)
  (:documentation
   "Draw text string S at position (X, Y).

GC — graphics context.
PROP — font properties (or path to TTF file).
ANGLE — rotation angle in degrees.
ISMATH — whether the string uses mathtext (default NIL)."))

(defgeneric draw-markers (renderer gc marker-path marker-trans path trans &optional rgbface)
  (:documentation
   "Draw a marker at each of PATH's vertices.

The base (fallback) implementation makes multiple calls to DRAW-PATH.
Backends may override for optimization.

GC — graphics context.
MARKER-PATH — the marker shape path.
MARKER-TRANS — transform applied to the marker.
PATH — the positions where markers should be drawn.
TRANS — transform applied to PATH vertices.
RGBFACE — optional fill color for the marker."))

(defgeneric draw-path-collection (renderer gc paths all-transforms
                                  offsets offset-trans facecolors edgecolors
                                  linewidths linestyles antialiaseds)
  (:documentation
   "Draw a collection of paths efficiently.

PATHS — list of mpl-paths.
ALL-TRANSFORMS — list of per-item transforms (or nil).
OFFSETS — list of (x y) offset positions.
OFFSET-TRANS — transform applied to each offset.
FACECOLORS, EDGECOLORS — lists of (r g b a) color specs.
LINEWIDTHS, LINESTYLES, ANTIALIASEDS — per-item drawing properties."))

(defgeneric draw-gouraud-triangles (renderer gc triangles-array colors-array transform)
  (:documentation
   "Draw a series of Gouraud-shaded triangles.

TRIANGLES-ARRAY — (N, 3, 2) array of triangle vertex positions.
COLORS-ARRAY — (N, 3, 4) array of RGBA colors per vertex.
TRANSFORM — affine transform applied to vertices."))

(defgeneric get-canvas-width-height (renderer)
  (:documentation
   "Return the canvas dimensions as (values width height)."))

(defgeneric points-to-pixels (renderer points)
  (:documentation
   "Convert typographic points to display pixels.
Default: pixels = points * dpi / 72.0"))

(defgeneric renderer-clear (renderer)
  (:documentation
   "Clear the renderer canvas to white/transparent background."))

(defgeneric renderer-option-image-nocomposite (renderer)
  (:documentation
   "Return T if the renderer does not support compositing.
Most renderers should return NIL."))

;;; ============================================================
;;; RendererBase — abstract base class
;;; ============================================================

(defclass renderer-base ()
  ((width :initarg :width
          :initform 640
          :accessor renderer-width
          :type fixnum
          :documentation "Canvas width in pixels.")
   (height :initarg :height
           :initform 480
           :accessor renderer-height
           :type fixnum
           :documentation "Canvas height in pixels.")
   (dpi :initarg :dpi
        :initform 100.0
        :accessor renderer-dpi
        :type real
        :documentation "Dots per inch."))
  (:documentation "Abstract base class for all renderers.
Subclasses must implement at minimum: draw-path, draw-image, draw-text."))

;;; ============================================================
;;; Default method implementations
;;; ============================================================

(defmethod get-canvas-width-height ((r renderer-base))
  "Return canvas dimensions as (values width height)."
  (values (renderer-width r) (renderer-height r)))

(defmethod points-to-pixels ((r renderer-base) points)
  "Convert typographic points to pixels: pixels = points * dpi / 72.0"
  (* points (/ (renderer-dpi r) 72.0)))

(defmethod renderer-option-image-nocomposite ((r renderer-base))
  "Default: compositing is supported."
  nil)

(defmethod draw-markers ((r renderer-base) gc marker-path marker-trans path trans &optional rgbface)
  "Default draw-markers: iterate path vertices, draw marker at each.
This is the fallback; backends may override for performance."
  (let* ((segments (mpl.primitives:path-iter-segments path))
         (verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0)))
    (declare (ignore segments))
    ;; Walk through vertices, only draw at MOVETO/LINETO positions
    (dotimes (i n)
      (let ((code (if codes (aref codes i)
                      (if (zerop i)
                          mpl.primitives:+moveto+
                          mpl.primitives:+lineto+))))
        (when (or (= code mpl.primitives:+moveto+)
                  (= code mpl.primitives:+lineto+))
          (let ((x (aref verts i 0))
                (y (aref verts i 1)))
            ;; Create a translate transform for this position
            ;; For now, just offset the marker-path vertices
            (draw-path r gc marker-path
                       (mpl.primitives:make-affine-2d :translate (list x y))
                       rgbface)))))))

(defmethod draw-path-collection ((r renderer-base) gc paths all-transforms
                                  offsets offset-trans facecolors edgecolors
                                  linewidths linestyles antialiaseds)
  "Default draw-path-collection: iterate and draw each path individually."
  (let* ((n-offsets (if offsets (length offsets) 0))
         (n-paths (if paths (length paths) 0))
         (n-items (max n-offsets n-paths 0)))
    (dotimes (i n-items)
      (let* ((path-idx (if (zerop n-paths) 0 (mod i n-paths)))
             (path (when (plusp n-paths) (elt paths path-idx)))
             (rgbface (when facecolors
                        (elt facecolors (mod i (length facecolors))))))
        (when path
          (draw-path r gc path nil rgbface))))))

(defmethod draw-gouraud-triangles ((r renderer-base) gc triangles-array colors-array transform)
  "Default: signal not-implemented. Backends should override."
  (declare (ignore gc triangles-array colors-array transform))
  (warn "draw-gouraud-triangles not implemented for ~A" (type-of r)))

;;; ============================================================
;;; Canvas protocol — generic functions
;;; ============================================================

(defgeneric canvas-draw (canvas)
  (:documentation "Clear canvas and draw the figure. Called before saving."))

(defgeneric print-png (canvas filename)
  (:documentation "Render figure and save to PNG file at FILENAME."))

(defgeneric get-renderer (canvas)
  (:documentation "Return or create the renderer for this canvas."))

;;; ============================================================
;;; Canvas base class
;;; ============================================================

(defclass canvas-base ()
  ((width :initarg :width
          :initform 640
          :accessor canvas-width
          :type fixnum)
   (height :initarg :height
           :initform 480
           :accessor canvas-height
           :type fixnum)
   (dpi :initarg :dpi
        :initform 100.0
        :accessor canvas-dpi
        :type real)
   (renderer :initform nil
             :accessor canvas-renderer
             :documentation "Cached renderer instance.")
   (figure :initarg :figure
           :initform nil
           :accessor canvas-figure
           :documentation "The figure associated with this canvas."))
  (:documentation "Base class for figure canvases. Manages rendering to output formats."))

;;; ============================================================
;;; Helper: make-graphics-context convenience constructor
;;; ============================================================

(defun make-graphics-context (&key (linewidth 1.0) (edgecolor nil) (facecolor nil)
                                   (alpha 1.0) (linestyle :solid) (dashes nil)
                                   (capstyle :butt) (joinstyle :miter)
                                   (clip-rectangle nil) (clip-path nil)
                                   (antialiased t) (hatch nil))
  "Create a graphics-context with matplotlib-style keyword args.
Colors can be strings (looked up via to-rgba) or RGBA lists."
  (let ((gc (make-instance 'mpl.rendering:graphics-context
                           :linewidth linewidth
                           :alpha alpha
                           :linestyle linestyle
                           :dashes dashes
                           :capstyle capstyle
                           :joinstyle joinstyle
                           :clip-rectangle clip-rectangle
                           :clip-path clip-path
                           :antialiased antialiased
                           :hatch hatch)))
    ;; Handle color conversion
    (when edgecolor
      (setf (mpl.rendering:gc-foreground gc)
            (if (listp edgecolor) edgecolor
                (multiple-value-list (mpl.colors:to-rgba edgecolor)))))
    (when facecolor
      (setf (mpl.rendering:gc-background gc)
            (if (listp facecolor) facecolor
                (multiple-value-list (mpl.colors:to-rgba facecolor)))))
    gc))
