;;;; annotation.lisp — Annotation class with arrow support
;;;; Ported from matplotlib's text.py Annotation class
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Annotation class — Text with optional arrow to a point
;;; ============================================================

(defclass annotation (text-artist)
  ((xy :initarg :xy :initform '(0.0d0 0.0d0) :accessor annotation-xy
       :documentation "The point (x y) being annotated.")
   (xytext :initarg :xytext :initform nil :accessor annotation-xytext
           :documentation "Position (x y) for the text. Defaults to xy if nil.")
   (xycoords :initarg :xycoords :initform :data :accessor annotation-xycoords
             :documentation "Coordinate system for xy: :data, :axes, :figure.")
   (textcoords :initarg :textcoords :initform nil :accessor annotation-textcoords
               :documentation "Coordinate system for xytext. Defaults to xycoords if nil.")
   (arrowprops :initarg :arrowprops :initform nil :accessor annotation-arrowprops
               :documentation "Plist of arrow properties:
:arrowstyle, :connectionstyle, :color, :linewidth, :shrinkA, :shrinkB.")
   (bbox :initarg :bbox :initform nil :accessor annotation-bbox
         :documentation "Plist for text bounding box: :boxstyle, :facecolor, :edgecolor, :pad.")
   (arrow-patch :initform nil :accessor annotation-arrow-patch
                :documentation "The FancyArrowPatch created for the arrow, or nil."))
  (:default-initargs :zorder 3)
  (:documentation "An Annotation is a Text that can refer to a specific position xy.
Optionally an arrow pointing from the text to xy can be drawn.
Ported from matplotlib.text.Annotation."))

(defmethod initialize-instance :after ((ann annotation) &key)
  "Initialize the annotation. Set up text position and arrow patch."
  ;; Default xytext to xy
  (unless (annotation-xytext ann)
    (setf (annotation-xytext ann) (annotation-xy ann)))
  ;; Default textcoords to xycoords
  (unless (annotation-textcoords ann)
    (setf (annotation-textcoords ann) (annotation-xycoords ann)))
  ;; Set text position to xytext
  (let ((xytext (annotation-xytext ann)))
    (setf (text-x ann) (float (first xytext) 1.0d0)
          (text-y ann) (float (second xytext) 1.0d0)))
  ;; Create arrow patch if arrowprops specified and xytext != xy
  (when (annotation-arrowprops ann)
    (let* ((xy (annotation-xy ann))
           (xytext (annotation-xytext ann)))
      ;; Only create arrow if text and point positions differ
      (when (or (/= (float (first xytext) 1.0d0) (float (first xy) 1.0d0))
                (/= (float (second xytext) 1.0d0) (float (second xy) 1.0d0)))
        (%create-annotation-arrow ann)))))

(defun %create-annotation-arrow (ann)
  "Create the FancyArrowPatch for annotation ANN based on arrowprops."
  (let* ((props (annotation-arrowprops ann))
         (arrowstyle (or (getf props :arrowstyle) :->))
         (connectionstyle (or (getf props :connectionstyle) :arc3))
         (color (or (getf props :color) "black"))
         (linewidth (or (getf props :linewidth) 1.5))
         (shrinkA (or (getf props :shrinkA) 0.0d0))
         (shrinkB (or (getf props :shrinkB) 3.0d0))
         (mutation-scale (or (getf props :mutation-scale) 1.0d0))
         (xytext (annotation-xytext ann))
         (xy (annotation-xy ann))
         (arrow (make-instance 'fancy-arrow-patch
                               :posA (list (float (first xytext) 1.0d0)
                                           (float (second xytext) 1.0d0))
                               :posB (list (float (first xy) 1.0d0)
                                           (float (second xy) 1.0d0))
                               :arrowstyle arrowstyle
                               :connectionstyle connectionstyle
                               :edgecolor color
                               :facecolor color
                               :linewidth linewidth
                               :shrinkA (float shrinkA 1.0d0)
                               :shrinkB (float shrinkB 1.0d0)
                               :mutation-scale (float mutation-scale 1.0d0))))
    (setf (annotation-arrow-patch ann) arrow)))

;;; ============================================================
;;; Annotation draw method
;;; ============================================================

(defmethod draw ((ann annotation) renderer)
  "Draw the annotation: text + optional arrow."
  (unless (artist-visible ann)
    (return-from draw))
  ;; Draw arrow first (below text)
  (when (annotation-arrow-patch ann)
    (let ((arrow (annotation-arrow-patch ann)))
      ;; Copy the transform from annotation to arrow
      (when (artist-transform ann)
        (setf (artist-transform arrow) (artist-transform ann)))
      (draw arrow renderer)))
  ;; Draw text bounding box if bbox specified
  (when (annotation-bbox ann)
    (%draw-annotation-bbox ann renderer))
  ;; Draw the text itself (via parent text-artist draw)
  (let ((gc (make-gc :foreground (text-color ann)
                     :alpha (or (artist-alpha ann) 1.0)
                     :linewidth (text-fontsize ann))))
    (renderer-draw-text renderer gc
                        (text-x ann) (text-y ann)
                        (text-text ann)
                        :angle (text-rotation ann)))
  (setf (artist-stale ann) nil))

(defun %draw-annotation-bbox (ann renderer)
  "Draw the bounding box around annotation text."
  (let* ((bbox-props (annotation-bbox ann))
         (boxstyle (or (getf bbox-props :boxstyle) :square))
         (facecolor (or (getf bbox-props :facecolor) "wheat"))
         (edgecolor (or (getf bbox-props :edgecolor) "black"))
         (pad (or (getf bbox-props :pad) 0.3d0))
         (x (text-x ann))
         (y (text-y ann))
         (fs (text-fontsize ann))
         ;; Estimate text dimensions
         (text-width (* 0.6d0 fs (length (text-text ann))))
         (text-height (* 1.2d0 fs))
         ;; Create box
         (style (make-box-style boxstyle :pad (float pad 1.0d0)))
         (box-path (box-transmute style x y text-width text-height))
         (gc (make-gc :foreground edgecolor
                      :linewidth 1.0
                      :alpha (or (artist-alpha ann) 1.0))))
    (renderer-draw-path renderer gc box-path (artist-transform ann)
                        :fill facecolor
                        :stroke edgecolor)))

;;; ============================================================
;;; Annotation accessors
;;; ============================================================

(defun annotation-set-position (ann xytext)
  "Set the text position of annotation ANN to XYTEXT."
  (setf (annotation-xytext ann) xytext)
  (setf (text-x ann) (float (first xytext) 1.0d0)
        (text-y ann) (float (second xytext) 1.0d0))
  ;; Update arrow if present
  (when (annotation-arrow-patch ann)
    (setf (fancy-arrow-posA (annotation-arrow-patch ann))
          (list (float (first xytext) 1.0d0) (float (second xytext) 1.0d0)))
    (setf (fancy-arrow-cached-path (annotation-arrow-patch ann)) nil))
  (setf (artist-stale ann) t)
  ann)

(defun annotation-set-target (ann xy)
  "Set the target point of annotation ANN to XY."
  (setf (annotation-xy ann) xy)
  ;; Update arrow if present
  (when (annotation-arrow-patch ann)
    (setf (fancy-arrow-posB (annotation-arrow-patch ann))
          (list (float (first xy) 1.0d0) (float (second xy) 1.0d0)))
    (setf (fancy-arrow-cached-path (annotation-arrow-patch ann)) nil))
  (setf (artist-stale ann) t)
  ann)
