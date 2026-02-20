;;;; axis.lisp — XAxis/YAxis classes for tick generation, label positioning, grid lines
;;;; Ported from matplotlib's axis.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Tick class — represents a single tick mark with label
;;; ============================================================

(defclass tick (mpl.rendering:artist)
  ((tick-axes :initarg :axes
              :initform nil
              :accessor tick-axes
              :documentation "Parent axes.")
   (tick-loc :initarg :loc
             :initform 0.0d0
             :accessor tick-loc
             :type double-float
             :documentation "Tick location in data coordinates.")
   (tick-major-p :initarg :major
                 :initform t
                 :accessor tick-major-p
                 :type boolean
                 :documentation "Whether this is a major tick.")
   (tick-size :initarg :size
              :initform nil
              :accessor tick-size
              :documentation "Tick size in points (nil = use default).")
   (tick-width :initarg :width
               :initform nil
               :accessor tick-width
               :documentation "Tick line width (nil = use default).")
   (tick-color :initarg :color
               :initform "black"
               :accessor tick-color
               :documentation "Tick mark color.")
   (tick-direction :initarg :direction
                   :initform :out
                   :accessor tick-direction
                   :documentation "Tick direction: :out, :in, :inout.")
   (tick-pad :initarg :pad
             :initform 3.5d0
             :accessor tick-pad
             :type double-float
             :documentation "Padding between tick and label in points.")
   (tick-label-text :initform ""
                    :accessor tick-label-text
                    :type string
                    :documentation "The formatted label string.")
   (tick-label-fontsize :initarg :label-fontsize
                        :initform 10.0
                        :accessor tick-label-fontsize
                        :documentation "Label font size in points.")
   (tick-label-color :initarg :label-color
                     :initform "black"
                     :accessor tick-label-color
                     :documentation "Label text color.")
   (tick-gridline-visible :initarg :grid-on
                          :initform nil
                          :accessor tick-gridline-visible-p
                          :type boolean
                          :documentation "Whether to draw gridline at this tick.")
   (tick-grid-color :initarg :grid-color
                    :initform "#b0b0b0"
                    :accessor tick-grid-color
                    :documentation "Grid line color.")
   (tick-grid-linewidth :initarg :grid-linewidth
                        :initform 0.8
                        :accessor tick-grid-linewidth
                        :documentation "Grid line width.")
   (tick-grid-linestyle :initarg :grid-linestyle
                        :initform :solid
                        :accessor tick-grid-linestyle
                        :documentation "Grid line style.")
   (tick-grid-alpha :initarg :grid-alpha
                     :initform 1.0
                     :accessor tick-grid-alpha
                    :documentation "Grid line alpha."))
  (:default-initargs :zorder 2.01)
  (:documentation "Represents a single tick mark with its label and gridline.
Ported from matplotlib.axis.Tick."))

(defmethod initialize-instance :after ((tk tick) &key)
  "Set default tick size based on major/minor."
  (unless (tick-size tk)
    (setf (tick-size tk)
          (if (tick-major-p tk) 6.0 3.0)))
  (unless (tick-width tk)
    (setf (tick-width tk)
          (if (tick-major-p tk) 0.8 0.6))))

;;; ============================================================
;;; Axis base class
;;; ============================================================

(defclass axis-obj (mpl.rendering:artist)
  ((axis-axes :initarg :axes
              :initform nil
              :accessor axis-axes
              :documentation "Parent axes.")
   (major-locator :initarg :major-locator
                  :initform nil
                  :accessor axis-major-locator
                  :documentation "Major tick locator.")
   (minor-locator :initarg :minor-locator
                  :initform nil
                  :accessor axis-minor-locator
                  :documentation "Minor tick locator.")
   (major-formatter :initarg :major-formatter
                    :initform nil
                    :accessor axis-major-formatter
                    :documentation "Major tick formatter.")
   (minor-formatter :initarg :minor-formatter
                    :initform nil
                    :accessor axis-minor-formatter
                    :documentation "Minor tick formatter.")
   (axis-label :initform nil
               :accessor axis-label-artist
               :documentation "Text artist for the axis label.")
   (axis-label-text :initform ""
                    :accessor axis-label-text
                    :documentation "The axis label string.")
   ;; Scale
   (axis-scale :initform nil
               :accessor axis-scale
               :documentation "The scale object for this axis (LinearScale, LogScale, etc.).")
   ;; Tick parameters
   (tick-size-major :initform 6.0
                    :accessor axis-tick-size-major
                    :type real)
   (tick-size-minor :initform 3.0
                    :accessor axis-tick-size-minor
                    :type real)
   (tick-direction :initform :out
                   :accessor axis-tick-direction
                   :documentation "Tick direction: :out, :in, :inout.")
   (tick-label-fontsize :initform 10.0
                        :accessor axis-tick-label-fontsize
                        :type real)
   (tick-pad :initform 3.5d0
             :accessor axis-tick-pad
             :type double-float)
    ;; Tick label visibility (for shared axes suppression)
    (tick-labels-visible :initform t
                         :accessor axis-tick-labels-visible-p
                         :type boolean
                         :documentation "Whether tick labels are drawn. Set to NIL to suppress (e.g. shared axes).")
    ;; Grid state
    (grid-on-p :initform nil
               :accessor axis-grid-on-p
               :type boolean
               :documentation "Whether grid is enabled for this axis.")
   (grid-color :initform "#b0b0b0"
               :accessor axis-grid-color)
   (grid-linewidth :initform 0.8
                   :accessor axis-grid-linewidth)
   (grid-linestyle :initform :solid
                   :accessor axis-grid-linestyle)
    (grid-alpha :initform 1.0
                :accessor axis-grid-alpha))
  (:default-initargs :zorder 1.5)
  (:documentation "Base class for axes axis objects.
Ported from matplotlib.axis.Axis."))

(defmethod initialize-instance :after ((ax axis-obj) &key)
  "Set up default locators and formatters."
  ;; Default: LinearScale
  (unless (axis-scale ax)
    (setf (axis-scale ax) (make-instance 'linear-scale :axis ax)))
  ;; Default: AutoLocator and ScalarFormatter for major
  (unless (axis-major-locator ax)
    (setf (axis-major-locator ax) (make-instance 'auto-locator)))
  (unless (axis-minor-locator ax)
    (setf (axis-minor-locator ax) (make-instance 'null-locator)))
  (unless (axis-major-formatter ax)
    (setf (axis-major-formatter ax) (make-instance 'scalar-formatter)))
  (unless (axis-minor-formatter ax)
    (setf (axis-minor-formatter ax) (make-instance 'null-formatter)))
  ;; Set axis reference on locators/formatters
  (setf (locator-axis (axis-major-locator ax)) ax)
  (setf (locator-axis (axis-minor-locator ax)) ax)
  (setf (tick-formatter-axis (axis-major-formatter ax)) ax)
  (setf (tick-formatter-axis (axis-minor-formatter ax)) ax))

;;; ============================================================
;;; Axis view interval protocol
;;; ============================================================

(defgeneric axis-get-view-interval (axis)
  (:documentation "Return (values vmin vmax) for this axis."))

(defgeneric axis-get-data-interval (axis)
  (:documentation "Return (values dmin dmax) for this axis."))

;;; ============================================================
;;; Set locators/formatters
;;; ============================================================

(defun axis-set-major-locator (axis locator)
  "Set the major tick locator."
  (setf (locator-axis locator) axis)
  (setf (axis-major-locator axis) locator)
  (setf (mpl.rendering:artist-stale axis) t))

(defun axis-set-minor-locator (axis locator)
  "Set the minor tick locator."
  (setf (locator-axis locator) axis)
  (setf (axis-minor-locator axis) locator)
  (setf (mpl.rendering:artist-stale axis) t))

(defun axis-set-major-formatter (axis fmt)
  "Set the major tick formatter."
  (setf (tick-formatter-axis fmt) axis)
  (setf (axis-major-formatter axis) fmt)
  (setf (mpl.rendering:artist-stale axis) t))

(defun axis-set-minor-formatter (axis fmt)
  "Set the minor tick formatter."
  (setf (tick-formatter-axis fmt) axis)
  (setf (axis-minor-formatter axis) fmt)
  (setf (mpl.rendering:artist-stale axis) t))

;;; ============================================================
;;; Axis label
;;; ============================================================

(defun axis-set-label-text (axis text &key (fontsize nil))
  "Set the axis label text."
  (setf (axis-label-text axis) text)
  (when fontsize
    ;; Will be used when creating the label artist
    t)
  (setf (mpl.rendering:artist-stale axis) t))

;;; ============================================================
;;; Grid control
;;; ============================================================

(defun axis-grid (axis &key (visible t) (color nil) (linewidth nil)
                            (linestyle nil) (alpha nil))
  "Enable or disable grid lines for this axis."
  (setf (axis-grid-on-p axis) visible)
  (when color (setf (axis-grid-color axis) color))
  (when linewidth (setf (axis-grid-linewidth axis) linewidth))
  (when linestyle (setf (axis-grid-linestyle axis) linestyle))
  (when alpha (setf (axis-grid-alpha axis) alpha))
  (setf (mpl.rendering:artist-stale axis) t))

;;; ============================================================
;;; Scale control
;;; ============================================================

(defun axis-set-scale (axis scale-instance)
  "Set the scale for this axis.
SCALE-INSTANCE is a scale object (LinearScale, LogScale, etc.).
The scale sets default locators and formatters."
  (setf (axis-scale axis) scale-instance)
  (setf (scale-axis scale-instance) axis)
  ;; Let the scale set default locators and formatters
  (scale-set-default-locators-and-formatters scale-instance axis)
  (setf (mpl.rendering:artist-stale axis) t))

;;; ============================================================
;;; Tick generation
;;; ============================================================

(defun axis-get-major-ticks (axis)
  "Generate tick objects for major ticks."
  (multiple-value-bind (vmin vmax) (axis-get-view-interval axis)
    (let* ((locator (axis-major-locator axis))
           (formatter (axis-major-formatter axis))
           (locs (locator-tick-values locator vmin vmax))
           ;; Filter to visible range (with small tolerance)
           (range (- vmax vmin))
           (tol (* range 0.001d0))
           (visible-locs (remove-if-not
                          (lambda (l) (and (>= l (- vmin tol))
                                           (<= l (+ vmax tol))))
                          locs))
           (labels (tick-formatter-format-ticks formatter visible-locs)))
      (loop for loc in visible-locs
            for label in labels
            collect (let ((tk (make-instance 'tick
                                            :axes (axis-axes axis)
                                            :loc (float loc 1.0d0)
                                            :major t
                                            :size (axis-tick-size-major axis)
                                            :direction (axis-tick-direction axis)
                                            :label-fontsize (axis-tick-label-fontsize axis)
                                            :grid-on (axis-grid-on-p axis)
                                            :grid-color (axis-grid-color axis)
                                            :grid-linewidth (axis-grid-linewidth axis)
                                            :grid-linestyle (axis-grid-linestyle axis)
                                            :grid-alpha (axis-grid-alpha axis))))
                     (setf (tick-label-text tk) label)
                     tk)))))

(defun axis-get-minor-ticks (axis)
  "Generate tick objects for minor ticks."
  (multiple-value-bind (vmin vmax) (axis-get-view-interval axis)
    (let* ((locator (axis-minor-locator axis))
           (locs (locator-tick-values locator vmin vmax))
           (range (- vmax vmin))
           (tol (* range 0.001d0))
           (visible-locs (remove-if-not
                          (lambda (l) (and (>= l (- vmin tol))
                                           (<= l (+ vmax tol))))
                          locs)))
      (loop for loc in visible-locs
            collect (make-instance 'tick
                                  :axes (axis-axes axis)
                                  :loc (float loc 1.0d0)
                                  :major nil
                                  :size (axis-tick-size-minor axis)
                                  :direction (axis-tick-direction axis)
                                  :label-fontsize (axis-tick-label-fontsize axis)
                                  :grid-on nil)))))

;;; ============================================================
;;; XAxis — horizontal axis
;;; ============================================================

(defclass x-axis (axis-obj)
  ()
  (:documentation "Horizontal axis for rectilinear axes.
Ported from matplotlib.axis.XAxis."))

(defmethod axis-get-view-interval ((axis x-axis))
  (let ((ax (axis-axes axis)))
    (if ax
        (axes-get-xlim ax)
        (values 0.0d0 1.0d0))))

(defmethod axis-get-data-interval ((axis x-axis))
  (let* ((ax (axis-axes axis))
         (dl (when ax (axes-base-data-lim ax))))
    (if (and dl (not (mpl.primitives:bbox-null-p dl)))
        (values (mpl.primitives:bbox-x0 dl) (mpl.primitives:bbox-x1 dl))
        (values 0.0d0 1.0d0))))

;;; XAxis grid drawing (called before data artists for correct z-ordering)

(defun draw-x-axis-grid (axis renderer)
  "Draw only the grid lines for the X axis.
Called before data artists to ensure grid appears behind data (zorder=0.5 in matplotlib)."
  (when (and (mpl.rendering:artist-visible axis)
             (axis-grid-on-p axis))
    (let* ((ax (axis-axes axis))
           (trans-axes (when ax (axes-base-trans-axes ax)))
           (trans-data (when ax (axes-base-trans-data ax))))
      (when (and ax trans-axes trans-data)
        (let* ((axes-left (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 0))
               (axes-bottom (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 1))
               (axes-right (aref (mpl.primitives:transform-point trans-axes (list 1.0d0 0.0d0)) 0))
               (axes-top (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 1.0d0)) 1))
               ;; Clip grid to axes area so line-width doesn't bleed outside
               (clip-rect (mpl.primitives:make-bbox axes-left axes-bottom axes-right axes-top))
               (major-ticks (axis-get-major-ticks axis)))
          (dolist (tk major-ticks)
            (when (tick-gridline-visible-p tk)
              (let* ((loc (tick-loc tk))
                     (data-pt (mpl.primitives:transform-point trans-data (list loc 0.0d0)))
                     (x-display (aref data-pt 0))
                     (x-display-snapped (+ (round x-display) 0.5d0))
                     (gc (mpl.rendering:make-gc
                          :foreground (tick-grid-color tk)
                          :linewidth (tick-grid-linewidth tk)
                          :alpha (tick-grid-alpha tk)
                          :linestyle (tick-grid-linestyle tk)
                          :clip-rectangle clip-rect))
                     (path (mpl.primitives:make-path
                            :vertices (make-array '(2 2) :element-type 'double-float
                                                  :initial-contents
                                                  (list (list x-display-snapped axes-bottom)
                                                        (list x-display-snapped axes-top))))))
                (mpl.rendering:renderer-draw-path renderer gc path nil :stroke t)))))))))

;;; XAxis drawing (ticks, labels — grid drawn separately)

(defmethod mpl.rendering:draw ((axis x-axis) renderer)
  "Draw the X axis: tick marks, tick labels, and axis label.
Grid lines are NOT drawn here — they are drawn earlier by draw-x-axis-grid
to ensure they appear behind data artists (matplotlib grid zorder=0.5)."
  (unless (mpl.rendering:artist-visible axis)
    (return-from mpl.rendering:draw))
  (let* ((ax (axis-axes axis))
         (trans-axes (when ax (axes-base-trans-axes ax)))
         (trans-data (when ax (axes-base-trans-data ax)))
         (labels-visible (axis-tick-labels-visible-p axis)))
    (when (and ax trans-axes trans-data)
      ;; Draw major ticks (skip-grid=t since grid was drawn in earlier pass)
      (let ((major-ticks (axis-get-major-ticks axis)))
        (dolist (tk major-ticks)
          (%draw-x-tick renderer ax tk trans-data trans-axes labels-visible t))
        ;; Draw minor ticks
        (let ((minor-ticks (axis-get-minor-ticks axis)))
          (dolist (tk minor-ticks)
            (%draw-x-tick renderer ax tk trans-data trans-axes labels-visible t))))
      ;; Draw axis label (also suppressed when tick labels are hidden)
      (when (and labels-visible
                 (axis-label-text axis)
                 (> (length (axis-label-text axis)) 0))
        (%draw-x-axis-label renderer ax axis trans-axes))))
  (setf (mpl.rendering:artist-stale axis) nil))

(defun %draw-x-tick (renderer ax tk trans-data trans-axes &optional (labels-visible t) (skip-grid nil))
  "Draw a single X axis tick mark, label, and optionally gridline.
When SKIP-GRID is T, skip drawing the gridline (it was already drawn earlier)."
  (let* ((loc (tick-loc tk))
         ;; Transform tick location to display coords
         (data-pt (mpl.primitives:transform-point trans-data (list loc 0.0d0)))
         (x-display (aref data-pt 0))                              ; original position for labels/grid
         (x-display-snapped (+ (round x-display) 0.5d0))          ; snapped for tick line and grid
         ;; Get axes bottom in display coords
         (axes-bottom (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 1))
         (axes-top (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 1.0d0)) 1))
         (tick-len (float (or (tick-size tk) 6.0) 1.0d0))
         (tick-wid (float (or (tick-width tk) 0.8) 1.0d0))
         (direction (tick-direction tk))
         ;; Compute tick mark endpoints
         (y-start (case direction
                    (:out axes-bottom)
                    (:in (+ axes-bottom tick-len))
                    (:inout (- axes-bottom (* tick-len 0.5d0)))
                    (t axes-bottom)))
         (y-end (case direction
                  (:out (- axes-bottom tick-len))
                  (:in axes-bottom)
                  (:inout (+ axes-bottom (* tick-len 0.5d0)))
                  (t (- axes-bottom tick-len)))))
    ;; Draw tick mark line
    (let ((gc (mpl.rendering:make-gc
               :foreground (tick-color tk)
               :linewidth tick-wid
               :capstyle :butt)))
      (let ((path (mpl.primitives:make-path
                   :vertices (make-array '(2 2) :element-type 'double-float
                                         :initial-contents
                                         (list (list x-display-snapped y-start)
                                               (list x-display-snapped y-end))))))
        (mpl.rendering:renderer-draw-path renderer gc path nil :stroke t)))
    ;; Draw tick label (only when labels are visible)
    (when (and labels-visible
               (tick-label-text tk)
               (> (length (tick-label-text tk)) 0))
      (let* ((label-y (- y-end (float (tick-pad tk) 1.0d0)))
              (fontsize-px (* (tick-label-fontsize tk)
                              (/ (mpl.backends:renderer-dpi renderer) 72.0)))
              (gc (mpl.rendering:make-gc
                   :foreground (tick-label-color tk)
                   :linewidth fontsize-px
                   :alpha 1.0)))
        (mpl.rendering:renderer-draw-text renderer gc
                                           x-display label-y
                                           (tick-label-text tk)
                                           :angle 0.0
                                           :ha :center
                                           :va :top)))
    ;; Draw gridline (unless already drawn in grid-only pass)
    (when (and (not skip-grid) (tick-gridline-visible-p tk))
      (let ((gc (mpl.rendering:make-gc
                 :foreground (tick-grid-color tk)
                 :linewidth (tick-grid-linewidth tk)
                 :alpha (tick-grid-alpha tk)
                 :linestyle (tick-grid-linestyle tk))))
        (let ((path (mpl.primitives:make-path
                     :vertices (make-array '(2 2) :element-type 'double-float
                                           :initial-contents
                                           (list (list x-display-snapped axes-bottom)
                                                 (list x-display-snapped axes-top))))))
          (mpl.rendering:renderer-draw-path renderer gc path nil :stroke t))))))

(defun %draw-x-axis-label (renderer ax axis trans-axes)
  "Draw the X axis label centered below the axes."
  (declare (ignore ax))
  (let* ((p-mid (mpl.primitives:transform-point trans-axes (list 0.5d0 0.0d0)))
         (x-mid (aref p-mid 0))
         (y-bottom (- (aref p-mid 1) 35.0d0))
         (fontsize-px (* 10.0 (/ (mpl.backends:renderer-dpi renderer) 72.0)))
         (gc (mpl.rendering:make-gc :foreground "black" :linewidth fontsize-px :alpha 1.0)))
    (mpl.rendering:renderer-draw-text renderer gc
                                      x-mid y-bottom
                                      (axis-label-text axis)
                                      :angle 0.0
                                      :ha :center)))

;;; ============================================================
;;; YAxis — vertical axis
;;; ============================================================

(defclass y-axis (axis-obj)
  ()
  (:documentation "Vertical axis for rectilinear axes.
Ported from matplotlib.axis.YAxis."))

(defmethod axis-get-view-interval ((axis y-axis))
  (let ((ax (axis-axes axis)))
    (if ax
        (axes-get-ylim ax)
        (values 0.0d0 1.0d0))))

(defmethod axis-get-data-interval ((axis y-axis))
  (let* ((ax (axis-axes axis))
         (dl (when ax (axes-base-data-lim ax))))
    (if (and dl (not (mpl.primitives:bbox-null-p dl)))
        (values (mpl.primitives:bbox-y0 dl) (mpl.primitives:bbox-y1 dl))
        (values 0.0d0 1.0d0))))

;;; YAxis grid drawing (called before data artists for correct z-ordering)

(defun draw-y-axis-grid (axis renderer)
  "Draw only the grid lines for the Y axis.
Called before data artists to ensure grid appears behind data (zorder=0.5 in matplotlib)."
  (when (and (mpl.rendering:artist-visible axis)
             (axis-grid-on-p axis))
    (let* ((ax (axis-axes axis))
           (trans-axes (when ax (axes-base-trans-axes ax)))
           (trans-data (when ax (axes-base-trans-data ax))))
      (when (and ax trans-axes trans-data)
        (let* ((axes-left (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 0))
               (axes-bottom (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 1))
               (axes-right (aref (mpl.primitives:transform-point trans-axes (list 1.0d0 0.0d0)) 0))
               (axes-top (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 1.0d0)) 1))
               ;; Clip grid to axes area so line-width doesn't bleed outside
               (clip-rect (mpl.primitives:make-bbox axes-left axes-bottom axes-right axes-top))
               (major-ticks (axis-get-major-ticks axis)))
          (dolist (tk major-ticks)
            (when (tick-gridline-visible-p tk)
              (let* ((loc (tick-loc tk))
                     (data-pt (mpl.primitives:transform-point trans-data (list 0.0d0 loc)))
                     (y-display (aref data-pt 1))
                     (y-display-snapped (- (round y-display) 0.5d0))
                     (gc (mpl.rendering:make-gc
                          :foreground (tick-grid-color tk)
                          :linewidth (tick-grid-linewidth tk)
                          :alpha (tick-grid-alpha tk)
                          :linestyle (tick-grid-linestyle tk)
                          :clip-rectangle clip-rect))
                     (path (mpl.primitives:make-path
                            :vertices (make-array '(2 2) :element-type 'double-float
                                                  :initial-contents
                                                  (list (list axes-left y-display-snapped)
                                                        (list axes-right y-display-snapped))))))
                (mpl.rendering:renderer-draw-path renderer gc path nil :stroke t)))))))))

;;; YAxis drawing (ticks, labels — grid drawn separately)

(defmethod mpl.rendering:draw ((axis y-axis) renderer)
  "Draw the Y axis: tick marks, tick labels, and axis label.
Grid lines are NOT drawn here — they are drawn earlier by draw-y-axis-grid
to ensure they appear behind data artists (matplotlib grid zorder=0.5)."
  (unless (mpl.rendering:artist-visible axis)
    (return-from mpl.rendering:draw))
  (let* ((ax (axis-axes axis))
         (trans-axes (when ax (axes-base-trans-axes ax)))
         (trans-data (when ax (axes-base-trans-data ax)))
         (labels-visible (axis-tick-labels-visible-p axis)))
    (when (and ax trans-axes trans-data)
      ;; Draw major ticks (skip-grid=t since grid was drawn in earlier pass)
      (let ((major-ticks (axis-get-major-ticks axis)))
        (dolist (tk major-ticks)
          (%draw-y-tick renderer ax tk trans-data trans-axes labels-visible t))
        ;; Draw minor ticks
        (let ((minor-ticks (axis-get-minor-ticks axis)))
          (dolist (tk minor-ticks)
            (%draw-y-tick renderer ax tk trans-data trans-axes labels-visible t))))
      ;; Draw axis label (also suppressed when tick labels are hidden)
      (when (and labels-visible
                 (axis-label-text axis)
                 (> (length (axis-label-text axis)) 0))
        (%draw-y-axis-label renderer ax axis trans-axes))))
  (setf (mpl.rendering:artist-stale axis) nil))

(defun %draw-y-tick (renderer ax tk trans-data trans-axes &optional (labels-visible t) (skip-grid nil))
  "Draw a single Y axis tick mark, label, and optionally gridline.
When SKIP-GRID is T, skip drawing the gridline (it was already drawn earlier)."
  (declare (ignore ax))
  (let* ((loc (tick-loc tk))
         ;; Transform tick location to display coords
         (data-pt (mpl.primitives:transform-point trans-data (list 0.0d0 loc)))
         (y-display (aref data-pt 1))                              ; original position for labels/grid
         (y-display-snapped (- (round y-display) 0.5d0))          ; snapped for tick line and grid (horizontal lines: y - 0.5)
         ;; Get axes left edge in display coords
         (axes-left (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 0))
         (axes-right (aref (mpl.primitives:transform-point trans-axes (list 1.0d0 0.0d0)) 0))
         (tick-len (float (or (tick-size tk) 6.0) 1.0d0))
         (tick-wid (float (or (tick-width tk) 0.8) 1.0d0))
         (direction (tick-direction tk))
         ;; Compute tick mark endpoints
         (x-start (case direction
                    (:out axes-left)
                    (:in (- axes-left tick-len))
                    (:inout (+ axes-left (* tick-len 0.5d0)))
                    (t axes-left)))
         (x-end (case direction
                  (:out (- axes-left tick-len))
                  (:in axes-left)
                  (:inout (- axes-left (* tick-len 0.5d0)))
                  (t (- axes-left tick-len)))))
    ;; Draw tick mark line
    (let ((gc (mpl.rendering:make-gc
               :foreground (tick-color tk)
               :linewidth tick-wid
               :capstyle :butt)))
      (let ((path (mpl.primitives:make-path
                   :vertices (make-array '(2 2) :element-type 'double-float
                                         :initial-contents
                                         (list (list x-start y-display-snapped)
                                               (list x-end y-display-snapped))))))
        (mpl.rendering:renderer-draw-path renderer gc path nil :stroke t)))
    ;; Draw tick label (only when labels are visible)
    (when (and labels-visible
               (tick-label-text tk)
               (> (length (tick-label-text tk)) 0))
      (let* ((label-x (- x-end (float (tick-pad tk) 1.0d0)))
              (fontsize-px (* (tick-label-fontsize tk)
                              (/ (mpl.backends:renderer-dpi renderer) 72.0)))
              (gc (mpl.rendering:make-gc
                   :foreground (tick-label-color tk)
                   :linewidth fontsize-px
                   :alpha 1.0)))
        (mpl.rendering:renderer-draw-text renderer gc
                                           label-x y-display
                                           (tick-label-text tk)
                                           :angle 0.0
                                           :ha :right
                                           :va :center)))
    ;; Draw gridline (unless already drawn in grid-only pass)
    (when (and (not skip-grid) (tick-gridline-visible-p tk))
      (let ((gc (mpl.rendering:make-gc
                 :foreground (tick-grid-color tk)
                 :linewidth (tick-grid-linewidth tk)
                 :alpha (tick-grid-alpha tk)
                 :linestyle (tick-grid-linestyle tk))))
        (let ((path (mpl.primitives:make-path
                     :vertices (make-array '(2 2) :element-type 'double-float
                                           :initial-contents
                                           (list (list axes-left y-display-snapped)
                                                 (list axes-right y-display-snapped))))))
          (mpl.rendering:renderer-draw-path renderer gc path nil :stroke t))))))

(defun %draw-y-axis-label (renderer ax axis trans-axes)
  "Draw the Y axis label rotated 90° to the left of axes."
  (declare (ignore ax))
  (let* ((p-mid (mpl.primitives:transform-point trans-axes (list 0.0d0 0.5d0)))
         (x-left (- (aref p-mid 0) 42.0d0))
         (y-mid (aref p-mid 1))
         (fontsize-px (* 10.0 (/ (mpl.backends:renderer-dpi renderer) 72.0)))
         (gc (mpl.rendering:make-gc :foreground "black" :linewidth fontsize-px :alpha 1.0)))
    (mpl.rendering:renderer-draw-text renderer gc
                                      x-left y-mid
                                      (axis-label-text axis)
                                      :angle 90.0
                                      :ha :center)))

;;; ============================================================
;;; Tick params helper
;;; ============================================================

(defun axis-set-tick-params (axis &key (size nil) (width nil)
                                       (direction nil) (pad nil)
                                       (labelsize nil) (which :major))
  "Set tick parameters on AXIS.
WHICH is :major, :minor, or :both."
  (when (member which '(:major :both))
    (when size (setf (axis-tick-size-major axis) size))
    (when direction (setf (axis-tick-direction axis) direction))
    (when pad (setf (axis-tick-pad axis) (float pad 1.0d0)))
    (when labelsize (setf (axis-tick-label-fontsize axis) labelsize)))
  (when (member which '(:minor :both))
    (when size (setf (axis-tick-size-minor axis) size))
    (when direction (setf (axis-tick-direction axis) direction))
    (when pad (setf (axis-tick-pad axis) (float pad 1.0d0)))
    (when labelsize (setf (axis-tick-label-fontsize axis) labelsize)))
  (when (and (null (member which '(:major :minor :both)))
             (null which))
    ;; Default: apply to major
    (when size (setf (axis-tick-size-major axis) size)))
  (ignore-errors (setf (mpl.rendering:artist-stale axis) t)))

;;; ============================================================
;;; Print representation
;;; ============================================================

(defmethod print-object ((axis x-axis) stream)
  (print-unreadable-object (axis stream :type t)
    (format stream "XAxis")))

(defmethod print-object ((axis y-axis) stream)
  (print-unreadable-object (axis stream :type t)
    (format stream "YAxis")))
