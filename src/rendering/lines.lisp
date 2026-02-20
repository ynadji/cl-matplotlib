;;;; lines.lisp — Line2D class
;;;; Ported from matplotlib's lines.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Line style helpers
;;; ============================================================

(defparameter *line-styles*
  '((:solid . "-")
    (:dashed . "--")
    (:dashdot . "-.")
    (:dotted . ":")
    (:none . ""))
  "Valid line styles as keyword/string pairs.")

(defparameter *draw-styles*
  '(:default :steps-mid :steps-pre :steps-post)
  "Valid draw styles for Line2D.")

;;; ============================================================
;;; Line2D class
;;; ============================================================

(defclass line-2d (artist)
  ((xdata :initarg :xdata
          :initform #()
          :accessor line-2d-xdata
          :documentation "X coordinate data (vector of numbers).")
   (ydata :initarg :ydata
          :initform #()
          :accessor line-2d-ydata
          :documentation "Y coordinate data (vector of numbers).")
   (linewidth :initarg :linewidth
              :initform 1.5
              :accessor line-2d-linewidth
              :type real
              :documentation "Line width in points.")
   (linestyle :initarg :linestyle
              :initform :solid
              :accessor line-2d-linestyle
              :documentation "Line style: :solid, :dashed, :dashdot, :dotted, :none.")
   (color :initarg :color
          :initform "C0"
          :accessor line-2d-color
          :documentation "Line color (color spec).")
   (marker :initarg :marker
           :initform :none
           :accessor line-2d-marker
           :documentation "Marker style keyword or MarkerStyle instance.")
   (markersize :initarg :markersize
               :initform 6.0
               :accessor line-2d-markersize
               :type real
               :documentation "Marker size in points.")
   (markeredgecolor :initarg :markeredgecolor
                    :initform nil
                    :accessor line-2d-markeredgecolor
                    :documentation "Marker edge color. Nil = use line color.")
   (markerfacecolor :initarg :markerfacecolor
                    :initform nil
                    :accessor line-2d-markerfacecolor
                    :documentation "Marker face color. Nil = use line color.")
   (markeredgewidth :initarg :markeredgewidth
                    :initform 1.0
                    :accessor line-2d-markeredgewidth
                    :type real
                    :documentation "Marker edge width in points.")
   (drawstyle :initarg :drawstyle
              :initform :default
              :accessor line-2d-drawstyle
              :documentation "Draw style: :default, :steps-mid, :steps-pre, :steps-post.")
   (antialiased :initarg :antialiased
                :initform t
                :accessor line-2d-antialiased
                :type boolean
                :documentation "Whether to use antialiased rendering.")
   (dash-capstyle :initarg :dash-capstyle
                  :initform :butt
                  :accessor line-2d-dash-capstyle
                  :documentation "Cap style for dashed lines.")
   (solid-capstyle :initarg :solid-capstyle
                   :initform :projecting
                   :accessor line-2d-solid-capstyle
                   :documentation "Cap style for solid lines.")
   (dash-joinstyle :initarg :dash-joinstyle
                   :initform :round
                   :accessor line-2d-dash-joinstyle
                   :documentation "Join style for dashed lines.")
   (solid-joinstyle :initarg :solid-joinstyle
                    :initform :round
                    :accessor line-2d-solid-joinstyle
                    :documentation "Join style for solid lines.")
   (pickradius :initarg :pickradius
               :initform 5
               :accessor line-2d-pickradius
               :type real
               :documentation "Pick radius in points.")
   (path :initform nil
         :accessor line-2d-path
         :documentation "Cached path for the line data."))
  (:default-initargs :zorder 2)
  (:documentation "A 2D line — can have both a solid linestyle connecting
vertices and a marker at each vertex. Ported from matplotlib.lines.Line2D."))

(defmethod initialize-instance :after ((line line-2d) &key xdata ydata)
  "Convert line data to proper vectors."
  (when xdata
    (setf (slot-value line 'xdata) (%coerce-line-data xdata)))
  (when ydata
    (setf (slot-value line 'ydata) (%coerce-line-data ydata)))
  ;; Build the path cache
  (%line-2d-recache line))

(defun %coerce-line-data (data)
  "Convert DATA to a simple vector of double-floats."
  (etypecase data
    ((simple-array double-float (*)) data)
    (vector
     (let ((result (make-array (length data) :element-type 'double-float)))
       (dotimes (i (length data))
         (setf (aref result i) (float (elt data i) 1.0d0)))
       result))
    (list
     (let* ((n (length data))
            (result (make-array n :element-type 'double-float)))
       (loop for v in data
             for i from 0
             do (setf (aref result i) (float v 1.0d0)))
       result))))

(defun %line-2d-recache (line)
  "Rebuild the cached path for LINE."
  (let* ((xdata (line-2d-xdata line))
         (ydata (line-2d-ydata line))
         (n (min (length xdata) (length ydata))))
    (if (zerop n)
        (setf (line-2d-path line)
              (mpl.primitives:make-path :vertices '()))
        (let ((verts (make-array (list n 2) :element-type 'double-float)))
          (dotimes (i n)
            (setf (aref verts i 0) (aref xdata i)
                  (aref verts i 1) (aref ydata i)))
          (setf (line-2d-path line)
                (mpl.primitives:make-path :vertices verts))))))

(defmethod (setf line-2d-xdata) :after (value (line line-2d))
  (declare (ignore value))
  (%line-2d-recache line)
  (setf (artist-stale line) t))

(defmethod (setf line-2d-ydata) :after (value (line line-2d))
  (declare (ignore value))
  (%line-2d-recache line)
  (setf (artist-stale line) t))

;;; ============================================================
;;; Line2D get-path
;;; ============================================================

(defmethod get-path ((line line-2d))
  "Return the path for this line."
  (or (line-2d-path line)
      (progn (%line-2d-recache line)
             (line-2d-path line))))

;;; ============================================================
;;; Line2D draw method
;;; ============================================================

(defmethod draw ((line line-2d) renderer)
  "Draw the line using RENDERER."
  (unless (artist-visible line)
    (return-from draw))
  (let* ((path (get-path line))
         (transform (get-artist-transform line))
         (gc (make-gc :foreground (line-2d-color line)
                      :linewidth (line-2d-linewidth line)
                      :linestyle (line-2d-linestyle line)
                      :alpha (or (artist-alpha line) 1.0)
                      :antialiased (line-2d-antialiased line)
                      :joinstyle (if (eq (line-2d-linestyle line) :solid)
                                     (line-2d-solid-joinstyle line)
                                     (line-2d-dash-joinstyle line))
                      :capstyle (if (eq (line-2d-linestyle line) :solid)
                                    (line-2d-solid-capstyle line)
                                    (line-2d-dash-capstyle line)))))
    ;; Draw the line path
    (renderer-draw-path renderer gc path transform :stroke t)
    ;; Draw markers at each vertex if marker is set
    (let ((marker (line-2d-marker line)))
      (when (and marker (not (eq marker :none)))
        (let* (;; Normalize marker aliases (e.g. :circle -> :o)
               (marker-key (case marker
                             (:circle :o)
                             (otherwise marker)))
               (marker-path (make-marker-path marker-key))
               (markersize (line-2d-markersize line))
               ;; Convert markersize from points to pixels (matching matplotlib behavior)
               (markersize-px (mpl.backends:points-to-pixels renderer (float markersize 1.0d0)))
               (marker-trans (mpl.primitives:make-affine-2d
                              :scale (list markersize-px markersize-px)))
               ;; Determine face color for filled markers
               ;; Inline list to avoid compile-time warning (markers.lisp loads after lines.lisp)
               (filled-p (member marker-key '(:point :o :v :^ :< :> :s :d :star)))
               (face-color (when filled-p
                             (let* ((fc (or (line-2d-markerfacecolor line)
                                            (line-2d-color line)))
                                    (rgba (mpl.colors:to-rgba fc)))
                               (list (elt rgba 0) (elt rgba 1)
                                     (elt rgba 2) (elt rgba 3)))))
               ;; Create a GC for the marker (edge color + edge width)
               (marker-gc (make-gc :foreground (or (line-2d-markeredgecolor line)
                                                   (line-2d-color line))
                                   :linewidth (line-2d-markeredgewidth line)
                                   :alpha (or (artist-alpha line) 1.0))))
          (mpl.backends:draw-markers renderer marker-gc marker-path marker-trans
                                     path transform face-color)))))
  (setf (artist-stale line) nil))

;;; ============================================================
;;; Convenience: set-data
;;; ============================================================

(defun line-2d-set-data (line xdata ydata)
  "Set both X and Y data at once."
  (setf (slot-value line 'xdata) (%coerce-line-data xdata))
  (setf (slot-value line 'ydata) (%coerce-line-data ydata))
  (%line-2d-recache line)
  (setf (artist-stale line) t)
  line)
