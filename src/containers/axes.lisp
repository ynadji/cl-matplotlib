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

Returns a list of created artists (patches for each point)."
  (let* ((effective-color (or c color "C0"))
         (n (min (length xdata) (length ydata)))
         (marker-size (sqrt (float s 1.0d0)))  ; diameter from area
         (artists nil))
    ;; Create a small circle patch for each data point
    (dotimes (i n)
      (let* ((x (float (elt xdata i) 1.0d0))
             (y (float (elt ydata i) 1.0d0))
             (circle (make-instance 'mpl.rendering:circle
                                    :center (list x y)
                                    :radius (* marker-size 0.5d0)
                                    :facecolor effective-color
                                    :edgecolor effective-color
                                    :linewidth 0.5
                                    :zorder zorder)))
        (when alpha
          (setf (mpl.rendering:artist-alpha circle)
                (float alpha 1.0d0)))
        ;; Set transform to transData
        (setf (mpl.rendering:artist-transform circle)
              (axes-base-trans-data ax))
        (axes-add-patch ax circle)
        (push circle artists)))
    ;; Update data limits
    (axes-update-datalim ax xdata ydata)
    ;; Autoscale
    (axes-autoscale-view ax)
    (nreverse artists)))

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
  (let* ((effective-color (or color "C0"))
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
