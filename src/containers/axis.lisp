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
          (if (tick-major-p tk) 3.5 2.0)))
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
    (tick-size-major :initform 3.5
                     :accessor axis-tick-size-major
                     :type real)
    (tick-size-minor :initform 2.0
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
    ;; Grid state (major)
    (grid-on-p :initform nil
               :accessor axis-grid-on-p
               :type boolean
               :documentation "Whether major grid is enabled for this axis.")
   (grid-color :initform "#b0b0b0"
               :accessor axis-grid-color)
   (grid-linewidth :initform 0.8
                   :accessor axis-grid-linewidth)
   (grid-linestyle :initform :solid
                   :accessor axis-grid-linestyle)
    (grid-alpha :initform 1.0
                :accessor axis-grid-alpha)
    ;; Grid state (minor)
    (minor-grid-on-p :initform nil
                     :accessor axis-minor-grid-on-p
                     :type boolean
                     :documentation "Whether minor grid is enabled for this axis.")
    (minor-grid-color :initform "#b0b0b0"
                      :accessor axis-minor-grid-color)
    (minor-grid-linewidth :initform 0.8
                          :accessor axis-minor-grid-linewidth)
    (minor-grid-linestyle :initform :solid
                          :accessor axis-minor-grid-linestyle)
    (minor-grid-alpha :initform 1.0
                      :accessor axis-minor-grid-alpha))
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

