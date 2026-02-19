;;;; patches.lisp — Patch classes
;;;; Ported from matplotlib's patches.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Patch base class
;;; ============================================================

(defclass patch (artist)
  ((edgecolor :initarg :edgecolor
              :initform nil
              :accessor patch-edgecolor
              :documentation "Edge color (color spec or nil for default).")
   (facecolor :initarg :facecolor
              :initform nil
              :accessor patch-facecolor
              :documentation "Face color (color spec or nil for default).")
   (linewidth :initarg :linewidth
              :initform 1.0
              :accessor patch-linewidth
              :type real
              :documentation "Edge line width in points.")
   (linestyle :initarg :linestyle
              :initform :solid
              :accessor patch-linestyle
              :documentation "Edge line style: :solid, :dashed, :dashdot, :dotted, :none.")
   (antialiased :initarg :antialiased
                :initform t
                :accessor patch-antialiased
                :type boolean
                :documentation "Whether to use antialiased rendering.")
   (hatch :initarg :hatch
          :initform nil
          :accessor patch-hatch
          :documentation "Hatching pattern string or nil.")
   (fill :initarg :fill
         :initform t
         :accessor patch-fill
         :type boolean
         :documentation "Whether to fill the patch.")
   (capstyle :initarg :capstyle
             :initform :butt
             :accessor patch-capstyle
             :documentation "Cap style: :butt, :round, :projecting.")
   (joinstyle :initarg :joinstyle
              :initform :miter
              :accessor patch-joinstyle
              :documentation "Join style: :miter, :round, :bevel."))
  (:default-initargs :zorder 1)
  (:documentation "A 2D artist with face and edge color.
Abstract base for Rectangle, Circle, Ellipse, etc.
Ported from matplotlib.patches.Patch."))

(defmethod initialize-instance :after ((p patch) &key color)
  "Initialize patch colors. If COLOR is provided, sets both face and edge color."
  (when color
    (unless (patch-edgecolor p)
      (setf (patch-edgecolor p) color))
    (unless (patch-facecolor p)
      (setf (patch-facecolor p) color))))

;;; ============================================================
;;; Patch default methods
;;; ============================================================

(defmethod draw ((p patch) renderer)
  "Draw the patch using RENDERER.
Composes get-patch-transform (unit coords → data coords) with
get-artist-transform (data coords → display coords)."
  (unless (artist-visible p)
    (return-from draw))
  (let* ((path (get-path p))
         (patch-transform (get-patch-transform p))
         (artist-transform (get-artist-transform p))
         (transform (mpl.primitives:compose patch-transform artist-transform))
         (gc (make-gc :foreground (or (patch-edgecolor p) "black")
                      :linewidth (patch-linewidth p)
                      :linestyle (patch-linestyle p)
                      :alpha (or (artist-alpha p) 1.0)
                      :antialiased (patch-antialiased p)
                      :capstyle (patch-capstyle p)
                      :joinstyle (patch-joinstyle p))))
    (renderer-draw-path renderer gc path transform
                        :fill (and (patch-fill p) (patch-facecolor p))
                        :stroke (patch-edgecolor p)))
  (setf (artist-stale p) nil))

(defmethod get-extents ((p patch))
  "Return the bounding box of the patch."
  (mpl.primitives:path-get-extents (get-path p)))

;;; ============================================================
;;; Rectangle
;;; ============================================================

(defclass rectangle (patch)
  ((x0 :initarg :x0 :initform 0.0d0 :accessor rectangle-x0 :type double-float)
   (y0 :initarg :y0 :initform 0.0d0 :accessor rectangle-y0 :type double-float)
   (width :initarg :width :initform 0.0d0 :accessor rectangle-width :type double-float)
   (height :initarg :height :initform 0.0d0 :accessor rectangle-height :type double-float)
   (angle :initarg :angle :initform 0.0d0 :accessor rectangle-angle :type double-float
          :documentation "Rotation in degrees anti-clockwise."))
  (:documentation "A rectangle defined by an anchor point (xy), width, and height.
Ported from matplotlib.patches.Rectangle."))

(defmethod initialize-instance :after ((r rectangle) &key xy)
  "Initialize rectangle from xy pair."
  (when xy
    (setf (rectangle-x0 r) (float (if (listp xy) (first xy) (elt xy 0)) 1.0d0)
          (rectangle-y0 r) (float (if (listp xy) (second xy) (elt xy 1)) 1.0d0))))

(defmethod get-path ((r rectangle))
  "Return the unit rectangle path."
  (mpl.primitives:path-unit-rectangle))

(defmethod get-patch-transform ((r rectangle))
  "Return the transform scaling/translating the unit rectangle to actual position."
  (let ((x0 (rectangle-x0 r))
        (y0 (rectangle-y0 r))
        (w (rectangle-width r))
        (h (rectangle-height r))
        (angle (rectangle-angle r)))
    (let ((tr (mpl.primitives:make-affine-2d
               :scale (list w h)
               :translate (list x0 y0))))
      (when (/= angle 0.0d0)
        (mpl.primitives:affine-2d-rotate-deg-around tr x0 y0 angle))
      tr)))

;;; ============================================================
;;; Ellipse
;;; ============================================================

(defclass ellipse (patch)
  ((center :initarg :center :initform '(0.0d0 0.0d0) :accessor ellipse-center
           :documentation "Center (x, y) of the ellipse.")
   (width :initarg :width :initform 1.0d0 :accessor ellipse-width :type double-float
          :documentation "Total length of horizontal axis (diameter).")
   (height :initarg :height :initform 1.0d0 :accessor ellipse-height :type double-float
           :documentation "Total length of vertical axis (diameter).")
   (angle :initarg :angle :initform 0.0d0 :accessor ellipse-angle :type double-float
          :documentation "Rotation in degrees anti-clockwise."))
  (:documentation "A scale-free ellipse. Ported from matplotlib.patches.Ellipse."))

(defmethod initialize-instance :after ((e ellipse) &key xy)
  "Allow :xy as alias for :center."
  (when xy
    (setf (ellipse-center e) xy)))

(defmethod get-path ((e ellipse))
  "Return the unit circle path (scaled by patch transform)."
  (mpl.primitives:path-unit-circle))

(defmethod get-patch-transform ((e ellipse))
  "Return the transform scaling/rotating/translating the unit circle to the ellipse."
  (let* ((center (ellipse-center e))
         (cx (float (if (listp center) (first center) (elt center 0)) 1.0d0))
         (cy (float (if (listp center) (second center) (elt center 1)) 1.0d0))
         (w (ellipse-width e))
         (h (ellipse-height e))
         (angle (ellipse-angle e)))
    (let ((tr (mpl.primitives:make-affine-2d
               :scale (list (* w 0.5d0) (* h 0.5d0)))))
      (when (/= angle 0.0d0)
        (mpl.primitives:affine-2d-rotate-deg tr angle))
      (mpl.primitives:affine-2d-translate tr cx cy)
      tr)))

;;; ============================================================
;;; Circle
;;; ============================================================

(defclass circle (ellipse)
  ((radius :initarg :radius :initform 1.0d0 :accessor circle-radius :type double-float
           :documentation "Circle radius."))
  (:documentation "A circle defined by center and radius.
Ported from matplotlib.patches.Circle."))

(defmethod initialize-instance :after ((c circle) &key)
  "Set width and height from radius."
  (let ((d (* 2.0d0 (circle-radius c))))
    (setf (ellipse-width c) d
          (ellipse-height c) d)))

;;; ============================================================
;;; Polygon
;;; ============================================================

(defclass polygon (patch)
  ((xy :initarg :xy :initform nil :accessor polygon-xy
       :documentation "Vertices as list of (x y) pairs or 2D array.")
   (closed :initarg :closed :initform t :accessor polygon-closed :type boolean
           :documentation "Whether the polygon is closed.")
   (cached-path :initform nil :accessor polygon-cached-path))
  (:documentation "A general polygon patch.
Ported from matplotlib.patches.Polygon."))

(defmethod initialize-instance :after ((p polygon) &key)
  "Build polygon path from vertices."
  (%polygon-recache p))

(defun %polygon-recache (p)
  "Rebuild the cached path for polygon P."
  (let ((xy (polygon-xy p)))
    (when xy
      (setf (polygon-cached-path p)
            (mpl.primitives:make-path
             :vertices xy
             :closed (polygon-closed p))))))

(defmethod get-path ((p polygon))
  "Return the polygon path."
  (or (polygon-cached-path p)
      (progn (%polygon-recache p) (polygon-cached-path p))))

(defmethod (setf polygon-xy) :after (value (p polygon))
  (declare (ignore value))
  (%polygon-recache p)
  (setf (artist-stale p) t))

;;; ============================================================
;;; Wedge
;;; ============================================================

(defclass wedge (patch)
  ((center :initarg :center :initform '(0.0d0 0.0d0) :accessor wedge-center
           :documentation "Center (x, y) of the wedge.")
   (r :initarg :r :initform 1.0d0 :accessor wedge-r :type double-float
      :documentation "Outer radius.")
   (theta1 :initarg :theta1 :initform 0.0d0 :accessor wedge-theta1 :type double-float
           :documentation "Start angle in degrees.")
   (theta2 :initarg :theta2 :initform 360.0d0 :accessor wedge-theta2 :type double-float
           :documentation "End angle in degrees.")
   (width :initarg :width :initform nil :accessor wedge-width
          :documentation "Width of the annular wedge, or nil for full wedge."))
  (:documentation "Wedge shaped patch. Ported from matplotlib.patches.Wedge."))

(defmethod get-path ((w wedge))
  "Return the wedge path."
  (mpl.primitives:path-wedge (wedge-theta1 w) (wedge-theta2 w)))

(defmethod get-patch-transform ((w wedge))
  "Return the transform scaling/translating the unit wedge."
  (let* ((center (wedge-center w))
         (cx (float (if (listp center) (first center) (elt center 0)) 1.0d0))
         (cy (float (if (listp center) (second center) (elt center 1)) 1.0d0))
         (r (wedge-r w)))
    (let ((tr (mpl.primitives:make-affine-2d :scale (list r r))))
      (mpl.primitives:affine-2d-translate tr cx cy)
      tr)))

;;; ============================================================
;;; Arc
;;; ============================================================

(defclass arc (ellipse)
  ((theta1 :initarg :theta1 :initform 0.0d0 :accessor arc-theta1 :type double-float
           :documentation "Start angle in degrees.")
   (theta2 :initarg :theta2 :initform 360.0d0 :accessor arc-theta2 :type double-float
           :documentation "End angle in degrees."))
  (:documentation "An elliptical arc. Ported from matplotlib.patches.Arc."))

(defmethod get-path ((a arc))
  "Return the arc path."
  (mpl.primitives:path-arc (arc-theta1 a) (arc-theta2 a)))

;;; ============================================================
;;; PathPatch
;;; ============================================================

(defclass path-patch (patch)
  ((path :initarg :path :initform nil :accessor path-patch-path
         :documentation "The Path object defining this patch."))
  (:documentation "A general polycurve path patch.
Ported from matplotlib.patches.PathPatch."))

(defmethod get-path ((pp path-patch))
  "Return the stored path."
  (path-patch-path pp))

;;; ============================================================
;;; FancyBboxPatch
;;; ============================================================

(defclass fancy-bbox-patch (patch)
  ((x0 :initarg :x0 :initform 0.0d0 :accessor fancy-bbox-x0 :type double-float)
   (y0 :initarg :y0 :initform 0.0d0 :accessor fancy-bbox-y0 :type double-float)
   (width :initarg :width :initform 1.0d0 :accessor fancy-bbox-width :type double-float)
   (height :initarg :height :initform 1.0d0 :accessor fancy-bbox-height :type double-float)
   (boxstyle :initarg :boxstyle :initform :square :accessor fancy-bbox-boxstyle
             :documentation "Box style: :square, :round, :round4, :roundtooth, :sawtooth.")
   (pad :initarg :pad :initform 0.3d0 :accessor fancy-bbox-pad :type double-float
        :documentation "Padding amount."))
  (:documentation "A fancy rectangle with optional rounded corners.
Ported from matplotlib.patches.FancyBboxPatch."))

(defmethod initialize-instance :after ((fb fancy-bbox-patch) &key xy)
  "Allow :xy initarg."
  (when xy
    (setf (fancy-bbox-x0 fb) (float (if (listp xy) (first xy) (elt xy 0)) 1.0d0)
          (fancy-bbox-y0 fb) (float (if (listp xy) (second xy) (elt xy 1)) 1.0d0))))

(defmethod get-path ((fb fancy-bbox-patch))
  "Return the rectangle path (simplified — no round corners yet)."
  (mpl.primitives:path-unit-rectangle))

(defmethod get-patch-transform ((fb fancy-bbox-patch))
  "Return transform for the fancy bbox."
  (let ((x0 (fancy-bbox-x0 fb))
        (y0 (fancy-bbox-y0 fb))
        (w (fancy-bbox-width fb))
        (h (fancy-bbox-height fb)))
    (mpl.primitives:make-affine-2d
     :scale (list w h)
     :translate (list x0 y0))))
