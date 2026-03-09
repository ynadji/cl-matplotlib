;;;; quiver.lisp — QuiverCollection for vector field (arrow) plots
;;;; Ported from matplotlib's quiver.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; QuiverCollection — collection of quiver arrows
;;; ============================================================

(defclass quiver-collection (poly-collection)
  ((x-data :initarg :x-data :accessor quiver-x-data
           :documentation "List of x positions for arrow origins.")
   (y-data :initarg :y-data :accessor quiver-y-data
           :documentation "List of y positions for arrow origins.")
   (u-data :initarg :u-data :accessor quiver-u-data
           :documentation "List of u (x-component) values for arrows.")
   (v-data :initarg :v-data :accessor quiver-v-data
           :documentation "List of v (y-component) values for arrows.")
   (scale  :initarg :scale  :initform nil :accessor quiver-scale
           :documentation "Arrow scale factor. NIL = auto-computed.")
   (width  :initarg :width  :initform nil :accessor quiver-width
           :documentation "Shaft width in data units. NIL = auto-computed.")
   (pivot  :initarg :pivot  :initform :tail :accessor quiver-pivot
           :documentation "Arrow pivot point: :TAIL, :MIDDLE, or :TIP.")
   (axes-ref :initarg :axes-ref :initform nil :accessor quiver-axes-ref
             :documentation "Reference to the axes for computing data limits."))
  (:documentation "Collection of quiver arrows for vector field plots.
Extends poly-collection; arrow polygons are computed at draw time
based on axes data limits for proper auto-scaling."))

;;; ============================================================
;;; Arrow polygon construction
;;; ============================================================

(defun %make-arrow-verts (x y u v shaft-width headwidth-factor headlength-factor
                          scale-factor pivot)
  "Build 7-vertex arrow polygon in data coordinates.

X, Y — arrow origin position.
U, V — vector components.
SHAFT-WIDTH — width of arrow shaft in data units.
HEADWIDTH-FACTOR — head width as multiple of shaft-width (default 3).
HEADLENGTH-FACTOR — head length as multiple of shaft-width (default 5).
SCALE-FACTOR — arrows scaled by magnitude / scale-factor.
PIVOT — :TAIL, :MIDDLE, or :TIP for pivot point.

Returns a list of 7 (x y) pairs defining the arrow polygon."
  (let* ((mag (sqrt (+ (* u u) (* v v))))
         (theta (atan v u))
         (arrow-len (/ mag scale-factor))
         (hw (* headwidth-factor shaft-width))
         (hl (* headlength-factor shaft-width))
         (shaft-len (max 0.0d0 (- arrow-len hl)))
         ;; Pivot offset
         (x-offset (ecase pivot
                     (:tail 0.0d0)
                     (:middle (* -0.5d0 arrow-len))
                     (:tip (- arrow-len))))
         ;; 7 vertices in local frame (pointing right along +x)
         (half-sw (* 0.5d0 shaft-width))
         (local-verts (list
                       (list x-offset (- half-sw))                         ; tail left
                       (list (+ x-offset shaft-len) (- half-sw))           ; shaft bottom right
                       (list (+ x-offset shaft-len) (- hw))               ; head bottom outer
                       (list (+ x-offset arrow-len) 0.0d0)               ; tip
                       (list (+ x-offset shaft-len) hw)                   ; head top outer
                       (list (+ x-offset shaft-len) half-sw)              ; shaft top right
                       (list x-offset half-sw)))                           ; tail right
         ;; Rotate by theta and translate to (x, y)
         (cos-t (cos theta))
         (sin-t (sin theta)))
    (mapcar (lambda (pt)
              (let ((lx (first pt)) (ly (second pt)))
                (list (+ x (- (* lx cos-t) (* ly sin-t)))
                      (+ y (+ (* lx sin-t) (* ly cos-t))))))
            local-verts)))

;;; ============================================================
;;; Draw override — compute arrows at draw time
;;; ============================================================

(defmethod draw ((qc quiver-collection) renderer)
  "Draw quiver arrows. Computes arrow geometry from data at draw time."
  (unless (artist-visible qc)
    (return-from draw))
  (let* ((x-data (quiver-x-data qc))
         (y-data (quiver-y-data qc))
         (u-data (quiver-u-data qc))
         (v-data (quiver-v-data qc))
         (n (length x-data)))
    (when (zerop n)
      (return-from draw))
    ;; Compute data range for auto-scaling
    (let* ((x-min (reduce #'min x-data))
           (x-max (reduce #'max x-data))
           (y-min (reduce #'min y-data))
           (y-max (reduce #'max y-data))
           (x-range (max 1.0d-10 (- x-max x-min)))
           (y-range (max 1.0d-10 (- y-max y-min)))
           (span (max x-range y-range))
           ;; Compute shaft width
           (shaft-width (or (quiver-width qc) (* 0.005d0 span)))
           ;; Compute scale factor
           (scale-factor
             (if (quiver-scale qc)
                 (float (quiver-scale qc) 1.0d0)
                 ;; Auto: mean magnitude / (0.1 * span)
                 (let ((total-mag 0.0d0)
                       (count 0))
                   (dotimes (i n)
                     (let ((ui (float (elt u-data i) 1.0d0))
                           (vi (float (elt v-data i) 1.0d0)))
                       (let ((mag (sqrt (+ (* ui ui) (* vi vi)))))
                         (when (> mag 0.0d0)
                           (incf total-mag mag)
                           (incf count)))))
                   (if (zerop count)
                       1.0d0
                       (let ((mean-mag (/ total-mag (float count 1.0d0))))
                         (/ mean-mag (* 0.1d0 span)))))))
           (pivot (quiver-pivot qc))
           (headwidth-factor 3.0d0)
           (headlength-factor 5.0d0)
           ;; Build arrow polygons
           (arrow-verts
             (loop for i from 0 below n
                   for xi = (float (elt x-data i) 1.0d0)
                   for yi = (float (elt y-data i) 1.0d0)
                   for ui = (float (elt u-data i) 1.0d0)
                   for vi = (float (elt v-data i) 1.0d0)
                   for mag = (sqrt (+ (* ui ui) (* vi vi)))
                   ;; Skip zero-length and invalid arrows
                   when (and (> mag 0.0d0)
                             (not (float-features:float-nan-p ui))
                             (not (float-features:float-nan-p vi))
                             (not (float-features:float-infinity-p ui))
                             (not (float-features:float-infinity-p vi)))
                   collect (%make-arrow-verts xi yi ui vi
                                              shaft-width headwidth-factor
                                              headlength-factor scale-factor
                                              pivot))))
      ;; Set verts and delegate to poly-collection draw with clipping
      (setf (poly-collection-verts qc) arrow-verts)
      ;; Compute clip rectangle from axes bounding box
      (let ((clip-rect (let ((axes (quiver-axes-ref qc)))
                        (if axes
                            (multiple-value-bind (x0 y0 w h)
                                (cl-matplotlib.containers::%compute-display-bbox axes)
                              (mpl.primitives:make-bbox x0 y0 (+ x0 w) (+ y0 h)))
                            nil))))
        ;; Draw polygons with clipping
        (let* ((paths (collection-get-paths qc))
               (facecolors (collection-facecolors qc))
               (edgecolors (collection-edgecolors qc))
               (linewidths (collection-linewidths qc))
               (linestyles (collection-linestyles qc))
               (antialiaseds (collection-antialiaseds qc))
               (transform (get-artist-transform qc))
               (alpha (or (artist-alpha qc) 1.0d0))
               (n (length paths)))
          (when (plusp n)
            (dotimes (i n)
              (let* ((path (elt paths i))
                     (facecolor (or (%coll-nth (collection-facecolors qc) i) "C0"))
                     (edgecolor (%coll-nth (collection-edgecolors qc) i))
                     (linewidth (or (%coll-nth (collection-linewidths qc) i) 1.0))
                     (linestyle (or (%coll-nth (collection-linestyles qc) i) :solid))
                     (antialiased (let ((aa (%coll-nth (collection-antialiaseds qc) i)))
                                    (if (null (collection-antialiaseds qc)) t aa))))
                (let ((gc (make-gc :foreground edgecolor
                                   :background facecolor
                                   :linewidth linewidth
                                   :linestyle linestyle
                                   :alpha (float alpha 1.0)
                                   :antialiased antialiased
                                   :capstyle (collection-capstyle qc)
                                   :joinstyle (collection-joinstyle qc)
                                   :clip-rectangle clip-rect)))
                  (renderer-draw-path renderer gc path transform
                                      :fill facecolor
                                      :stroke edgecolor))))
            (setf (artist-stale qc) nil)))))))