(defun axis-grid (axis &key (visible t) (which :major) (color nil) (linewidth nil)
                            (linestyle nil) (alpha nil))
  "Enable or disable grid lines for this axis.
WHICH: :major, :minor, or :both."
  (when (member which '(:major :both))
    (setf (axis-grid-on-p axis) visible)
    (when color (setf (axis-grid-color axis) color))
    (when linewidth (setf (axis-grid-linewidth axis) linewidth))
    (when linestyle (setf (axis-grid-linestyle axis) linestyle))
    (when alpha (setf (axis-grid-alpha axis) alpha)))
  (when (member which '(:minor :both))
    (setf (axis-minor-grid-on-p axis) visible)
    (when color (setf (axis-minor-grid-color axis) color))
    (when linewidth (setf (axis-minor-grid-linewidth axis) linewidth))
    (when linestyle (setf (axis-minor-grid-linestyle axis) linestyle))
    (when alpha (setf (axis-minor-grid-alpha axis) alpha)))
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
    ;; Apply scale-specific range limiting for log scales
    (let ((scale (axis-scale axis)))
      (when (and scale (typep scale 'log-scale))
        (multiple-value-bind (data-min data-max) (axis-get-data-interval axis)
          (let ((minpos (if (> data-min 0.0d0) data-min 1.0d-300)))
            (multiple-value-setq (vmin vmax)
              (scale-limit-range-for-scale scale vmin vmax minpos))))))
    (let* ((locator (axis-major-locator axis))
           (formatter (axis-major-formatter axis))
           (locs (locator-tick-values locator vmin vmax))
            ;; Filter to visible range (with small tolerance)
           ;; Use min/max to handle inverted axes (vmin > vmax)
           (real-min (min vmin vmax))
           (real-max (max vmin vmax))
           (range (- real-max real-min))
           (tol (* range 0.001d0))
           (visible-locs (remove-if-not
                          (lambda (l) (and (>= l (- real-min tol))
                                           (<= l (+ real-max tol))))
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
    ;; Apply scale-specific range limiting for log scales
    (let ((scale (axis-scale axis)))
      (when (and scale (typep scale 'log-scale))
        (multiple-value-bind (data-min data-max) (axis-get-data-interval axis)
          (let ((minpos (if (> data-min 0.0d0) data-min 1.0d-300)))
            (multiple-value-setq (vmin vmax)
              (scale-limit-range-for-scale scale vmin vmax minpos))))))
    (let* ((locator (axis-minor-locator axis))
            (locs (locator-tick-values locator vmin vmax))
           ;; Use min/max to handle inverted axes (vmin > vmax)
           (real-min (min vmin vmax))
           (real-max (max vmin vmax))
           (range (- real-max real-min))
           (tol (* range 0.001d0))
           (visible-locs (remove-if-not
                          (lambda (l) (and (>= l (- real-min tol))
                                           (<= l (+ real-max tol))))
                          locs)))
      (loop for loc in visible-locs
            collect (make-instance 'tick
                                  :axes (axis-axes axis)
                                  :loc (float loc 1.0d0)
                                  :major nil
                                  :size (axis-tick-size-minor axis)
                                  :direction (axis-tick-direction axis)
                                  :label-fontsize (axis-tick-label-fontsize axis)
                                  :grid-on (axis-minor-grid-on-p axis)
                                  :grid-color (axis-minor-grid-color axis)
                                  :grid-linewidth (axis-minor-grid-linewidth axis)
                                  :grid-linestyle (axis-minor-grid-linestyle axis)
                                  :grid-alpha (axis-minor-grid-alpha axis))))))

;;; ============================================================
;;; XAxis — horizontal axis
;;; ============================================================

(defclass x-axis (axis-obj)
  ((axis-side :initarg :side
              :initform :bottom
              :accessor axis-side
              :documentation "Which side to draw ticks/labels: :bottom (default) or :top."))
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
  "Draw grid lines for the X axis (both major and minor).
Called before data artists to ensure grid appears behind data."
  (when (mpl.rendering:artist-visible axis)
    (let* ((ax (axis-axes axis))
           (trans-axes (when ax (axes-base-trans-axes ax)))
           (trans-data (when ax (axes-base-trans-data ax))))
      (when (and ax trans-axes trans-data)
        (let* ((axes-left (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 0))
               (axes-bottom (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 1))
               (axes-right (aref (mpl.primitives:transform-point trans-axes (list 1.0d0 0.0d0)) 0))
               (axes-top (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 1.0d0)) 1))
               (clip-rect (mpl.primitives:make-bbox axes-left axes-bottom axes-right axes-top)))
          ;; Minor grid lines first (behind major)
          (when (axis-minor-grid-on-p axis)
            (dolist (tk (axis-get-minor-ticks axis))
              (when (tick-gridline-visible-p tk)
                (let* ((loc (tick-loc tk))
                       (data-pt (mpl.primitives:transform-point trans-data (list loc 0.0d0)))
                       (x-display (aref data-pt 0))
                       (x-display-snapped (+ (round x-display) 0.5d0)))
                  (mpl.rendering:renderer-draw-path renderer
                   (mpl.rendering:make-gc :foreground (tick-grid-color tk)
                    :linewidth (tick-grid-linewidth tk) :alpha (tick-grid-alpha tk)
                    :linestyle (tick-grid-linestyle tk) :clip-rectangle clip-rect)
                   (mpl.primitives:make-path :vertices
                    (make-array '(2 2) :element-type 'double-float :initial-contents
                     (list (list x-display-snapped axes-bottom)
                           (list x-display-snapped axes-top))))
                   nil :stroke t)))))
          ;; Major grid lines
          (when (axis-grid-on-p axis)
            (dolist (tk (axis-get-major-ticks axis))
              (when (tick-gridline-visible-p tk)
                (let* ((loc (tick-loc tk))
                       (data-pt (mpl.primitives:transform-point trans-data (list loc 0.0d0)))
                       (x-display (aref data-pt 0))
                       (x-display-snapped (+ (round x-display) 0.5d0)))
                  (mpl.rendering:renderer-draw-path renderer
                   (mpl.rendering:make-gc :foreground (tick-grid-color tk)
                    :linewidth (tick-grid-linewidth tk) :alpha (tick-grid-alpha tk)
                    :linestyle (tick-grid-linestyle tk) :clip-rectangle clip-rect)
                   (mpl.primitives:make-path :vertices
                    (make-array '(2 2) :element-type 'double-float :initial-contents
                     (list (list x-display-snapped axes-bottom)
                           (list x-display-snapped axes-top))))
                   nil :stroke t))))))))))

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
         (labels-visible (axis-tick-labels-visible-p axis))
         (side (axis-side axis)))
    (when (and ax trans-axes trans-data)
      ;; Draw major ticks (skip-grid=t since grid was drawn in earlier pass)
      (let ((major-ticks (axis-get-major-ticks axis)))
        (dolist (tk major-ticks)
          (%draw-x-tick renderer ax tk trans-data trans-axes labels-visible t side))
        ;; Draw minor ticks
        (let ((minor-ticks (axis-get-minor-ticks axis)))
          (dolist (tk minor-ticks)
            (%draw-x-tick renderer ax tk trans-data trans-axes labels-visible t side))))
      ;; Draw axis label (also suppressed when tick labels are hidden)
      (when (and labels-visible
                 (axis-label-text axis)
                 (> (length (axis-label-text axis)) 0))
        (%draw-x-axis-label renderer ax axis trans-axes side))))
  (setf (mpl.rendering:artist-stale axis) nil))

(defun %draw-x-tick (renderer ax tk trans-data trans-axes &optional (labels-visible t) (skip-grid nil) (side :bottom))
  "Draw a single X axis tick mark, label, and optionally gridline.
When SKIP-GRID is T, skip drawing the gridline (it was already drawn earlier).
SIDE is :bottom (default) or :top for twin axes."
  (let* ((loc (tick-loc tk))
         ;; Transform tick location to display coords
         (data-pt (mpl.primitives:transform-point trans-data (list loc 0.0d0)))
         (x-display (aref data-pt 0))                              ; original position for labels/grid
         (x-display-snapped (+ (round x-display) 0.5d0))          ; snapped for tick line and grid
         ;; Get axes bottom/top in display coords
         (axes-bottom (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 1))
         (axes-top (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 1.0d0)) 1))
         (dpi (mpl.backends:renderer-dpi renderer))
         (pts->px (/ dpi 72.0d0))
         (tick-len (* (float (or (tick-size tk) 3.5) 1.0d0) pts->px))
         (tick-wid (float (or (tick-width tk) 0.8) 1.0d0))
         (direction (tick-direction tk))
         ;; Compute tick mark endpoints based on side
         (top-p (eq side :top))
         (edge (if top-p axes-top axes-bottom))
         (y-start (if top-p
                      (case direction
                        (:out edge)
                        (:in (- edge tick-len))
                        (:inout (+ edge (* tick-len 0.5d0)))
                        (t edge))
                      (case direction
                        (:out edge)
                        (:in (+ edge tick-len))
                        (:inout (- edge (* tick-len 0.5d0)))
                        (t edge))))
         (y-end (if top-p
                    (case direction
                      (:out (+ edge tick-len))
                      (:in edge)
                      (:inout (+ edge (* tick-len 0.5d0)))
                      (t (+ edge tick-len)))
                    (case direction
                      (:out (- edge tick-len))
                      (:in edge)
                      (:inout (+ edge (* tick-len 0.5d0)))
                      (t (- edge tick-len))))))
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
      (let* ((label-y (if top-p
                          (+ y-end (* (float (tick-pad tk) 1.0d0) pts->px))
                          (- y-end (* (float (tick-pad tk) 1.0d0) pts->px))))
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
                                           :va (if top-p :bottom :top))))
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

(defun %draw-x-axis-label (renderer ax axis trans-axes &optional (side :bottom))
  "Draw the X axis label centered below (or above for :top) the axes.
Offset matches matplotlib: tick_size(3.5pt) + tick_pad(3.5pt) + tick_label_height + labelpad(4pt).
The tick_label_height uses the font line-height ratio (0.9754) matching matplotlib's FT2Font metrics.
SIDE is :bottom (default) or :top for twin axes."
  (declare (ignore ax))
  (let* ((top-p (eq side :top))
         (dpi (mpl.backends:renderer-dpi renderer))
         (pts->px (/ dpi 72.0d0))
         (p-mid (mpl.primitives:transform-point trans-axes
                                                 (list 0.5d0 (if top-p 1.0d0 0.0d0))))
         (x-mid (aref p-mid 0))
         ;; matplotlib xlabel offset = tick_size + tick_pad + tick_label_height + label_pad
         ;; tick_label_height = fontsize_px * 0.9754 (empirical ratio from matplotlib's FT2Font)
         (tick-fontsize-pts (float (axis-tick-label-fontsize axis) 1.0d0))
         (tick-label-height (* tick-fontsize-pts pts->px 0.9754d0))
         (tick-size-px (* (float (axis-tick-size-major axis) 1.0d0) pts->px))
         (tick-pad-px (* (float (axis-tick-pad axis) 1.0d0) pts->px))
         (label-pad-px (* 4.0d0 pts->px))
         (offset (+ tick-size-px tick-pad-px tick-label-height label-pad-px))
         (y-pos (if top-p
                    (+ (aref p-mid 1) offset)
                    (- (aref p-mid 1) offset)))
         (fontsize-px (* 10.0 pts->px))
         (gc (mpl.rendering:make-gc :foreground "black" :linewidth fontsize-px :alpha 1.0)))
    (mpl.rendering:renderer-draw-text renderer gc
                                      x-mid y-pos
                                      (axis-label-text axis)
                                      :angle 0.0
                                      :ha :center
                                      :va (if top-p :bottom :top))))

;;; ============================================================
;;; YAxis — vertical axis
;;; ============================================================

(defclass y-axis (axis-obj)
  ((axis-side :initarg :side
              :initform :left
              :accessor axis-side
              :documentation "Which side to draw ticks/labels: :left (default) or :right."))
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
  "Draw grid lines for the Y axis (both major and minor).
Called before data artists to ensure grid appears behind data."
  (when (mpl.rendering:artist-visible axis)
    (let* ((ax (axis-axes axis))
           (trans-axes (when ax (axes-base-trans-axes ax)))
           (trans-data (when ax (axes-base-trans-data ax))))
      (when (and ax trans-axes trans-data)
        (let* ((axes-left (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 0))
               (axes-bottom (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 1))
               (axes-right (aref (mpl.primitives:transform-point trans-axes (list 1.0d0 0.0d0)) 0))
               (axes-top (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 1.0d0)) 1))
               (clip-rect (mpl.primitives:make-bbox axes-left axes-bottom axes-right axes-top)))
          ;; Minor grid lines first (behind major)
          (when (axis-minor-grid-on-p axis)
            (dolist (tk (axis-get-minor-ticks axis))
              (when (tick-gridline-visible-p tk)
                (let* ((loc (tick-loc tk))
                       (data-pt (mpl.primitives:transform-point trans-data (list 0.0d0 loc)))
                       (y-display (aref data-pt 1))
                       (y-display-snapped (- (round y-display) 0.5d0)))
                  (mpl.rendering:renderer-draw-path renderer
                   (mpl.rendering:make-gc :foreground (tick-grid-color tk)
                    :linewidth (tick-grid-linewidth tk) :alpha (tick-grid-alpha tk)
                    :linestyle (tick-grid-linestyle tk) :clip-rectangle clip-rect)
                   (mpl.primitives:make-path :vertices
                    (make-array '(2 2) :element-type 'double-float :initial-contents
                     (list (list axes-left y-display-snapped)
                           (list axes-right y-display-snapped))))
                   nil :stroke t)))))
          ;; Major grid lines
          (when (axis-grid-on-p axis)
            (dolist (tk (axis-get-major-ticks axis))
              (when (tick-gridline-visible-p tk)
                (let* ((loc (tick-loc tk))
                       (data-pt (mpl.primitives:transform-point trans-data (list 0.0d0 loc)))
                       (y-display (aref data-pt 1))
                       (y-display-snapped (- (round y-display) 0.5d0)))
                  (mpl.rendering:renderer-draw-path renderer
                   (mpl.rendering:make-gc :foreground (tick-grid-color tk)
                    :linewidth (tick-grid-linewidth tk) :alpha (tick-grid-alpha tk)
                    :linestyle (tick-grid-linestyle tk) :clip-rectangle clip-rect)
                   (mpl.primitives:make-path :vertices
                    (make-array '(2 2) :element-type 'double-float :initial-contents
                     (list (list axes-left y-display-snapped)
                           (list axes-right y-display-snapped))))
                   nil :stroke t))))))))))


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
         (labels-visible (axis-tick-labels-visible-p axis))
         (side (axis-side axis)))
    (when (and ax trans-axes trans-data)
      ;; Draw major ticks (skip-grid=t since grid was drawn in earlier pass)
      (let ((major-ticks (axis-get-major-ticks axis)))
        (dolist (tk major-ticks)
          (%draw-y-tick renderer ax tk trans-data trans-axes labels-visible t side))
        ;; Draw minor ticks
        (let ((minor-ticks (axis-get-minor-ticks axis)))
          (dolist (tk minor-ticks)
            (%draw-y-tick renderer ax tk trans-data trans-axes labels-visible t side))))
      ;; Draw axis label (also suppressed when tick labels are hidden)
      (when (and labels-visible
                 (axis-label-text axis)
                 (> (length (axis-label-text axis)) 0))
        (%draw-y-axis-label renderer ax axis trans-axes side))))
  (setf (mpl.rendering:artist-stale axis) nil))

