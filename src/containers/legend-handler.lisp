;;;; legend-handler.lisp — Legend handler classes for creating legend entries
;;;; Ported from matplotlib's legend_handler.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Handler base class
;;; ============================================================

(defclass handler-base ()
  ((xpad :initarg :xpad :initform 0.0 :accessor handler-xpad :type real)
   (ypad :initarg :ypad :initform 0.0 :accessor handler-ypad :type real))
  (:documentation "Base class for legend handlers.
Handlers create legend entry artists from original plot artists.
Ported from matplotlib.legend_handler.HandlerBase."))

(defgeneric create-legend-artists (handler legend orig-handle
                                   xdescent ydescent width height fontsize transform)
  (:documentation "Create artist(s) for the legend entry representing ORIG-HANDLE.
Returns a list of artists to be drawn in the legend box."))

(defgeneric legend-artist (handler legend orig-handle fontsize handlebox)
  (:documentation "Return the artist that this handler generates for the given original handle."))

(defmethod legend-artist ((h handler-base) legend orig-handle fontsize handlebox)
  "Default legend-artist: compute drawing area and delegate to create-legend-artists."
  (let* ((xdescent (* (handler-xpad h) fontsize))
         (ydescent (* (handler-ypad h) fontsize))
         (width (max 1.0d0 (- (float handlebox 1.0d0) (* (handler-xpad h) fontsize))))
         (height (max 1.0d0 (float fontsize 1.0d0)))
         (transform mpl.primitives:*identity-transform*))
    (create-legend-artists h legend orig-handle
                           xdescent ydescent width height fontsize transform)))

;;; ============================================================
;;; HandlerLine2D — creates a small line segment for legend entry
;;; ============================================================

(defclass handler-line-2d (handler-base)
  ((numpoints :initarg :numpoints :initform 2 :accessor handler-numpoints :type fixnum
              :documentation "Number of points in the legend line."))
  (:documentation "Handler for Line2D objects.
Creates a small line segment with the same style as the original line.
Ported from matplotlib.legend_handler.HandlerLine2D."))

(defmethod create-legend-artists ((h handler-line-2d) legend orig-handle
                                  xdescent ydescent width height fontsize transform)
  "Create a small Line2D for the legend entry."
  (declare (ignore legend ydescent transform))
  (let* ((numpoints (handler-numpoints h))
         ;; Create x positions for the legend line
         (xdata (if (<= numpoints 1)
                    (list (/ width 2.0d0))
                    (loop for i below numpoints
                          collect (+ (- xdescent)
                                     (* (/ (float i 1.0d0) (float (1- numpoints) 1.0d0))
                                        width)))))
         ;; Y position is at the middle of the handlebox
         (ydata (loop for i below numpoints
                      collect (/ height 2.0d0)))
         ;; Copy properties from original handle
         (color (if (typep orig-handle 'mpl.rendering:line-2d)
                    (mpl.rendering:line-2d-color orig-handle)
                    "C0"))
         (linewidth (if (typep orig-handle 'mpl.rendering:line-2d)
                        (mpl.rendering:line-2d-linewidth orig-handle)
                        1.5))
         (linestyle (if (typep orig-handle 'mpl.rendering:line-2d)
                        (mpl.rendering:line-2d-linestyle orig-handle)
                        :solid))
         (legend-line (make-instance 'mpl.rendering:line-2d
                                     :xdata xdata
                                     :ydata ydata
                                     :color color
                                     :linewidth linewidth
                                     :linestyle linestyle
                                     :marker :none
                                     :zorder 0)))
    (list legend-line)))

;;; ============================================================
;;; HandlerPatch — creates a small patch for legend entry
;;; ============================================================

(defclass handler-patch (handler-base)
  ((patch-func :initarg :patch-func :initform nil :accessor handler-patch-func
               :documentation "Optional function to create custom patch."))
  (:documentation "Handler for Patch objects.
Creates a small rectangle with the same face/edge color as the original patch.
Ported from matplotlib.legend_handler.HandlerPatch."))

(defmethod create-legend-artists ((h handler-patch) legend orig-handle
                                  xdescent ydescent width height fontsize transform)
  "Create a small Rectangle for the legend entry."
  (declare (ignore legend fontsize transform))
  (let* ((facecolor (if (typep orig-handle 'mpl.rendering:patch)
                        (or (mpl.rendering:patch-facecolor orig-handle) "C0")
                        "C0"))
         (edgecolor (if (typep orig-handle 'mpl.rendering:patch)
                        (or (mpl.rendering:patch-edgecolor orig-handle) "black")
                        "black"))
         (linewidth (if (typep orig-handle 'mpl.rendering:patch)
                        (mpl.rendering:patch-linewidth orig-handle)
                        1.0))
         (rect (make-instance 'mpl.rendering:rectangle
                              :x0 (- xdescent)
                              :y0 (- ydescent)
                              :width width
                              :height height
                              :facecolor facecolor
                              :edgecolor edgecolor
                              :linewidth linewidth
                              :zorder 0)))
    (list rect)))

;;; ============================================================
;;; HandlerLineCollection — creates line for collection
;;; ============================================================

(defclass handler-line-collection (handler-base)
  ((numpoints :initarg :numpoints :initform 2 :accessor handler-lc-numpoints :type fixnum))
  (:documentation "Handler for LineCollection objects.
Creates a representative line for the collection.
Ported from matplotlib.legend_handler.HandlerLineCollection."))

(defmethod create-legend-artists ((h handler-line-collection) legend orig-handle
                                  xdescent ydescent width height fontsize transform)
  "Create a Line2D representing a line collection."
  (declare (ignore legend ydescent transform))
  (let* ((numpoints (handler-lc-numpoints h))
         (xdata (if (<= numpoints 1)
                    (list (/ width 2.0d0))
                    (loop for i below numpoints
                          collect (+ (- xdescent)
                                     (* (/ (float i 1.0d0) (float (1- numpoints) 1.0d0))
                                        width)))))
         (ydata (loop for i below numpoints
                      collect (/ height 2.0d0)))
         ;; Use first color from the collection, or default
         (color (if (and (typep orig-handle 'mpl.rendering:artist)
                         (slot-exists-p orig-handle 'mpl.rendering::color))
                    (slot-value orig-handle 'mpl.rendering::color)
                    "C0"))
         (legend-line (make-instance 'mpl.rendering:line-2d
                                     :xdata xdata
                                     :ydata ydata
                                     :color color
                                     :linewidth 1.5
                                     :linestyle :solid
                                     :marker :none
                                     :zorder 0)))
    (list legend-line)))

;;; ============================================================
;;; HandlerPathCollection — creates marker for scatter collection
;;; ============================================================

(defclass handler-path-collection (handler-base)
  ((numpoints :initarg :numpoints :initform 3 :accessor handler-pc-numpoints :type fixnum
              :documentation "Number of markers to show."))
  (:documentation "Handler for PathCollection objects (scatter plots).
Creates representative markers for the collection.
Ported from matplotlib.legend_handler.HandlerPathCollection."))

(defmethod create-legend-artists ((h handler-path-collection) legend orig-handle
                                  xdescent ydescent width height fontsize transform)
  "Create circles representing a path/scatter collection."
  (declare (ignore legend ydescent transform))
  (let* ((numpoints (handler-pc-numpoints h))
         ;; Create marker circles
         (facecolor (if (typep orig-handle 'mpl.rendering:patch)
                        (or (mpl.rendering:patch-facecolor orig-handle) "C0")
                        (if (and (typep orig-handle 'mpl.rendering:artist)
                                 (slot-exists-p orig-handle 'mpl.rendering::color))
                            (slot-value orig-handle 'mpl.rendering::color)
                            "C0")))
         (marker-size (* fontsize 0.3d0))
         (artists
           (loop for i below numpoints
                 for x = (+ (- xdescent)
                            (* (/ (+ (float i 1.0d0) 0.5d0)
                                  (float numpoints 1.0d0))
                               width))
                 for y = (/ height 2.0d0)
                 collect (make-instance 'mpl.rendering:circle
                                        :center (list x y)
                                        :radius marker-size
                                        :facecolor facecolor
                                        :edgecolor facecolor
                                        :linewidth 0.5
                                        :zorder 0))))
    artists))

;;; ============================================================
;;; Default handler map
;;; ============================================================

(defparameter *default-handler-map*
  (list (cons 'mpl.rendering:line-2d (make-instance 'handler-line-2d))
        (cons 'mpl.rendering:patch (make-instance 'handler-patch))
        (cons 'mpl.rendering:rectangle (make-instance 'handler-patch))
        (cons 'mpl.rendering:circle (make-instance 'handler-path-collection))
        (cons 'mpl.rendering:polygon (make-instance 'handler-patch)))
  "Default mapping from artist types to legend handlers.")

(defun get-legend-handler (handle &optional (handler-map *default-handler-map*))
  "Get the legend handler for HANDLE from HANDLER-MAP.
Tries exact type match, then walks known supertypes."
  (let ((handle-type (type-of handle)))
    ;; First try exact type match
    (let ((entry (assoc handle-type handler-map)))
      (when entry (return-from get-legend-handler (cdr entry))))
    ;; Try typep-based matching against each handler map entry
    (dolist (entry handler-map)
      (when (typep handle (car entry))
        (return-from get-legend-handler (cdr entry))))
    ;; Default: try patch handler for any patch subclass
    (when (typep handle 'mpl.rendering:patch)
      (return-from get-legend-handler (make-instance 'handler-patch)))
    ;; Default: try line handler for any line subclass
    (when (typep handle 'mpl.rendering:line-2d)
      (return-from get-legend-handler (make-instance 'handler-line-2d)))
    ;; No handler found
    nil))
