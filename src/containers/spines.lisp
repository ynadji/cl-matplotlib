;;;; spines.lisp — Spine class: border rendering for axes
;;;; Ported from matplotlib's spines.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Spine — axis border line
;;; ============================================================

(defclass spine (mpl.rendering:patch)
  ((spine-axes :initarg :axes
               :initform nil
               :accessor spine-axes
               :documentation "The Axes instance containing the spine.")
   (spine-type :initarg :spine-type
               :initform "left"
               :accessor spine-spine-type
               :type string
               :documentation "Spine type: left, right, bottom, top.")
   (spine-path :initarg :path
               :initform nil
               :accessor spine-path
               :documentation "The Path instance used to draw the spine.")
   (spine-visible :initarg :spine-visible
                  :initform t
                  :accessor spine-visible-p
                  :type boolean
                  :documentation "Whether this spine is visible.")
   (spine-position :initform nil
                   :accessor spine-position-spec
                   :documentation "Position specification: nil, (:outward offset), (:axes fraction), (:data value).")
   (spine-bounds :initform nil
                 :accessor spine-bounds
                 :documentation "Custom bounds or nil for full extent."))
  (:default-initargs :facecolor "none" :edgecolor "black" :linewidth 1.0 :zorder 2.5)
  (:documentation "An axis spine — the line noting the data area boundaries.
Ported from matplotlib.spines.Spine."))

(defmethod initialize-instance :after ((sp spine) &key)
  "Initialize spine defaults."
  (setf (mpl.rendering:patch-facecolor sp) "none")
  ;; Create default path if not provided
  (unless (spine-path sp)
    (setf (spine-path sp)
          (%make-spine-path (spine-spine-type sp)))))

(defun %make-spine-path (spine-type)
  "Create the default path for SPINE-TYPE."
  (cond
    ((string= spine-type "left")
     ;; Vertical line from (0,0) to (0,1)
     (mpl.primitives:make-path
      :vertices (make-array '(2 2)
                            :element-type 'double-float
                            :initial-contents '((0.0d0 0.0d0) (0.0d0 1.0d0)))))
    ((string= spine-type "right")
     (mpl.primitives:make-path
      :vertices (make-array '(2 2)
                            :element-type 'double-float
                            :initial-contents '((1.0d0 0.0d0) (1.0d0 1.0d0)))))
    ((string= spine-type "bottom")
     (mpl.primitives:make-path
      :vertices (make-array '(2 2)
                            :element-type 'double-float
                            :initial-contents '((0.0d0 0.0d0) (1.0d0 0.0d0)))))
    ((string= spine-type "top")
     (mpl.primitives:make-path
      :vertices (make-array '(2 2)
                            :element-type 'double-float
                            :initial-contents '((0.0d0 1.0d0) (1.0d0 1.0d0)))))
    (t
     ;; Default: bottom
     (mpl.primitives:make-path
      :vertices (make-array '(2 2)
                            :element-type 'double-float
                            :initial-contents '((0.0d0 0.0d0) (1.0d0 0.0d0)))))))

(defmethod mpl.rendering:get-path ((sp spine))
  "Return the spine path."
  (spine-path sp))

;;; ============================================================
;;; Spine drawing
;;; ============================================================

(defun %snap-spine-path (path transform spine-type)
  "Transform PATH to display coordinates and snap to pixel centers.
For vertical spines (left/right), snap x to pixel center.
For horizontal spines (top/bottom), snap y to pixel center.
This avoids antialiasing gray from sub-pixel boundaries."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (n (array-dimension verts 0))
         (new-verts (make-array (list n 2) :element-type 'double-float))
         (vertical-p (or (string= spine-type "left")
                         (string= spine-type "right"))))
    (dotimes (i n)
      (let* ((pt (mpl.primitives:transform-point
                  transform
                  (list (aref verts i 0) (aref verts i 1))))
             (px (aref pt 0))
             (py (aref pt 1)))
        (if vertical-p
            ;; Vertical spine: snap x to pixel center
            (setf (aref new-verts i 0) (+ (floor px) 0.5d0)
                  (aref new-verts i 1) py)
            ;; Horizontal spine: snap y to pixel center
            (setf (aref new-verts i 0) px
                  (aref new-verts i 1) (- (floor py) 0.5d0)))))
    (mpl.primitives:make-path
     :vertices new-verts
     :codes (mpl.primitives:mpl-path-codes path))))

(defmethod mpl.rendering:draw ((sp spine) renderer)
  "Draw the spine line."
  (unless (and (mpl.rendering:artist-visible sp)
               (spine-visible-p sp))
    (return-from mpl.rendering:draw))
  (let* ((ax (spine-axes sp))
         (ec (or (mpl.rendering:patch-edgecolor sp) "black"))
         (lw (mpl.rendering:patch-linewidth sp))
         (path (spine-path sp))
         ;; Spine is drawn in axes coordinates (0-1)
         (transform (when ax (axes-base-trans-axes ax))))
    (when (and path renderer transform)
      ;; Snap spine path to pixel centers to avoid antialiasing gray
      (let* ((snapped-path (%snap-spine-path path transform
                                             (spine-spine-type sp)))
             (gc (mpl.rendering:make-gc
                  :foreground ec
                  :linewidth lw
                  :alpha (or (mpl.rendering:artist-alpha sp) 1.0)
                  :capstyle :projecting)))
        (mpl.rendering:renderer-draw-path renderer gc snapped-path
                                          (mpl.primitives:make-identity-transform)
                                          :stroke t))))
  (setf (mpl.rendering:artist-stale sp) nil))

;;; ============================================================
;;; Spine visibility control
;;; ============================================================

(defun spine-set-visible (sp visible)
  "Set whether the spine is visible."
  (setf (spine-visible-p sp) visible)
  (setf (mpl.rendering:artist-visible sp) visible)
  (setf (mpl.rendering:artist-stale sp) t))

(defun spine-set-position (sp position)
  "Set spine position. POSITION is (:outward offset), (:axes fraction), or (:data value)."
  (setf (spine-position-spec sp) position)
  (setf (mpl.rendering:artist-stale sp) t))

(defun spine-set-color (sp color)
  "Set spine color."
  (setf (mpl.rendering:patch-edgecolor sp) color)
  (setf (mpl.rendering:artist-stale sp) t))

(defun spine-set-linewidth (sp lw)
  "Set spine line width."
  (setf (mpl.rendering:patch-linewidth sp) (float lw 1.0d0))
  (setf (mpl.rendering:artist-stale sp) t))

;;; ============================================================
;;; Spines container — dict-like mapping of spine-type → Spine
;;; ============================================================

(defclass spines ()
  ((spine-dict :initform (make-hash-table :test 'equal)
               :accessor spines-dict
               :documentation "Hash table of spine-type → Spine."))
  (:documentation "Dict-like container for Spine objects.
Ported from matplotlib.spines.Spines."))

(defun make-spines (axes)
  "Create the default set of 4 spines for AXES."
  (let ((container (make-instance 'spines)))
    (dolist (stype '("left" "right" "bottom" "top"))
      (let ((sp (make-instance 'spine :axes axes :spine-type stype)))
        (setf (mpl.rendering:artist-axes sp) axes)
        (setf (gethash stype (spines-dict container)) sp)))
    container))

(defun spines-ref (container spine-type)
  "Get the spine of SPINE-TYPE from CONTAINER."
  (gethash spine-type (spines-dict container)))

(defun (setf spines-ref) (value container spine-type)
  "Set the spine of SPINE-TYPE in CONTAINER."
  (setf (gethash spine-type (spines-dict container)) value))

(defun spines-all (container)
  "Return a list of all spine objects."
  (loop for sp being the hash-values of (spines-dict container)
        collect sp))

(defun spines-draw-all (container renderer)
  "Draw all visible spines."
  (dolist (sp (spines-all container))
    (when (and (mpl.rendering:artist-visible sp)
               (spine-visible-p sp))
      (mpl.rendering:draw sp renderer))))

;;; ============================================================
;;; Print representation
;;; ============================================================

(defmethod print-object ((sp spine) stream)
  "Print a readable representation of the spine."
  (print-unreadable-object (sp stream :type t)
    (format stream "~A" (spine-spine-type sp))))