(defun %draw-y-tick (renderer ax tk trans-data trans-axes &optional (labels-visible t) (skip-grid nil) (side :left))
  "Draw a single Y axis tick mark, label, and optionally gridline.
When SKIP-GRID is T, skip drawing the gridline (it was already drawn earlier).
SIDE is :left (default) or :right for twin axes."
  (declare (ignore ax))
  (let* ((loc (tick-loc tk))
         ;; Transform tick location to display coords
         (data-pt (mpl.primitives:transform-point trans-data (list 0.0d0 loc)))
         (y-display (aref data-pt 1))                              ; original position for labels/grid
         (y-display-snapped (- (round y-display) 0.5d0))          ; snapped for tick line and grid
         ;; Get axes left/right edge in display coords
         (axes-left (aref (mpl.primitives:transform-point trans-axes (list 0.0d0 0.0d0)) 0))
         (axes-right (aref (mpl.primitives:transform-point trans-axes (list 1.0d0 0.0d0)) 0))
         (dpi (mpl.backends:renderer-dpi renderer))
         (pts->px (/ dpi 72.0d0))
         (tick-len (* (float (or (tick-size tk) 3.5) 1.0d0) pts->px))
         (tick-wid (float (or (tick-width tk) 0.8) 1.0d0))
         (direction (tick-direction tk))
         ;; Compute tick mark endpoints based on side
         (right-p (eq side :right))
         (edge (if right-p axes-right axes-left))
         (x-start (if right-p
                      (case direction
                        (:out edge)
                        (:in (+ edge tick-len))
                        (:inout (- edge (* tick-len 0.5d0)))
                        (t edge))
                      (case direction
                        (:out edge)
                        (:in (- edge tick-len))
                        (:inout (+ edge (* tick-len 0.5d0)))
                        (t edge))))
         (x-end (if right-p
                    (case direction
                      (:out (+ edge tick-len))
                      (:in edge)
                      (:inout (+ edge (* tick-len 0.5d0)))
                      (t (+ edge tick-len)))
                    (case direction
                      (:out (- edge tick-len))
                      (:in edge)
                      (:inout (- edge (* tick-len 0.5d0)))
                      (t (- edge tick-len))))))
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
      (let* ((label-x (if right-p
                          (+ x-end (* (float (tick-pad tk) 1.0d0) pts->px))
                          (- x-end (* (float (tick-pad tk) 1.0d0) pts->px))))
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
                                           :ha (if right-p :left :right)
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

(defun %draw-y-axis-label (renderer ax axis trans-axes &optional (side :left))
  "Draw the Y axis label rotated 90° to the left (or 270° to the right) of axes.
Dynamically computes offset based on actual tick label widths.
SIDE is :left (default) or :right for twin axes."
  (declare (ignore ax))
  (let* ((right-p (eq side :right))
         (dpi (mpl.backends:renderer-dpi renderer))
         (pts->px (/ dpi 72.0d0))
         (p-mid (mpl.primitives:transform-point trans-axes
                                                 (list (if right-p 1.0d0 0.0d0) 0.5d0)))
         (y-mid (aref p-mid 1))
         (axes-edge (aref p-mid 0))
         ;; Tick geometry in pixels
         (tick-size-px (* (float (axis-tick-size-major axis) 1.0d0) pts->px))
         (tick-pad-px (* (float (axis-tick-pad axis) 1.0d0) pts->px))
         (label-pad-px (* 4.0d0 pts->px))  ; labelpad = 4pt (matplotlib default)
         ;; Measure max tick label width using font metrics
         ;; Account for matplotlib using Unicode minus (U+2212) which is wider than ASCII hyphen
         (tick-fontsize-px (* (float (axis-tick-label-fontsize axis) 1.0d0) pts->px))
         (font-loader (zpb-ttf:open-font-loader mpl.backends::*default-font-path*))
         (font-scale-tick (/ tick-fontsize-px (float (zpb-ttf:units/em font-loader) 1.0d0)))
         (minus-width-diff (* font-scale-tick
                              (- (zpb-ttf:advance-width
                                  (zpb-ttf:find-glyph (code-char #x2212) font-loader))
                                 (zpb-ttf:advance-width
                                  (zpb-ttf:find-glyph #\- font-loader)))))
         (major-ticks (axis-get-major-ticks axis))
         (max-label-width
           (loop for tk in major-ticks
                 for text = (tick-label-text tk)
                 when (and text (> (length text) 0))
                   maximize (let* ((bb (vecto:string-bounding-box text tick-fontsize-px font-loader))
                                   (width (- (aref bb 2) (aref bb 0)))
                                   ;; Add Unicode minus correction for negative labels
                                   (correction (if (and (> (length text) 0)
                                                        (char= (char text 0) #\-))
                                                   minus-width-diff
                                                   0.0d0)))
                              (+ width correction))
                 into max-w
                 finally (return (or max-w 0.0d0))))
         ;; Ylabel font height (rotated 90°, so height becomes x-extent)
         (ylabel-fontsize-px (* 10.0d0 pts->px))
         (font-scale (/ ylabel-fontsize-px (float (zpb-ttf:units/em font-loader) 1.0d0)))
         (ylabel-half-height (* 0.5d0 (+ (* (zpb-ttf:ascender font-loader) font-scale)
                                          (abs (* (zpb-ttf:descender font-loader) font-scale)))))
         ;; Total offset from axes edge to ylabel center
         (offset (+ tick-size-px tick-pad-px max-label-width label-pad-px ylabel-half-height))
         (x-pos (if right-p (+ axes-edge offset) (- axes-edge offset)))
         (fontsize-px ylabel-fontsize-px)
         (gc (mpl.rendering:make-gc :foreground "black" :linewidth fontsize-px :alpha 1.0)))
    (zpb-ttf:close-font-loader font-loader)
    (mpl.rendering:renderer-draw-text renderer gc
                                      x-pos y-mid
                                      (axis-label-text axis)
                                      :angle (if right-p 270.0 90.0)
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
