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
         ;; Get edge color from rcParams
         (edge-color (mpl.rc:rc "scatter.edgecolors"))
         ;; Get figure DPI for correct point-to-pixel conversion
         (fig-dpi (let ((fig (axes-base-figure ax)))
                    (if fig (figure-dpi fig) 100.0)))
         ;; Create PathCollection
         ;; NOTE: Do NOT set :trans-offset here. axes-base-trans-data is recomputed
         ;; by %update-trans-data after autoscaling, creating a new object.
         ;; The axes draw method propagates the fresh transData to artist-transform,
         ;; which collection's draw uses as fallback when trans-offset is nil.
         (pc (mpl.rendering:make-path-collection
              :paths (list marker-path)
              :offsets offsets
              :sizes sizes
              :facecolors effective-color
              :edgecolors (if (string= edge-color "face") nil edge-color)
              :linewidths 0.0
              :alpha alpha
              :zorder zorder
              :label label
              :dpi fig-dpi)))
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
                              (edgecolor nil) (linewidth 0.0)
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
        ;; Set label on first rect for legend auto-collect
        (when (and (= i 0) (stringp label) (plusp (length label)))
          (setf (mpl.rendering:artist-label rect) label))
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
     ;; Set sticky y-min for bar charts (y=0 is a sticky edge)
     (setf (axes-base-sticky-y-min ax) t)
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
      (axes-add-patch ax poly :at-end t)
      ;; Update data limits from both curves
      (let ((all-y (append (coerce y1data 'list)
                           (coerce y2data 'list))))
        (axes-update-datalim ax xdata all-y))
      (axes-autoscale-view ax)
      poly)))

;;; ============================================================
;;; axhspan / axvspan — shaded region spans
;;; ============================================================

(defun axhspan (ax ymin ymax &key (xmin 0.0) (xmax 1.0) (color "C0") (alpha nil)
                                   (edgecolor "none") (linewidth 0.0) (label "") (zorder 1))
  "Draw a horizontal span (shaded region) between YMIN and YMAX.
YMIN, YMAX — y extent in DATA coordinates.
XMIN, XMAX — x extent as AXES FRACTION (0=left, 1=right). Default: full width.
Returns the created Polygon."
  (multiple-value-bind (x0 x1) (axes-get-xlim ax)
    (let* ((span (if (= x0 x1) 1.0d0 (- x1 x0)))
           (xs (float (+ x0 (* (float xmin 1.0d0) span)) 1.0d0))
           (xe (float (+ x0 (* (float xmax 1.0d0) span)) 1.0d0))
           (ys (float ymin 1.0d0))
           (ye (float ymax 1.0d0))
           (verts (make-array '(4 2) :element-type 'double-float)))
      ;; 4 vertices: bottom-left, bottom-right, top-right, top-left
      (setf (aref verts 0 0) xs  (aref verts 0 1) ys)
      (setf (aref verts 1 0) xe  (aref verts 1 1) ys)
      (setf (aref verts 2 0) xe  (aref verts 2 1) ye)
      (setf (aref verts 3 0) xs  (aref verts 3 1) ye)
      (let ((poly (make-instance 'mpl.rendering:polygon
                                 :xy verts
                                 :closed t
                                 :facecolor color
                                 :edgecolor edgecolor
                                 :linewidth linewidth
                                 :label label
                                 :zorder zorder)))
        (when alpha
          (setf (mpl.rendering:artist-alpha poly) (float alpha 1.0d0)))
        (setf (mpl.rendering:artist-transform poly) (axes-base-trans-data ax))
        ;; Add as patch at end — preserves insertion order for overlapping spans
        (axes-add-patch ax poly :at-end t)
        (setf (mpl.rendering:artist-stale ax) t)
        poly))))

(defun axvspan (ax xmin xmax &key (ymin 0.0) (ymax 1.0) (color "C0") (alpha nil)
                                   (edgecolor "none") (linewidth 0.0) (label "") (zorder 1))
  "Draw a vertical span (shaded region) between XMIN and XMAX.
XMIN, XMAX — x extent in DATA coordinates.
YMIN, YMAX — y extent as AXES FRACTION (0=bottom, 1=top). Default: full height.
Returns the created Polygon."
  (multiple-value-bind (y0 y1) (axes-get-ylim ax)
    (let* ((span (if (= y0 y1) 1.0d0 (- y1 y0)))
           (ys (float (+ y0 (* (float ymin 1.0d0) span)) 1.0d0))
           (ye (float (+ y0 (* (float ymax 1.0d0) span)) 1.0d0))
           (xs (float xmin 1.0d0))
           (xe (float xmax 1.0d0))
           (verts (make-array '(4 2) :element-type 'double-float)))
      ;; 4 vertices: bottom-left, bottom-right, top-right, top-left
      (setf (aref verts 0 0) xs  (aref verts 0 1) ys)
      (setf (aref verts 1 0) xe  (aref verts 1 1) ys)
      (setf (aref verts 2 0) xe  (aref verts 2 1) ye)
      (setf (aref verts 3 0) xs  (aref verts 3 1) ye)
      (let ((poly (make-instance 'mpl.rendering:polygon
                                 :xy verts
                                 :closed t
                                 :facecolor color
                                 :edgecolor edgecolor
                                 :linewidth linewidth
                                 :label label
                                 :zorder zorder)))
        (when alpha
          (setf (mpl.rendering:artist-alpha poly) (float alpha 1.0d0)))
        (setf (mpl.rendering:artist-transform poly) (axes-base-trans-data ax))
        ;; Add as patch at end — preserves insertion order for overlapping spans
        (axes-add-patch ax poly :at-end t)
        (setf (mpl.rendering:artist-stale ax) t)
        poly))))

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
;;; %apply-autopct — Python-to-CL format string conversion
;;; ============================================================

(defun %apply-autopct (autopct pct)
  "Apply autopct format string to percentage value PCT.
Supports both Python-style ('%1.1f%%') and CL FORMAT-style ('~,1F%').
Returns the formatted string."
  (if (find #\~ autopct)
      ;; CL FORMAT style — use directly
      (format nil autopct pct)
      ;; Python %-format style — parse and convert
      (let ((result (make-array 0 :element-type 'character :adjustable t :fill-pointer 0))
            (i 0)
            (len (length autopct)))
        (loop while (< i len) do
          (let ((ch (char autopct i)))
            (cond
              ;; %% → literal %
              ((and (char= ch #\%) (< (1+ i) len) (char= (char autopct (1+ i)) #\%))
               (vector-push-extend #\% result)
               (incf i 2))
              ;; % followed by format spec
              ((char= ch #\%)
               (incf i) ; skip %
               ;; Skip optional width digits
               (loop while (and (< i len) (digit-char-p (char autopct i)))
                     do (incf i))
               ;; Parse .precision
               (let ((precision nil))
                 (when (and (< i len) (char= (char autopct i) #\.))
                   (incf i) ; skip .
                   (setf precision 0)
                   (loop while (and (< i len) (digit-char-p (char autopct i)))
                         do (setf precision (+ (* precision 10)
                                               (digit-char-p (char autopct i))))
                            (incf i)))
                 ;; Format specifier character
                 (when (< i len)
                   (let ((spec (char autopct i)))
                     (incf i)
                     (let ((formatted
                             (cond
                               ((char= spec #\f)
                                (if precision
                                    (format nil (format nil "~~,~DF" precision) pct)
                                    (format nil "~F" pct)))
                               ((char= spec #\d)
                                (format nil "~D" (round pct)))
                               (t (string spec)))))
                       (loop for c across formatted
                             do (vector-push-extend c result)))))))
              ;; Regular character
              (t
               (vector-push-extend ch result)
               (incf i)))))
        (coerce result 'string))))

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
  ;; Set view limits BEFORE creating artists so that transData is stable.
  ;; Artists (patches + text labels) capture transData at creation time;
  ;; setting limits afterwards would leave text artists with a stale transform
  ;; (patches are refreshed in the draw method, but texts are not).
  (axes-set-xlim ax :min -1.25d0 :max 1.25d0)
  (axes-set-ylim ax :min -1.25d0 :max 1.25d0)
  ;; Enforce equal aspect ratio (matplotlib's pie() calls set_aspect('equal')).
  ;; Adjust axes position so display bbox is square, centering the shorter dimension.
  (multiple-value-bind (dx dy dw dh) (%compute-display-bbox ax)
    (declare (ignore dx dy))
    (when (and (> dw 0) (> dh 0) (/= dw dh))
      (let* ((fig (axes-base-figure ax))
             (pos (axes-base-position ax))
             (fig-w (if fig (float (figure-width-px fig) 1.0d0) 640.0d0))
             (fig-h (if fig (float (figure-height-px fig) 1.0d0) 480.0d0))
             (side (min dw dh)))
        (if (> dw dh)
            ;; Width > height: narrow the width, center horizontally
            (let* ((new-width-frac (/ side fig-w))
                   (old-left (first pos))
                   (old-width (third pos))
                   (new-left (+ old-left (/ (- old-width new-width-frac) 2.0d0))))
              (setf (axes-base-position ax)
                    (list new-left (second pos) new-width-frac (fourth pos))))
            ;; Height > width: shorten the height, center vertically
            (let* ((new-height-frac (/ side fig-h))
                   (old-bottom (second pos))
                   (old-height (fourth pos))
                   (new-bottom (+ old-bottom (/ (- old-height new-height-frac) 2.0d0))))
              (setf (axes-base-position ax)
                    (list (first pos) new-bottom (third pos) new-height-frac))))
        ;; Recompute transforms with new position
        (%setup-transforms ax))))
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
                                                :edgecolor nil
                                                :linewidth 0.0
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
                       (pct-text (%apply-autopct autopct pct))
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
    ;; Set up pie chart display — match matplotlib behavior:
    ;; (view limits already set above, before artist creation)
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
           do (let* (;; +1 extra vertex so the last backward point is LINETO (not CLOSEPOLY)
                     ;; This ensures the left edge is drawn correctly as a vertical line
                     (total-verts (+ (* 2 n-pts) 1))
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
                ;; Extra closing vertex = same as start, so CLOSEPOLY draws the left edge
                (setf (aref verts (* 2 n-pts) 0) (aref verts 0 0)
                      (aref verts (* 2 n-pts) 1) (aref verts 0 1))
                (let ((poly (make-instance 'mpl.rendering:polygon
                                           :xy verts
                                           :closed t
                                           :facecolor color
                                           :edgecolor color
                                           :linewidth 0.5
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
    ;; Set sticky y-min: stackplot always starts at y=0 (sticky edge)
    (setf (axes-base-sticky-y-min ax) t)
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
        ;; Set label on first rect for legend auto-collect
        (when (and (= i 0) (stringp label) (plusp (length label)))
          (setf (mpl.rendering:artist-label rect) label))
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
    (setf (axes-base-sticky-x-min ax) t)
    (axes-autoscale-view ax)
    (nreverse rects)))

;;; ============================================================
;;; text — place arbitrary text on axes
;;; ============================================================

(defun text (ax x y s &key (fontsize 12.0) (color "black") (alpha nil)
                            (ha :left) (va :baseline) (rotation 0.0)
                            (zorder 3))
  "Place text S at position (X, Y) in data coordinates on AX.

HA — horizontal alignment: :left, :center, :right.
VA — vertical alignment: :top, :center, :bottom, :baseline.
ROTATION — text rotation in degrees.
Returns the created text-artist."
  (let ((txt (make-instance 'mpl.rendering:text-artist
                            :x (float x 1.0d0)
                            :y (float y 1.0d0)
                            :text s
                            :fontsize (float fontsize 1.0d0)
                            :color color
                            :horizontalalignment ha
                            :verticalalignment va
                            :rotation (float rotation 1.0d0)
                            :zorder zorder)))
    (when alpha
      (setf (mpl.rendering:artist-alpha txt) (float alpha 1.0d0)))
    ;; Set transform to transData (data coordinates)
    (setf (mpl.rendering:artist-transform txt)
          (axes-base-trans-data ax))
    ;; Add to axes texts list and artists
    (push txt (axes-base-texts ax))
    (axes-add-artist ax txt)
    (setf (mpl.rendering:artist-stale ax) t)
    txt))

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
;;; axhline — horizontal reference line
;;; ============================================================

(defun axhline (ax y &key (xmin 0.0) (xmax 1.0) (color "C0") (linewidth 1.5)
                           (linestyle :solid) (alpha nil) (label "") (zorder 2))
  "Draw a horizontal line at Y across the axes.
Y — y position in DATA coordinates.
XMIN, XMAX — fraction of x-axis span (0=left edge, 1=right edge). Default: full width.
Returns the created Line2D."
  (multiple-value-bind (x0 x1) (axes-get-xlim ax)
    ;; If axes has no data yet, use xmin/xmax as data coords directly
    (let* ((span (if (= x0 x1) 1.0d0 (- x1 x0)))
           (xs (float (+ x0 (* (float xmin 1.0d0) span)) 1.0d0))
           (xe (float (+ x0 (* (float xmax 1.0d0) span)) 1.0d0))
           (line (make-instance 'mpl.rendering:line-2d
                                :xdata (list xs xe)
                                :ydata (list (float y 1.0d0) (float y 1.0d0))
                                :color color
                                :linewidth linewidth
                                :linestyle linestyle
                                :label label
                                :zorder zorder)))
      (when alpha
        (setf (mpl.rendering:artist-alpha line) (float alpha 1.0d0)))
      (setf (mpl.rendering:artist-transform line) (axes-base-trans-data ax))
      ;; Add line WITHOUT updating datalim (axhline doesn't affect autoscaling)
      (axes-add-line ax line)
      (setf (mpl.rendering:artist-stale ax) t)
      line)))

;;; ============================================================
;;; axvline — vertical reference line
;;; ============================================================

(defun axvline (ax x &key (ymin 0.0) (ymax 1.0) (color "C0") (linewidth 1.5)
                           (linestyle :solid) (alpha nil) (label "") (zorder 2))
  "Draw a vertical line at X across the axes.
X — x position in DATA coordinates.
YMIN, YMAX — fraction of y-axis span (0=bottom, 1=top). Default: full height.
Returns the created Line2D."
  (multiple-value-bind (y0 y1) (axes-get-ylim ax)
    (let* ((span (if (= y0 y1) 1.0d0 (- y1 y0)))
           (ys (float (+ y0 (* (float ymin 1.0d0) span)) 1.0d0))
           (ye (float (+ y0 (* (float ymax 1.0d0) span)) 1.0d0))
           (line (make-instance 'mpl.rendering:line-2d
                                :xdata (list (float x 1.0d0) (float x 1.0d0))
                                :ydata (list ys ye)
                                :color color
                                :linewidth linewidth
                                :linestyle linestyle
                                :label label
                                :zorder zorder)))
      (when alpha
        (setf (mpl.rendering:artist-alpha line) (float alpha 1.0d0)))
      (setf (mpl.rendering:artist-transform line) (axes-base-trans-data ax))
      (axes-add-line ax line)
      (setf (mpl.rendering:artist-stale ax) t)
      line)))

;;; ============================================================
;;; hlines — multiple horizontal lines at data coordinates
;;; ============================================================

(defun hlines (ax y xmin xmax &key (colors "C0") (linestyles :solid)
                                    (linewidth 1.5) (alpha nil) (label "") (zorder 2))
  "Draw horizontal lines at each y in Y from xmin to xmax (all in DATA coordinates).
Y — scalar or list of y values.
XMIN, XMAX — x extent in data coordinates (scalar or list matching Y).
Returns list of Line2D objects."
  (let* ((ys (if (listp y) y (list y)))
         (xmins (if (listp xmin) xmin (make-list (length ys) :initial-element xmin)))
         (xmaxs (if (listp xmax) xmax (make-list (length ys) :initial-element xmax)))
         (colorlist (if (listp colors) colors (make-list (length ys) :initial-element colors)))
         (lines nil))
    (loop for yi in ys
          for x0 in xmins
          for x1 in xmaxs
          for col in colorlist
          do (let ((line (make-instance 'mpl.rendering:line-2d
                                        :xdata (list (float x0 1.0d0) (float x1 1.0d0))
                                        :ydata (list (float yi 1.0d0) (float yi 1.0d0))
                                        :color col
                                        :linewidth linewidth
                                        :linestyle linestyles
                                        :label label
                                        :zorder zorder)))
               (when alpha (setf (mpl.rendering:artist-alpha line) (float alpha 1.0d0)))
               (setf (mpl.rendering:artist-transform line) (axes-base-trans-data ax))
               (axes-add-line ax line)
               (axes-update-datalim ax (list x0 x1) (list yi yi))
               (push line lines)))
    (axes-autoscale-view ax)
    (setf (mpl.rendering:artist-stale ax) t)
    (nreverse lines)))

;;; ============================================================
;;; vlines — multiple vertical lines at data coordinates
;;; ============================================================

(defun vlines (ax x ymin ymax &key (colors "C0") (linestyles :solid)
                                    (linewidth 1.5) (alpha nil) (label "") (zorder 2))
  "Draw vertical lines at each x in X from ymin to ymax (all in DATA coordinates).
X — scalar or list of x values.
YMIN, YMAX — y extent in data coordinates (scalar or list matching X).
Returns list of Line2D objects."
  (let* ((xs (if (listp x) x (list x)))
         (ymins (if (listp ymin) ymin (make-list (length xs) :initial-element ymin)))
         (ymaxs (if (listp ymax) ymax (make-list (length xs) :initial-element ymax)))
         (colorlist (if (listp colors) colors (make-list (length xs) :initial-element colors)))
         (lines nil))
    (loop for xi in xs
          for y0 in ymins
          for y1 in ymaxs
          for col in colorlist
          do (let ((line (make-instance 'mpl.rendering:line-2d
                                        :xdata (list (float xi 1.0d0) (float xi 1.0d0))
                                        :ydata (list (float y0 1.0d0) (float y1 1.0d0))
                                        :color col
                                        :linewidth linewidth
                                        :linestyle linestyles
                                        :label label
                                        :zorder zorder)))
               (when alpha (setf (mpl.rendering:artist-alpha line) (float alpha 1.0d0)))
               (setf (mpl.rendering:artist-transform line) (axes-base-trans-data ax))
               (axes-add-line ax line)
               (axes-update-datalim ax (list xi xi) (list y0 y1))
               (push line lines)))
    (axes-autoscale-view ax)
    (setf (mpl.rendering:artist-stale ax) t)
    (nreverse lines)))

;;; ============================================================
;;; pcolormesh — pseudocolor mesh plot
;;; ============================================================

(defun axes-pcolormesh (ax c &key x y (cmap nil) (vmin nil) (vmax nil) (alpha nil)
                                       (zorder 1))
  "Create a pseudocolor mesh plot of 2D array C on axes AX.

AX — an axes-base instance.
C — 2D array of scalar values (H rows × W columns).
X, Y — optional (H+1)×(W+1) arrays of corner coordinates. If nil, implicit grid.
CMAP — colormap name (keyword or string) or nil for viridis.
VMIN, VMAX — data range for colormap normalization.
ALPHA — transparency.
ZORDER — drawing order (default 1).

Returns a scalar-mappable (for use with colorbar)."
  (let* ((h (array-dimension c 0))
         (w (array-dimension c 1))
         ;; Resolve colormap
         (effective-cmap (if cmap
                             (if (or (keywordp cmap) (stringp cmap))
                                 (mpl.primitives:get-colormap cmap)
                                 cmap)
                             (mpl.primitives:get-colormap :viridis)))
         ;; Compute vmin/vmax from data if not specified
         (data-min most-positive-double-float)
         (data-max most-negative-double-float))
    ;; Scan C for min/max
    (dotimes (row h)
      (dotimes (col w)
        (let ((v (float (aref c row col) 1.0d0)))
          (when (< v data-min) (setf data-min v))
          (when (> v data-max) (setf data-max v)))))
    (let* ((eff-vmin (float (or vmin data-min) 1.0d0))
           (eff-vmax (float (or vmax data-max) 1.0d0))
           ;; Build coordinates array: (H+1)×(W+1)×2
           (coords (make-array (list (1+ h) (1+ w) 2) :element-type 'double-float
                                                        :initial-element 0.0d0))
           ;; Track data limits
           (x-min most-positive-double-float)
           (x-max most-negative-double-float)
           (y-min most-positive-double-float)
           (y-max most-negative-double-float))
      ;; Fill coordinates
      (if (and x y)
          ;; Explicit X, Y grids
          (dotimes (i (1+ h))
            (dotimes (j (1+ w))
              (let ((xv (float (aref x i j) 1.0d0))
                    (yv (float (aref y i j) 1.0d0)))
                (setf (aref coords i j 0) xv
                      (aref coords i j 1) yv)
                (when (< xv x-min) (setf x-min xv))
                (when (> xv x-max) (setf x-max xv))
                (when (< yv y-min) (setf y-min yv))
                (when (> yv y-max) (setf y-max yv)))))
          ;; Implicit grid: coords[i][j] = (j, i)
          (progn
            (dotimes (i (1+ h))
              (dotimes (j (1+ w))
                (setf (aref coords i j 0) (float j 1.0d0)
                      (aref coords i j 1) (float i 1.0d0))))
            (setf x-min 0.0d0 x-max (float w 1.0d0)
                  y-min 0.0d0 y-max (float h 1.0d0))))
      ;; Apply colormap to get per-cell facecolors
      (let* ((range (- eff-vmax eff-vmin))
             (facecolors
               (let ((colors nil))
                 (dotimes (row h)
                   (dotimes (col w)
                     (let* ((v (float (aref c row col) 1.0d0))
                            (norm-v (if (zerop range) 0.5d0
                                        (max 0.0d0 (min 1.0d0
                                                        (/ (- v eff-vmin) range)))))
                            (rgba (mpl.primitives:colormap-call effective-cmap norm-v))
                            (hex (format nil "#~2,'0x~2,'0x~2,'0x"
                                         (round (* (aref rgba 0) 255))
                                         (round (* (aref rgba 1) 255))
                                         (round (* (aref rgba 2) 255)))))
                       (push hex colors))))
                 (nreverse colors)))
             ;; Create QuadMesh
             (qm (make-instance 'mpl.rendering:quad-mesh
                                :mesh-width w
                                :mesh-height h
                                :coordinates coords
                                :facecolors facecolors
                                :edgecolors '("none")
                                :linewidths '(0.0)
                                :zorder zorder)))
        (when alpha
          (setf (mpl.rendering:artist-alpha qm) (float alpha 1.0d0)))
        ;; Set transform
        (setf (mpl.rendering:artist-transform qm)
              (axes-base-trans-data ax))
        ;; Add to axes
        (axes-add-artist ax qm)
        ;; Update data limits
        (axes-update-datalim ax (list x-min x-max) (list y-min y-max))
        (axes-autoscale-view ax :tight t)
        ;; Create scalar-mappable for colorbar integration
        (let* ((norm (mpl.primitives:make-normalize :vmin eff-vmin :vmax eff-vmax))
               (sm (mpl.primitives:make-scalar-mappable :norm norm :cmap effective-cmap)))
          sm)))))

;;; ============================================================
;;; add-subplot — create axes in figure at subplot position
;;; ============================================================

(defun add-subplot (figure nrows ncols index &key (facecolor "white") (frameon t) (projection nil))
   "Add an Axes to FIGURE as part of a subplot arrangement.

FIGURE — an mpl-figure instance.
NROWS — number of rows in subplot grid.
NCOLS — number of columns in subplot grid.
INDEX — 1-based index of the subplot position.
FACECOLOR — axes background color (default white).
FRAMEON — whether to draw axes frame (default T).
PROJECTION — axes projection type (:polar for polar axes, NIL for rectangular).

Returns the created mpl-axes or polar-axes."
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
            (ax (case projection
                  (:polar (make-instance 'polar-axes
                                         :figure figure
                                         :position position
                                         :facecolor facecolor
                                         :frameon frameon
                                         :zorder 0))
                  (otherwise (make-instance 'mpl-axes
                                            :figure figure
                                            :position position
                                            :facecolor facecolor
                                            :frameon frameon
                                            :zorder 0)))))
       ;; Add to figure's axes list
       (push ax (figure-axes figure))
       ;; Set artist references
       (setf (mpl.rendering:artist-figure ax) figure)
       (setf (mpl.rendering:artist-axes ax) ax)
       (setf (mpl.rendering:artist-stale figure) t)
       ax)))

;;; ============================================================
;;; twinx / twiny — dual-axis overlaid axes
;;; ============================================================

(defun axes-twinx (ax)
  "Create a twin axes overlaid on AX, sharing the x-axis but with an
independent y-axis on the right side.
Returns the new twin mpl-axes.
Ported from matplotlib.axes.Axes.twinx."
  (let* ((fig (axes-base-figure ax))
         (pos (axes-base-position ax))
         ;; Create new axes at the same position with transparent background
         (twin (make-instance 'mpl-axes
                               :figure fig
                               :position (copy-list pos)
                               :facecolor "none"
                               :frameon nil
                               :zorder (1+ (mpl.rendering:artist-zorder ax)))))
    ;; Set artist references
    (setf (mpl.rendering:artist-figure twin) fig)
    (setf (mpl.rendering:artist-axes twin) twin)
    ;; Share x-axis: twin's x-limits track parent's
    (axes-share-x twin ax)
    ;; Set twin's y-axis to draw on the right side
    (setf (axis-side (axes-base-yaxis twin)) :right)
    ;; Hide twin's x-axis tick labels (parent already has them on bottom)
    (setf (axis-tick-labels-visible-p (axes-base-xaxis twin)) nil)
    ;; Configure spines: hide left/top/bottom on twin, show right
    (when (axes-base-spines twin)
      (spine-set-visible (spines-ref (axes-base-spines twin) "left") nil)
      (spine-set-visible (spines-ref (axes-base-spines twin) "top") nil)
      (spine-set-visible (spines-ref (axes-base-spines twin) "bottom") nil)
      (spine-set-visible (spines-ref (axes-base-spines twin) "right") t))
    ;; Hide the right spine on the parent (twin owns it now)
    (when (axes-base-spines ax)
      (spine-set-visible (spines-ref (axes-base-spines ax) "right") nil))
    ;; Add twin to figure's axes list (first position = current axes for gca)
    (push twin (figure-axes fig))
    (setf (mpl.rendering:artist-stale fig) t)
    twin))

(defun axes-twiny (ax)
  "Create a twin axes overlaid on AX, sharing the y-axis but with an
independent x-axis on the top side.
Returns the new twin mpl-axes.
Ported from matplotlib.axes.Axes.twiny."
  (let* ((fig (axes-base-figure ax))
         (pos (axes-base-position ax))
         ;; Create new axes at the same position with transparent background
         (twin (make-instance 'mpl-axes
                               :figure fig
                               :position (copy-list pos)
                               :facecolor "none"
                               :frameon nil
                               :zorder (1+ (mpl.rendering:artist-zorder ax)))))
    ;; Set artist references
    (setf (mpl.rendering:artist-figure twin) fig)
    (setf (mpl.rendering:artist-axes twin) twin)
    ;; Share y-axis: twin's y-limits track parent's
    (axes-share-y twin ax)
    ;; Set twin's x-axis to draw on the top side
    (setf (axis-side (axes-base-xaxis twin)) :top)
    ;; Hide twin's y-axis tick labels (parent already has them on left)
    (setf (axis-tick-labels-visible-p (axes-base-yaxis twin)) nil)
    ;; Configure spines: hide left/bottom/right on twin, show top
    (when (axes-base-spines twin)
      (spine-set-visible (spines-ref (axes-base-spines twin) "left") nil)
      (spine-set-visible (spines-ref (axes-base-spines twin) "bottom") nil)
      (spine-set-visible (spines-ref (axes-base-spines twin) "right") nil)
      (spine-set-visible (spines-ref (axes-base-spines twin) "top") t))
    ;; Hide the top spine on the parent (twin owns it now)
    (when (axes-base-spines ax)
      (spine-set-visible (spines-ref (axes-base-spines ax) "top") nil))
    ;; Add twin to figure's axes list (first position = current axes for gca)
    (push twin (figure-axes fig))
    (setf (mpl.rendering:artist-stale fig) t)
    twin))
