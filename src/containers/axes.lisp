;;;; axes.lisp — Axes class with plot, scatter, bar, fill, fill_between
;;;; Ported from matplotlib's axes/_axes.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Axes — the main plotting class (rectilinear projection)
;;; ============================================================

(defclass mpl-axes (axes-base)
  ()
  (:documentation "Standard rectilinear Axes with plotting methods.
Ported from matplotlib.axes.Axes. Contains plot(), scatter(), bar(),
fill(), fill_between() methods."))

;;; ============================================================
;;; plot — plot y versus x as lines
;;; ============================================================

(defun plot (ax xdata ydata &key (color nil) (linewidth 1.5) (linestyle :solid)
                                 (marker :none) (label "") (zorder 2))
  "Plot y versus x as lines and/or markers.

AX — an axes-base (or mpl-axes) instance.
XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
COLOR — line color (string or nil for default blue).
LINEWIDTH — line width in points (default 1.5).
LINESTYLE — :solid, :dashed, :dashdot, :dotted (default :solid).
MARKER — marker style keyword (default :none).
LABEL — string label for legend.
ZORDER — drawing order (default 2).

Returns a list containing the created Line2D."
  (let* ((effective-color (or color "C0"))
         (line (make-instance 'mpl.rendering:line-2d
                              :xdata xdata
                              :ydata ydata
                              :color effective-color
                              :linewidth linewidth
                              :linestyle linestyle
                              :marker marker
                              :label label
                              :zorder zorder)))
    ;; Set the transform on the line to transData
    (setf (mpl.rendering:artist-transform line)
          (axes-base-trans-data ax))
    ;; Add to axes
    (axes-add-line ax line)
    ;; Update data limits
    (axes-update-datalim ax xdata ydata)
    ;; Autoscale
    (axes-autoscale-view ax)
    ;; Return list of lines (matching matplotlib API)
    (list line)))

;;; ============================================================
;;; scatter — scatter plot of y vs x with varying marker size/color
;;; ============================================================

(defun scatter (ax xdata ydata &key (s 36.0) (c nil) (marker :circle)
                                    (color nil) (label "") (zorder 1)
                                    (alpha nil))
  "Make a scatter plot of y vs x with optional varying marker size and color.

AX — an axes-base instance.
XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
S — marker size in points^2 (default 36.0, i.e., 6pt markers).
C — color specification (string, or nil for default).
MARKER — marker style (default :circle).
COLOR — alias for C.
LABEL — string label for legend.
ZORDER — drawing order (default 1).
ALPHA — transparency (nil for opaque).

Returns the PathCollection artist."
  (let* ((effective-color (or c color "C0"))
         (n (min (length xdata) (length ydata)))
         ;; Build offsets from data coordinates
         (offsets (loop for i from 0 below n
                        collect (list (float (elt xdata i) 1.0d0)
                                      (float (elt ydata i) 1.0d0))))
         ;; Create marker path — a unit circle for :circle marker
         (marker-path (mpl.rendering:make-marker-path
                       (if (eq marker :circle) :o marker)))
         ;; Build sizes list (uniform for now)
         (sizes (if (numberp s)
                    (make-list n :initial-element (float s 1.0d0))
                    (loop for i from 0 below n
                          collect (float (elt s i) 1.0d0))))
         ;; Create PathCollection
         (pc (mpl.rendering:make-path-collection
              :paths (list marker-path)
              :offsets offsets
              :sizes sizes
              :facecolors effective-color
              :edgecolors effective-color
              :linewidths 0.5
              :alpha alpha
              :trans-offset (axes-base-trans-data ax)
              :zorder zorder
              :label label)))
    ;; Add the collection as an artist to the axes
    (axes-add-artist ax pc)
    ;; Update data limits
    (axes-update-datalim ax xdata ydata)
    ;; Autoscale
    (axes-autoscale-view ax)
    pc))

;;; ============================================================
;;; bar — bar chart
;;; ============================================================

(defun bar (ax x height &key (width 0.8) (bottom 0) (color nil)
                              (edgecolor "black") (linewidth 0.5)
                              (label "") (zorder 1) (align :center))
  "Make a bar plot.

AX — an axes-base instance.
X — sequence of x positions for bars.
HEIGHT — sequence of bar heights.
WIDTH — bar width (number or sequence, default 0.8).
BOTTOM — bar bottom (number or sequence, default 0).
COLOR — face color (default nil = C0).
EDGECOLOR — edge color (default black).
LINEWIDTH — edge line width (default 0.5).
LABEL — string label for legend.
ZORDER — drawing order (default 1).
ALIGN — :center or :edge (default :center).

Returns a list of Rectangle patches."
  (let* ((base-color (or color "C0"))
         (n (min (length x) (length height)))
         (rects nil))
    (dotimes (i n)
      (let* ((xi (float (elt x i) 1.0d0))
             (hi (float (elt height i) 1.0d0))
             (wi (if (numberp width)
                     (float width 1.0d0)
                     (float (elt width i) 1.0d0)))
             (bi (if (numberp bottom)
                     (float bottom 1.0d0)
                     (float (elt bottom i) 1.0d0)))
             ;; Adjust x based on alignment
             (x0 (if (eq align :center)
                     (- xi (* wi 0.5d0))
                     xi))
             ;; Per-bar color: if color is a list, index into it
             (effective-color (if (and (listp base-color) (not (null base-color)))
                                  (elt base-color (mod i (length base-color)))
                                  base-color))
             (rect (make-instance 'mpl.rendering:rectangle
                                  :x0 x0
                                  :y0 bi
                                  :width wi
                                  :height hi
                                  :facecolor effective-color
                                  :edgecolor edgecolor
                                  :linewidth linewidth
                                  :zorder zorder)))
        ;; Set transform to transData
        (setf (mpl.rendering:artist-transform rect)
              (axes-base-trans-data ax))
        (axes-add-patch ax rect)
        (push rect rects)))
    ;; Compute data limits from bar extents
    (let ((all-x nil) (all-y nil))
      (dotimes (i n)
        (let* ((xi (float (elt x i) 1.0d0))
               (hi (float (elt height i) 1.0d0))
               (wi (if (numberp width)
                       (float width 1.0d0)
                       (float (elt width i) 1.0d0)))
               (bi (if (numberp bottom)
                       (float bottom 1.0d0)
                       (float (elt bottom i) 1.0d0)))
               (x0 (if (eq align :center)
                       (- xi (* wi 0.5d0))
                       xi)))
          (push x0 all-x)
          (push (+ x0 wi) all-x)
          (push bi all-y)
          (push (+ bi hi) all-y)))
      (axes-update-datalim ax (nreverse all-x) (nreverse all-y)))
    ;; Autoscale
    (axes-autoscale-view ax)
    (nreverse rects)))

;;; ============================================================
;;; fill — filled polygon
;;; ============================================================

(defun axes-fill (ax xdata ydata &key (color nil) (alpha nil) (label "")
                                      (zorder 1))
  "Fill the area defined by vertices (xdata, ydata).

AX — an axes-base instance.
XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
COLOR — fill color (default C0).
ALPHA — transparency.
LABEL — string label for legend.
ZORDER — drawing order (default 1).

Returns the created Polygon."
  (let* ((effective-color (or color "C0"))
         (n (min (length xdata) (length ydata)))
         (verts (make-array (list n 2) :element-type 'double-float)))
    ;; Build vertex array
    (dotimes (i n)
      (setf (aref verts i 0) (float (elt xdata i) 1.0d0)
            (aref verts i 1) (float (elt ydata i) 1.0d0)))
    (let ((poly (make-instance 'mpl.rendering:polygon
                               :xy verts
                               :closed t
                               :facecolor effective-color
                               :edgecolor effective-color
                               :linewidth 1.0
                               :label label
                               :zorder zorder)))
      (when alpha
        (setf (mpl.rendering:artist-alpha poly)
              (float alpha 1.0d0)))
      ;; Set transform to transData
      (setf (mpl.rendering:artist-transform poly)
            (axes-base-trans-data ax))
      (axes-add-patch ax poly)
      ;; Update data limits
      (axes-update-datalim ax xdata ydata)
      (axes-autoscale-view ax)
      poly)))

;;; ============================================================
;;; fill-between — fill area between two curves
;;; ============================================================

(defun fill-between (ax xdata y1data y2data &key (color nil) (alpha nil)
                                                  (label "") (zorder 1))
  "Fill the area between two horizontal curves.

AX — an axes-base instance.
XDATA — sequence of x coordinates.
Y1DATA — sequence of y1 coordinates (lower curve).
Y2DATA — sequence of y2 coordinates (upper curve).
COLOR — fill color (default C0).
ALPHA — transparency.
LABEL — string label for legend.
ZORDER — drawing order (default 1).

Returns the created Polygon."
  (let* ((effective-color (or color "C0"))
         (n (min (length xdata) (length y1data) (length y2data)))
         ;; Build polygon: forward along y2, then backward along y1
         (total-verts (* 2 n))
         (verts (make-array (list total-verts 2) :element-type 'double-float)))
    ;; Forward pass: y2 curve (x[0]→x[n-1])
    (dotimes (i n)
      (setf (aref verts i 0) (float (elt xdata i) 1.0d0)
            (aref verts i 1) (float (elt y2data i) 1.0d0)))
    ;; Backward pass: y1 curve (x[n-1]→x[0])
    (dotimes (i n)
      (let ((j (- n 1 i)))
        (setf (aref verts (+ n i) 0) (float (elt xdata j) 1.0d0)
              (aref verts (+ n i) 1) (float (elt y1data j) 1.0d0))))
    (let ((poly (make-instance 'mpl.rendering:polygon
                               :xy verts
                               :closed t
                               :facecolor effective-color
                               :edgecolor "none"
                               :linewidth 0.0
                               :label label
                               :zorder zorder)))
      (when alpha
        (setf (mpl.rendering:artist-alpha poly)
              (float alpha 1.0d0)))
      ;; Set transform to transData
      (setf (mpl.rendering:artist-transform poly)
            (axes-base-trans-data ax))
      (axes-add-patch ax poly)
      ;; Update data limits from both curves
      (let ((all-y (append (coerce y1data 'list)
                           (coerce y2data 'list))))
        (axes-update-datalim ax xdata all-y))
      (axes-autoscale-view ax)
      poly)))

;;; ============================================================
;;; grid — enable/disable grid lines
;;; ============================================================

(defun axes-grid-toggle (ax &key (visible t) (which :major) (axis :both)
                                  (color nil) (linewidth nil) (linestyle nil)
                                  (alpha nil))
  "Toggle grid lines on the axes.
WHICH: :major, :minor, or :both.
AXIS: :both, :x, or :y."
  (declare (ignore which))
  (when (member axis '(:both :x))
    (when (axes-base-xaxis ax)
      (axis-grid (axes-base-xaxis ax) :visible visible
                 :color color :linewidth linewidth
                 :linestyle linestyle :alpha alpha)))
  (when (member axis '(:both :y))
    (when (axes-base-yaxis ax)
      (axis-grid (axes-base-yaxis ax) :visible visible
                 :color color :linewidth linewidth
                 :linestyle linestyle :alpha alpha)))
  (setf (mpl.rendering:artist-stale ax) t))

;;; ============================================================
;;; pie — pie chart
;;; ============================================================

(defun pie (ax x &key (labels nil) (colors nil) (autopct nil)
                      (startangle 0) (counterclock t)
                      (wedgeprops nil) (textprops nil)
                      (zorder 1))
  "Draw a pie chart.

AX — an axes-base instance.
X — sequence of wedge sizes (need not sum to 1; will be normalized).
LABELS — list of label strings for each wedge.
COLORS — list of color strings for each wedge.
AUTOPCT — format string for percentage labels (e.g. \"~,1F%\") or nil.
STARTANGLE — angle in degrees for first wedge (default 0).
COUNTERCLOCK — if T, wedges go counter-clockwise (default T).
WEDGEPROPS — plist of extra wedge properties (ignored in simplified version).
TEXTPROPS — plist of extra text properties (ignored in simplified version).
ZORDER — drawing order (default 1).

Returns (values patches texts autotexts)."
  (declare (ignore wedgeprops textprops))
  (let* ((data (mapcar (lambda (v) (float v 1.0d0)) (coerce x 'list)))
         (total (reduce #'+ data))
         (fractions (if (zerop total)
                        (make-list (length data) :initial-element 0.0d0)
                        (mapcar (lambda (v) (/ v total)) data)))
         (default-colors '("C0" "C1" "C2" "C3" "C4" "C5" "C6" "C7" "C8" "C9"))
         (patches nil)
         (texts nil)
         (autotexts nil)
         (angle (float startangle 1.0d0)))
    (loop for i from 0
          for frac in fractions
          for sweep = (* frac 360.0d0)
          for theta1 = angle
          for theta2 = (if counterclock (+ angle sweep) (- angle sweep))
          for color = (if colors
                          (elt colors (mod i (length colors)))
                          (elt default-colors (mod i (length default-colors))))
          do
             ;; Create wedge patch
             (let ((wedge-patch (make-instance 'mpl.rendering:wedge
                                               :center '(0.0d0 0.0d0)
                                               :r 1.0d0
                                               :theta1 (min theta1 theta2)
                                               :theta2 (max theta1 theta2)
                                               :facecolor color
                                               :edgecolor "white"
                                               :linewidth 1.0
                                               :zorder zorder)))
               (setf (mpl.rendering:artist-transform wedge-patch)
                     (axes-base-trans-data ax))
               (axes-add-patch ax wedge-patch)
               (push wedge-patch patches))
             ;; Label text
             (when (and labels (< i (length labels)))
               (let* ((mid-angle (* (/ (+ theta1 theta2) 2.0d0) (/ pi 180.0d0)))
                      (label-r 1.1d0)
                      (lx (* label-r (cos mid-angle)))
                      (ly (* label-r (sin mid-angle)))
                      (txt (make-instance 'mpl.rendering:text-artist
                                          :x lx :y ly
                                          :text (elt labels i)
                                          :fontsize 10.0
                                          :horizontalalignment :center
                                          :verticalalignment :center
                                          :zorder (1+ zorder))))
                 (setf (mpl.rendering:artist-transform txt)
                       (axes-base-trans-data ax))
                 (push txt (axes-base-texts ax))
                 (push txt texts)))
             ;; Auto-percentage text
             (when autopct
               (let* ((pct (* frac 100.0d0))
                      (mid-angle (* (/ (+ theta1 theta2) 2.0d0) (/ pi 180.0d0)))
                      (pct-r 0.6d0)
                      (px (* pct-r (cos mid-angle)))
                      (py (* pct-r (sin mid-angle)))
                      (pct-text (format nil autopct pct))
                      (txt (make-instance 'mpl.rendering:text-artist
                                          :x px :y py
                                          :text pct-text
                                          :fontsize 8.0
                                          :horizontalalignment :center
                                          :verticalalignment :center
                                          :zorder (1+ zorder))))
                 (setf (mpl.rendering:artist-transform txt)
                       (axes-base-trans-data ax))
                 (push txt (axes-base-texts ax))
                 (push txt autotexts)))
             ;; Advance angle
             (setf angle theta2))
    ;; Set equal aspect and limits for pie — match matplotlib behavior:
    ;; 1. Explicit symmetric view limits for centering (no autoscale margin)
    (axes-set-xlim ax :min -1.3d0 :max 1.3d0)
    (axes-set-ylim ax :min -1.3d0 :max 1.3d0)
    ;; 2. Hide ticks and tick labels (pie charts have no axes)
    (axis-set-major-locator (axes-base-xaxis ax) (make-instance 'null-locator))
    (axis-set-major-locator (axes-base-yaxis ax) (make-instance 'null-locator))
    (axis-set-major-formatter (axes-base-xaxis ax) (make-instance 'null-formatter))
    (axis-set-major-formatter (axes-base-yaxis ax) (make-instance 'null-formatter))
    ;; 3. Hide frame and spines (like matplotlib's set_frame_on(False))
    (setf (axes-base-frameon-p ax) nil)
    (when (axes-base-spines ax)
      (dolist (sp (spines-all (axes-base-spines ax)))
        (spine-set-visible sp nil)))
    (values (nreverse patches) (nreverse texts) (nreverse autotexts))))

;;; ============================================================
;;; errorbar — line plot with error bars
;;; ============================================================

(defun errorbar (ax xdata ydata &key (yerr nil) (xerr nil) (fmt nil)
                                     (ecolor nil) (elinewidth 1.0)
                                     (capsize 3.0) (color nil)
                                     (linewidth 1.5) (marker :none)
                                     (label "") (zorder 2))
  "Plot y versus x with error bars.

AX — an axes-base instance.
XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
YERR — vertical error (number for symmetric, or list of numbers).
XERR — horizontal error (number for symmetric, or list of numbers).
FMT — format string (ignored, use COLOR/MARKER instead).
ECOLOR — error bar color (default same as line color).
ELINEWIDTH — error bar line width.
CAPSIZE — cap size in points (default 3.0).
COLOR — line/marker color.
LINEWIDTH — main line width.
MARKER — marker style.
LABEL — legend label.
ZORDER — drawing order.

Returns (values line error-lines caps)."
  (declare (ignore fmt))
  (let* ((effective-color (or color "C0"))
         (err-color (or ecolor effective-color))
         (n (min (length xdata) (length ydata)))
         (error-segments nil)
         (cap-segments nil))
    ;; Plot main line
    (let ((line (first (plot ax xdata ydata
                             :color effective-color
                             :linewidth linewidth
                             :marker marker
                             :label label
                             :zorder zorder))))
      ;; Create error bar segments
      (dotimes (i n)
        (let ((xi (float (elt xdata i) 1.0d0))
              (yi (float (elt ydata i) 1.0d0)))
          ;; Vertical error bars
          (when yerr
            (let* ((ye (if (numberp yerr)
                           (float yerr 1.0d0)
                           (float (elt yerr i) 1.0d0)))
                   (y-lo (- yi ye))
                   (y-hi (+ yi ye)))
              ;; Vertical line
              (push (list (list xi y-lo) (list xi y-hi)) error-segments)
              ;; Caps
              (when (plusp capsize)
                (let ((cap-hw (* capsize 0.01d0))) ; convert points to data approx
                  (push (list (list (- xi cap-hw) y-lo) (list (+ xi cap-hw) y-lo)) cap-segments)
                  (push (list (list (- xi cap-hw) y-hi) (list (+ xi cap-hw) y-hi)) cap-segments)))))
          ;; Horizontal error bars
          (when xerr
            (let* ((xe (if (numberp xerr)
                           (float xerr 1.0d0)
                           (float (elt xerr i) 1.0d0)))
                   (x-lo (- xi xe))
                   (x-hi (+ xi xe)))
              ;; Horizontal line
              (push (list (list x-lo yi) (list x-hi yi)) error-segments)
              ;; Caps
              (when (plusp capsize)
                (let ((cap-hw (* capsize 0.01d0)))
                  (push (list (list x-lo (- yi cap-hw)) (list x-lo (+ yi cap-hw))) cap-segments)
                  (push (list (list x-hi (- yi cap-hw)) (list x-hi (+ yi cap-hw))) cap-segments)))))))
      ;; Create LineCollection for error bars
      (let ((err-lc (mpl.rendering:make-line-collection
                     :segments (nreverse error-segments)
                     :edgecolors err-color
                     :linewidths elinewidth
                     :zorder (1- zorder))))
        (setf (mpl.rendering:artist-transform err-lc)
              (axes-base-trans-data ax))
        (axes-add-artist ax err-lc)
        ;; Create LineCollection for caps
        (let ((cap-lc (when cap-segments
                        (mpl.rendering:make-line-collection
                         :segments (nreverse cap-segments)
                         :edgecolors err-color
                         :linewidths elinewidth
                         :zorder (1- zorder)))))
          (when cap-lc
            (setf (mpl.rendering:artist-transform cap-lc)
                  (axes-base-trans-data ax))
            (axes-add-artist ax cap-lc))
          ;; Update data limits with error extents
          (when yerr
            (let ((all-y nil))
              (dotimes (i n)
                (let* ((yi (float (elt ydata i) 1.0d0))
                       (ye (if (numberp yerr) (float yerr 1.0d0) (float (elt yerr i) 1.0d0))))
                  (push (- yi ye) all-y)
                  (push (+ yi ye) all-y)))
              (axes-update-datalim ax xdata (nreverse all-y))))
          (when xerr
            (let ((all-x nil))
              (dotimes (i n)
                (let* ((xi (float (elt xdata i) 1.0d0))
                       (xe (if (numberp xerr) (float xerr 1.0d0) (float (elt xerr i) 1.0d0))))
                  (push (- xi xe) all-x)
                  (push (+ xi xe) all-x)))
              (axes-update-datalim ax (nreverse all-x) ydata)))
          (axes-autoscale-view ax)
          (values line err-lc cap-lc))))))

;;; ============================================================
;;; stem — stem plot
;;; ============================================================

(defun stem (ax xdata ydata &key (linefmt nil) (markerfmt nil) (basefmt nil)
                                  (bottom 0.0) (label "") (zorder 2))
  "Create a stem plot.

AX — an axes-base instance.
XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
LINEFMT — stem line color (default C0).
MARKERFMT — marker color (default C0).
BASEFMT — baseline color (default C3).
BOTTOM — baseline y position (default 0).
LABEL — legend label.
ZORDER — drawing order.

Returns (values markerline stemlines baseline)."
  (let* ((stem-color (or linefmt "C0"))
         (marker-color (or markerfmt "C0"))
         (base-color (or basefmt "C3"))
         (bot (float bottom 1.0d0))
         (n (min (length xdata) (length ydata)))
         (stem-segments nil))
    ;; Create stem line segments (vertical lines from bottom to y)
    (dotimes (i n)
      (let ((xi (float (elt xdata i) 1.0d0))
            (yi (float (elt ydata i) 1.0d0)))
        (push (list (list xi bot) (list xi yi)) stem-segments)))
    ;; Stem lines as LineCollection
    (let ((stemlines (mpl.rendering:make-line-collection
                      :segments (nreverse stem-segments)
                      :edgecolors stem-color
                      :linewidths 1.0
                      :zorder zorder)))
      (setf (mpl.rendering:artist-transform stemlines)
            (axes-base-trans-data ax))
      (axes-add-artist ax stemlines)
      ;; Marker line (scatter at heads)
      (let ((markerline (make-instance 'mpl.rendering:line-2d
                                       :xdata xdata
                                       :ydata ydata
                                       :color marker-color
                                       :linewidth 0
                                       :linestyle :solid
                                       :marker :circle
                                       :label label
                                       :zorder (1+ zorder))))
        (setf (mpl.rendering:artist-transform markerline)
              (axes-base-trans-data ax))
        (axes-add-line ax markerline)
        ;; Baseline
        (let* ((x-min (reduce #'min (coerce xdata 'list)))
               (x-max (reduce #'max (coerce xdata 'list)))
               (baseline (make-instance 'mpl.rendering:line-2d
                                        :xdata (list (float x-min 1.0d0) (float x-max 1.0d0))
                                        :ydata (list bot bot)
                                        :color base-color
                                        :linewidth 1.0
                                        :linestyle :solid
                                        :zorder zorder)))
          (setf (mpl.rendering:artist-transform baseline)
                (axes-base-trans-data ax))
          (axes-add-line ax baseline)
          ;; Update data limits
          (axes-update-datalim ax xdata ydata)
          (axes-update-datalim ax xdata (list bot))
          (axes-autoscale-view ax)
          (values markerline stemlines baseline))))))

;;; ============================================================
;;; step — step plot
;;; ============================================================

(defun axes-step (ax xdata ydata &key (where :pre) (color nil) (linewidth 1.5)
                                       (linestyle :solid) (label "") (zorder 2))
  "Create a step plot.

AX — an axes-base instance.
XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
WHERE — :pre (step before), :post (step after), :mid (step at midpoint).
COLOR — line color.
LINEWIDTH — line width.
LINESTYLE — line style.
LABEL — legend label.
ZORDER — drawing order.

Returns the created Line2D."
  (let* ((effective-color (or color "C0"))
         (n (min (length xdata) (length ydata)))
         (step-x nil)
         (step-y nil))
    ;; Build step path based on where
    (ecase where
      (:pre
       ;; Step happens before the next y value
       ;; For each segment: first go horizontal at old y, then vertical to new y
       (when (plusp n)
         (push (float (elt xdata 0) 1.0d0) step-x)
         (push (float (elt ydata 0) 1.0d0) step-y)
         (loop for i from 1 below n
               for xi = (float (elt xdata i) 1.0d0)
               for yi = (float (elt ydata i) 1.0d0)
               do ;; Horizontal at previous y to current x
                  (push xi step-x)
                  (push (float (elt ydata (1- i)) 1.0d0) step-y)
                  ;; Vertical to current y
                  (push xi step-x)
                  (push yi step-y))))
      (:post
       ;; Step happens after the current y value
       (when (plusp n)
         (loop for i from 0 below (1- n)
               for xi = (float (elt xdata i) 1.0d0)
               for yi = (float (elt ydata i) 1.0d0)
               for xi+1 = (float (elt xdata (1+ i)) 1.0d0)
               do ;; Current point
                  (push xi step-x)
                  (push yi step-y)
                  ;; Horizontal at current y to next x
                  (push xi+1 step-x)
                  (push yi step-y))
         ;; Last point
         (push (float (elt xdata (1- n)) 1.0d0) step-x)
         (push (float (elt ydata (1- n)) 1.0d0) step-y)))
      (:mid
       ;; Step happens at midpoint between x values
       (when (plusp n)
         (push (float (elt xdata 0) 1.0d0) step-x)
         (push (float (elt ydata 0) 1.0d0) step-y)
         (loop for i from 1 below n
               for xi-prev = (float (elt xdata (1- i)) 1.0d0)
               for xi = (float (elt xdata i) 1.0d0)
               for yi-prev = (float (elt ydata (1- i)) 1.0d0)
               for yi = (float (elt ydata i) 1.0d0)
               for mid-x = (* 0.5d0 (+ xi-prev xi))
               do ;; Horizontal to midpoint at previous y
                  (push mid-x step-x)
                  (push yi-prev step-y)
                  ;; Vertical to current y at midpoint
                  (push mid-x step-x)
                  (push yi step-y))
         ;; Last segment to end
         (push (float (elt xdata (1- n)) 1.0d0) step-x)
         (push (float (elt ydata (1- n)) 1.0d0) step-y))))
    (setf step-x (nreverse step-x)
          step-y (nreverse step-y))
    ;; Create Line2D with step path
    (let ((line (make-instance 'mpl.rendering:line-2d
                               :xdata step-x
                               :ydata step-y
                               :color effective-color
                               :linewidth linewidth
                               :linestyle linestyle
                               :label label
                               :zorder zorder)))
      (setf (mpl.rendering:artist-transform line)
            (axes-base-trans-data ax))
      (axes-add-line ax line)
      (axes-update-datalim ax xdata ydata)
      (axes-autoscale-view ax)
      line)))

;;; ============================================================
;;; stackplot — stacked area plot
;;; ============================================================

(defun stackplot (ax xdata ydatas &key (labels nil) (colors nil) (baseline :zero)
                                        (zorder 1))
  "Draw a stacked area plot.

AX — an axes-base instance.
XDATA — sequence of x coordinates.
YDATAS — list of y-data sequences (one per layer).
LABELS — list of label strings for each layer.
COLORS — list of colors for each layer.
BASELINE — :zero (default), :sym (symmetric), :wiggle.
ZORDER — drawing order.

Returns a list of Polygon patches."
  (declare (ignore baseline))  ; Simplified: always :zero baseline
  (let* ((default-colors '("C0" "C1" "C2" "C3" "C4" "C5" "C6" "C7" "C8" "C9"))
         (n-layers (length ydatas))
         (n-pts (length xdata))
         ;; Compute cumulative sums
         (cumsum (make-array (list (1+ n-layers) n-pts) :element-type 'double-float
                             :initial-element 0.0d0))
         (polys nil))
    ;; cumsum[0] = baseline (zeros)
    ;; cumsum[k] = sum of layers 0..k-1
    (loop for k from 0 below n-layers
          for ydata in ydatas
          do (dotimes (j n-pts)
               (setf (aref cumsum (1+ k) j)
                     (+ (aref cumsum k j)
                        (float (elt ydata j) 1.0d0)))))
    ;; Create filled polygons for each layer
    (loop for k from 0 below n-layers
          for color = (if colors
                          (elt colors (mod k (length colors)))
                          (elt default-colors (mod k (length default-colors))))
          for label = (if (and labels (< k (length labels)))
                          (elt labels k) "")
          do (let* ((total-verts (* 2 n-pts))
                    (verts (make-array (list total-verts 2) :element-type 'double-float)))
               ;; Forward pass: upper boundary (cumsum[k+1])
               (dotimes (j n-pts)
                 (setf (aref verts j 0) (float (elt xdata j) 1.0d0)
                       (aref verts j 1) (aref cumsum (1+ k) j)))
               ;; Backward pass: lower boundary (cumsum[k])
               (dotimes (j n-pts)
                 (let ((rev-j (- n-pts 1 j)))
                   (setf (aref verts (+ n-pts j) 0) (float (elt xdata rev-j) 1.0d0)
                         (aref verts (+ n-pts j) 1) (aref cumsum k rev-j))))
               (let ((poly (make-instance 'mpl.rendering:polygon
                                          :xy verts
                                          :closed t
                                          :facecolor color
                                          :edgecolor "none"
                                          :linewidth 0.0
                                          :label label
                                          :zorder zorder)))
                 (setf (mpl.rendering:artist-transform poly)
                       (axes-base-trans-data ax))
                 (axes-add-patch ax poly)
                 (push poly polys))))
    ;; Update data limits
    (let ((y-max 0.0d0))
      (dotimes (j n-pts)
        (setf y-max (max y-max (aref cumsum n-layers j))))
      (axes-update-datalim ax xdata (list 0.0d0 y-max)))
    (axes-autoscale-view ax)
    (nreverse polys)))

;;; ============================================================
;;; barh — horizontal bar chart
;;; ============================================================

(defun barh (ax y width &key (height 0.8) (left 0) (color nil)
                              (edgecolor "black") (linewidth 0.5)
                              (label "") (zorder 1) (align :center))
  "Make a horizontal bar plot.

AX — an axes-base instance.
Y — sequence of y positions for bars.
WIDTH — sequence of bar widths (horizontal extent).
HEIGHT — bar height (number or sequence, default 0.8).
LEFT — bar left edge (number or sequence, default 0).
COLOR — face color (default C0).
EDGECOLOR — edge color (default black).
LINEWIDTH — edge line width.
LABEL — legend label.
ZORDER — drawing order.
ALIGN — :center or :edge.

Returns a list of Rectangle patches."
  (let* ((effective-color (or color "C0"))
         (n (min (length y) (length width)))
         (rects nil))
    (dotimes (i n)
      (let* ((yi (float (elt y i) 1.0d0))
             (wi (float (elt width i) 1.0d0))
             (hi (if (numberp height)
                     (float height 1.0d0)
                     (float (elt height i) 1.0d0)))
             (li (if (numberp left)
                     (float left 1.0d0)
                     (float (elt left i) 1.0d0)))
             ;; Adjust y based on alignment
             (y0 (if (eq align :center)
                     (- yi (* hi 0.5d0))
                     yi))
             (rect (make-instance 'mpl.rendering:rectangle
                                  :x0 li
                                  :y0 y0
                                  :width wi
                                  :height hi
                                  :facecolor effective-color
                                  :edgecolor edgecolor
                                  :linewidth linewidth
                                  :zorder zorder)))
        (setf (mpl.rendering:artist-transform rect)
              (axes-base-trans-data ax))
        (axes-add-patch ax rect)
        (push rect rects)))
    ;; Update data limits
    (let ((all-x nil) (all-y nil))
      (dotimes (i n)
        (let* ((yi (float (elt y i) 1.0d0))
               (wi (float (elt width i) 1.0d0))
               (hi (if (numberp height) (float height 1.0d0)
                       (float (elt height i) 1.0d0)))
               (li (if (numberp left) (float left 1.0d0)
                       (float (elt left i) 1.0d0)))
               (y0 (if (eq align :center) (- yi (* hi 0.5d0)) yi)))
          (push li all-x)
          (push (+ li wi) all-x)
          (push y0 all-y)
          (push (+ y0 hi) all-y)))
      (axes-update-datalim ax (nreverse all-x) (nreverse all-y)))
    (axes-autoscale-view ax)
    (nreverse rects)))

;;; ============================================================
;;; annotate — add text annotation with optional arrow
;;; ============================================================

(defun annotate (ax text xy &key (xytext nil) (xycoords :data) (textcoords nil)
                                  (arrowprops nil) (bbox nil) (fontsize 12.0)
                                  (color "black") (horizontalalignment :left)
                                  (verticalalignment :baseline) (zorder 3))
  "Annotate the point XY with text TEXT, optionally drawing an arrow.

AX — an axes-base (or mpl-axes) instance.
TEXT — the text of the annotation (string).
XY — point (x y) to annotate (target of arrow).
XYTEXT — position (x y) to place text. Defaults to XY (no arrow).
XYCOORDS — coordinate system for XY: :data, :axes, :figure (default :data).
TEXTCOORDS — coordinate system for XYTEXT. Defaults to XYCOORDS.
ARROWPROPS — plist of arrow properties:
  :arrowstyle (default :->) — arrow head style
  :connectionstyle (default :arc3) — path between points
  :color — arrow color
  :linewidth — arrow line width
  :shrinkA — shrink at start (points)
  :shrinkB — shrink at end (points)
BBOX — plist for text box: :boxstyle :facecolor :edgecolor :pad.
FONTSIZE — font size in points.
COLOR — text color.
HORIZONTALALIGNMENT — :left, :center, :right.
VERTICALALIGNMENT — :top, :center, :bottom, :baseline.
ZORDER — drawing order (default 3).

Returns the created Annotation."
  (let ((ann (make-instance 'mpl.rendering:annotation
                            :text text
                            :xy xy
                            :xytext xytext
                            :xycoords xycoords
                            :textcoords textcoords
                            :arrowprops arrowprops
                            :bbox bbox
                            :fontsize (float fontsize 1.0d0)
                            :color color
                            :horizontalalignment horizontalalignment
                            :verticalalignment verticalalignment
                            :zorder zorder)))
    ;; Set transform to transData
    (setf (mpl.rendering:artist-transform ann)
          (axes-base-trans-data ax))
    ;; Set arrow transform too
    (when (mpl.rendering:annotation-arrow-patch ann)
      (setf (mpl.rendering:artist-transform (mpl.rendering:annotation-arrow-patch ann))
            (axes-base-trans-data ax)))
    ;; Add to axes texts list
    (push ann (axes-base-texts ax))
    ;; Also add to artists for draw ordering
    (axes-add-artist ax ann)
    ;; Mark stale
    (setf (mpl.rendering:artist-stale ax) t)
    ann))

;;; ============================================================
;;; add-subplot — create axes in figure at subplot position
;;; ============================================================

(defun add-subplot (figure nrows ncols index &key (facecolor "white") (frameon t))
  "Add an Axes to FIGURE as part of a subplot arrangement.

FIGURE — an mpl-figure instance.
NROWS — number of rows in subplot grid.
NCOLS — number of columns in subplot grid.
INDEX — 1-based index of the subplot position.
FACECOLOR — axes background color (default white).
FRAMEON — whether to draw axes frame (default T).

Returns the created mpl-axes."
  (let* ((params (figure-subplot-params figure))
         (left (getf params :left))
         (right (getf params :right))
         (bottom (getf params :bottom))
         (top (getf params :top))
         (wspace (getf params :wspace))
         (hspace (getf params :hspace))
         ;; Available area
         (total-w (- right left))
         (total-h (- top bottom))
         ;; Spacing between subplots
         (subplot-w (/ (- total-w (* wspace (1- ncols))) ncols))
         (subplot-h (/ (- total-h (* hspace (1- nrows))) nrows))
         ;; Convert 1-based index to row, col (0-based)
         (row (floor (1- index) ncols))      ; row 0 = top
         (col (mod (1- index) ncols))
         ;; Compute position in figure coordinates
         ;; Row 0 is top, so we flip: pos-bottom = top - (row+1)*h - row*hspace
         (pos-left (+ left (* col (+ subplot-w wspace))))
         (pos-bottom (- top (* (1+ row) subplot-h) (* row hspace)))
         (pos-width subplot-w)
         (pos-height subplot-h))
    ;; Ensure position is within bounds
    (let* ((position (list pos-left pos-bottom pos-width pos-height))
           (ax (make-instance 'mpl-axes
                              :figure figure
                              :position position
                              :facecolor facecolor
                              :frameon frameon
                              :zorder 0)))
      ;; Add to figure's axes list
      (push ax (figure-axes figure))
      ;; Set artist references
      (setf (mpl.rendering:artist-figure ax) figure)
      (setf (mpl.rendering:artist-axes ax) ax)
      (setf (mpl.rendering:artist-stale figure) t)
      ax)))
