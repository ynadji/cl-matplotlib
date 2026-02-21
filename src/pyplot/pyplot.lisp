;;;; pyplot.lisp — Procedural plotting interface
;;;; Ported from matplotlib's pyplot.py
;;;; Provides a stateful, user-friendly API wrapping the OO Figure/Axes classes.
;;;;
;;;; Usage:
;;;;   (plt:figure)
;;;;   (plt:plot '(1 2 3 4) '(1 4 9 16))
;;;;   (plt:xlabel "X")
;;;;   (plt:ylabel "Y")
;;;;   (plt:title "Test Plot")
;;;;   (plt:savefig "output.png")

(in-package #:cl-matplotlib.pyplot)

;;; ============================================================
;;; Global state — figure tracking
;;; ============================================================

(defvar *figures* (make-hash-table :test 'eql)
  "Hash table mapping figure numbers to mpl-figure objects.")

(defvar *current-figure* nil
  "Current figure number (integer), or NIL if no figure exists.")

(defvar *figure-counter* 0
  "Auto-incrementing counter for figure numbers.")

;;; ============================================================
;;; Figure management
;;; ============================================================

(defun figure (&key (num nil) (figsize '(6.4d0 4.8d0)) (dpi 100)
                    (facecolor "white") (edgecolor "white") (frameon t)
                    (layout nil))
  "Create a new figure or switch to an existing one.

NUM — figure number. If NIL, auto-assign next number.
      If a figure with this number exists, switch to it.
FIGSIZE — (width height) in inches, default (6.4 4.8).
DPI — dots per inch, default 100.
FACECOLOR — background color, default white.
EDGECOLOR — frame edge color, default white.
FRAMEON — whether to draw background, default T.
LAYOUT — layout engine: :tight, :none, or NIL.

Returns the figure object."
  (let ((fig-num (or num (incf *figure-counter*))))
    ;; If figure already exists, just switch to it
    (let ((existing (gethash fig-num *figures*)))
      (when existing
        (setf *current-figure* fig-num)
        (return-from figure existing)))
    ;; Create new figure
    (let ((fig (mpl.containers:make-figure
                :figsize figsize :dpi dpi
                :facecolor facecolor :edgecolor edgecolor
                :linewidth 0.0 :frameon frameon
                :layout layout)))
      ;; Track the figure counter if num was provided
      (when (and num (> num *figure-counter*))
        (setf *figure-counter* num))
      (setf (gethash fig-num *figures*) fig)
      (setf *current-figure* fig-num)
      fig)))

(defun gcf ()
  "Get the current figure. Creates a new one if none exists.
Returns the current mpl-figure object."
  (if (and *current-figure* (gethash *current-figure* *figures*))
      (gethash *current-figure* *figures*)
      (figure)))

(defun gca ()
  "Get the current axes. Creates figure and axes if needed.
Returns the current axes object."
  (let* ((fig (gcf))
         (axes-list (mpl.containers:figure-axes fig)))
    (if axes-list
        ;; Return the most recently added axes (first in the list)
        (first axes-list)
        ;; No axes — create default subplot (1,1,1)
        (mpl.containers:add-subplot fig 1 1 1))))

(defun close-figure (&optional (num :current))
  "Close figure(s).

NUM — figure number to close, or:
  :current — close current figure (default)
  :all — close all figures
  An integer — close that specific figure.

After closing, switches to the highest-numbered remaining figure."
  (cond
    ((eq num :all)
     (clrhash *figures*)
     (setf *current-figure* nil))
    ((eq num :current)
     (when *current-figure*
       (remhash *current-figure* *figures*)
       ;; Switch to highest remaining figure
       (setf *current-figure*
             (let ((max-num nil))
               (maphash (lambda (k v)
                          (declare (ignore v))
                          (when (or (null max-num) (> k max-num))
                            (setf max-num k)))
                        *figures*)
               max-num))))
    ((integerp num)
     (remhash num *figures*)
     (when (eql num *current-figure*)
       (setf *current-figure*
             (let ((max-num nil))
               (maphash (lambda (k v)
                          (declare (ignore v))
                          (when (or (null max-num) (> k max-num))
                            (setf max-num k)))
                        *figures*)
               max-num))))
    (t (error "close-figure: NUM must be :current, :all, or an integer, got ~S" num))))

(defun clf ()
  "Clear the current figure — remove all axes and artists."
  (let ((fig (gcf)))
    (setf (mpl.containers:figure-axes fig) nil)
    (setf (mpl.containers:figure-artists fig) nil)
    (setf (mpl.containers:figure-lines fig) nil)
    (setf (mpl.containers:figure-patches fig) nil)
    (setf (mpl.containers:figure-texts fig) nil)
    (setf (mpl.containers:figure-images fig) nil)
    (setf (mpl.containers:figure-legends fig) nil)
    (setf (mpl.rendering:artist-stale fig) t)
    fig))

(defun cla ()
  "Clear the current axes — remove all artists from current axes."
  (let ((ax (gca)))
    (setf (mpl.containers:axes-base-lines ax) nil)
    (setf (mpl.containers:axes-base-patches ax) nil)
    (setf (mpl.containers:axes-base-artists ax) nil)
    (setf (mpl.containers:axes-base-texts ax) nil)
    (setf (mpl.containers:axes-base-images ax) nil)
    (setf (mpl.containers:axes-base-legend ax) nil)
    ;; Reset data limits
    (setf (mpl.containers:axes-base-data-lim ax) (mpl.primitives:bbox-null))
    (setf (mpl.containers:axes-base-view-lim ax)
          (mpl.primitives:make-bbox 0.0d0 0.0d0 1.0d0 1.0d0))
    (setf (mpl.rendering:artist-stale ax) t)
    ax))

;;; ============================================================
;;; Subplot creation
;;; ============================================================

(defun subplots (&optional (nrows 1) (ncols 1) &key (sharex nil) (sharey nil)
                                                     (squeeze t) (figsize nil)
                                                     (dpi nil))
  "Create a figure with a grid of NROWSxNCOLS axes.

NROWS — number of rows (default 1).
NCOLS — number of columns (default 1).
SHAREX — share X axis: T, NIL, :all, :row, :col, :none.
SHAREY — share Y axis: T, NIL, :all, :row, :col, :none.
SQUEEZE — if T, squeeze out dimensions of length 1.
FIGSIZE — figure size (width height) in inches.
DPI — resolution.

Returns (values figure axes) where axes is a single axes, 1D array, or 2D array."
  (let* ((fig-args (append (when figsize (list :figsize figsize))
                           (when dpi (list :dpi dpi))))
         (fig (apply #'figure fig-args))
         (axes (mpl.containers:subplots fig nrows ncols
                                        :sharex sharex :sharey sharey
                                        :squeeze squeeze)))
    (values fig axes)))

;;; ============================================================
;;; Plot function wrappers — delegate to current axes
;;; ============================================================

(defun plot (xdata ydata &key (color nil) (linewidth 1.5) (linestyle :solid)
                              (marker :none) (label "") (zorder 2))
  "Plot y versus x as lines and/or markers on the current axes.

XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
COLOR — line color (string or nil for default).
LINEWIDTH — line width in points (default 1.5).
LINESTYLE — :solid, :dashed, :dashdot, :dotted.
MARKER — marker style keyword (default :none).
LABEL — legend label string.
ZORDER — drawing order (default 2).

Returns a list containing the created Line2D."
  (mpl.containers:plot (gca) xdata ydata
                        :color color :linewidth linewidth :linestyle linestyle
                        :marker marker :label label :zorder zorder))

(defun scatter (xdata ydata &key (s 36.0) (c nil) (marker :circle)
                                 (color nil) (label "") (zorder 1) (alpha nil))
  "Make a scatter plot on the current axes.

XDATA — sequence of x coordinates.
YDATA — sequence of y coordinates.
S — marker size in points^2.
C — color specification.
MARKER — marker style (default :circle).
COLOR — alias for C.
LABEL — legend label.
ZORDER — drawing order.
ALPHA — transparency.

Returns the PathCollection artist."
  (mpl.containers:scatter (gca) xdata ydata
                           :s s :c c :marker marker :color color
                           :label label :zorder zorder :alpha alpha))

(defun bar (x height &key (width 0.8) (bottom 0) (color nil)
                           (edgecolor "black") (linewidth 0.5)
                           (label "") (zorder 1) (align :center))
  "Make a bar plot on the current axes.

X — sequence of x positions.
HEIGHT — sequence of bar heights.
WIDTH — bar width (default 0.8).
BOTTOM — bar bottom (default 0).
COLOR — face color.
EDGECOLOR — edge color.
LINEWIDTH — edge line width.
LABEL — legend label.
ZORDER — drawing order.
ALIGN — :center or :edge.

Returns a list of Rectangle patches."
  (mpl.containers:bar (gca) x height
                       :width width :bottom bottom :color color
                       :edgecolor edgecolor :linewidth linewidth
                       :label label :zorder zorder :align align))

(defun hist (data &key (bins 10) (range nil) (density nil) (cumulative nil)
                       (histtype :bar) (color nil) (edgecolor "black")
                       (linewidth 1.0) (alpha nil) (label "") (zorder 1))
  "Plot a histogram on the current axes.

DATA — sequence of data values.
BINS — number of bins or list of bin edges.
RANGE — (min max) range for binning.
DENSITY — if T, normalize to probability density.
CUMULATIVE — if T, cumulative histogram.
HISTTYPE — :bar, :step, :stepfilled.
COLOR — bar face color.
EDGECOLOR — bar edge color.
LINEWIDTH — edge line width.
ALPHA — transparency.
LABEL — legend label.
ZORDER — drawing order."
  (mpl.containers:hist (gca) data
                        :bins bins :range range :density density
                        :cumulative cumulative :histtype histtype
                        :color color :edgecolor edgecolor
                        :linewidth linewidth :alpha alpha
                        :label label :zorder zorder))

(defun imshow (data &key (cmap nil) (norm nil) (interpolation :nearest)
                         (extent nil) (origin :upper) (aspect :equal)
                         (alpha nil) (vmin nil) (vmax nil) (zorder 0))
  "Display a 2D data array as an image on the current axes.

DATA — 2D array (grayscale) or 3D array (RGB/RGBA).
CMAP — colormap keyword or instance.
NORM — normalize instance.
INTERPOLATION — :nearest or :bilinear.
EXTENT — (xmin xmax ymin ymax).
ORIGIN — :upper or :lower.
ASPECT — :auto, :equal, or numeric.
ALPHA — transparency.
VMIN, VMAX — data range.
ZORDER — drawing order.

Returns the created AxesImage."
  (mpl.containers:imshow (gca) data
                          :cmap cmap :norm norm :interpolation interpolation
                          :extent extent :origin origin :aspect aspect
                          :alpha alpha :vmin vmin :vmax vmax :zorder zorder))

(defun contour (x y z &key levels colors linewidths linestyles
                            cmap norm alpha (zorder 2))
  "Draw contour lines on the current axes.

X — 1D sequence of X coordinates.
Y — 1D sequence of Y coordinates.
Z — 2D array of scalar values.
LEVELS — list of level values.
COLORS — explicit colors.
LINEWIDTHS — line width(s).
LINESTYLES — line style(s).
CMAP — colormap.
NORM — normalization.
ALPHA — transparency.
ZORDER — drawing order.

Returns a QuadContourSet."
  (mpl.containers:contour (gca) x y z
                           :levels levels :colors colors
                           :linewidths linewidths :linestyles linestyles
                           :cmap cmap :norm norm :alpha alpha :zorder zorder))

(defun contourf (x y z &key levels cmap norm alpha colors (zorder 1))
  "Draw filled contours on the current axes.

X — 1D sequence of X coordinates.
Y — 1D sequence of Y coordinates.
Z — 2D array of scalar values.
LEVELS — list of level values.
CMAP — colormap.
NORM — normalization.
ALPHA — transparency.
COLORS — explicit colors.
ZORDER — drawing order.

Returns a QuadContourSet."
  (mpl.containers:contourf (gca) x y z
                            :levels levels :cmap cmap :norm norm
                            :alpha alpha :colors colors :zorder zorder))

(defun pie (x &key (labels nil) (colors nil) (autopct nil)
                    (startangle 0) (counterclock t)
                    (wedgeprops nil) (textprops nil) (zorder 1))
  "Draw a pie chart on the current axes.

X — sequence of wedge sizes.
LABELS — list of label strings.
COLORS — list of colors.
AUTOPCT — format string for percentage labels.
STARTANGLE — starting angle in degrees.
COUNTERCLOCK — if T, counter-clockwise wedges.

Returns (values patches texts autotexts)."
  (mpl.containers:pie (gca) x
                       :labels labels :colors colors :autopct autopct
                       :startangle startangle :counterclock counterclock
                       :wedgeprops wedgeprops :textprops textprops
                       :zorder zorder))

(defun errorbar (xdata ydata &key (yerr nil) (xerr nil) (fmt nil)
                                   (ecolor nil) (elinewidth 1.0)
                                   (capsize 3.0) (color nil)
                                   (linewidth 1.5) (marker :none)
                                   (label "") (zorder 2))
  "Plot with error bars on the current axes.

Returns (values line error-lines caps)."
  (mpl.containers:errorbar (gca) xdata ydata
                            :yerr yerr :xerr xerr :fmt fmt
                            :ecolor ecolor :elinewidth elinewidth
                            :capsize capsize :color color
                            :linewidth linewidth :marker marker
                            :label label :zorder zorder))

(defun stem (xdata ydata &key (linefmt nil) (markerfmt nil) (basefmt nil)
                               (bottom 0.0) (label "") (zorder 2))
  "Create a stem plot on the current axes.

Returns (values markerline stemlines baseline)."
  (mpl.containers:stem (gca) xdata ydata
                        :linefmt linefmt :markerfmt markerfmt :basefmt basefmt
                        :bottom bottom :label label :zorder zorder))

(defun step-plot (xdata ydata &key (where :pre) (color nil) (linewidth 1.5)
                                    (linestyle :solid) (label "") (zorder 2))
  "Create a step plot on the current axes.
Named step-plot to avoid conflict with CL:STEP.

Returns the created Line2D."
  (mpl.containers:axes-step (gca) xdata ydata
                             :where where :color color :linewidth linewidth
                             :linestyle linestyle :label label :zorder zorder))

(defun stackplot (xdata ydatas &key (labels nil) (colors nil) (baseline :zero)
                                     (zorder 1))
  "Draw a stacked area plot on the current axes.

XDATA — sequence of x coordinates.
YDATAS — list of y-data sequences.
LABELS — list of labels.
COLORS — list of colors.
BASELINE — :zero.
ZORDER — drawing order.

Returns a list of Polygon patches."
  (mpl.containers:stackplot (gca) xdata ydatas
                             :labels labels :colors colors
                             :baseline baseline :zorder zorder))

(defun barh (y width &key (height 0.8) (left 0) (color nil)
                           (edgecolor "black") (linewidth 0.5)
                           (label "") (zorder 1) (align :center))
  "Make a horizontal bar plot on the current axes.

Returns a list of Rectangle patches."
  (mpl.containers:barh (gca) y width
                        :height height :left left :color color
                        :edgecolor edgecolor :linewidth linewidth
                        :label label :zorder zorder :align align))

(defun boxplot (data &key (labels nil) (vert t) (widths 0.5)
                          (positions nil) (color nil) (linewidth 1.0)
                          (zorder 2))
  "Draw box-and-whisker plot on the current axes.

DATA — list of datasets or single dataset."
  (mpl.containers:boxplot (gca) data
                           :labels labels :vert vert :widths widths
                           :positions positions :color color
                           :linewidth linewidth :zorder zorder))

(defun fill-between (xdata y1data y2data &key (color nil) (alpha nil)
                                               (label "") (zorder 1))
  "Fill area between two curves on the current axes.

Returns the created Polygon."
  (mpl.containers:fill-between (gca) xdata y1data y2data
                                :color color :alpha alpha
                                :label label :zorder zorder))

;;; ============================================================
;;; Axes configuration wrappers
;;; ============================================================

(defun xlabel (text &key (fontsize nil))
  "Set the X-axis label on the current axes.

TEXT — label string.
FONTSIZE — font size in points."
  (let ((ax (gca)))
    (mpl.containers:axis-set-label-text
     (mpl.containers:axes-base-xaxis ax) text :fontsize fontsize)))

(defun ylabel (text &key (fontsize nil))
  "Set the Y-axis label on the current axes.

TEXT — label string.
FONTSIZE — font size in points."
  (let ((ax (gca)))
    (mpl.containers:axis-set-label-text
     (mpl.containers:axes-base-yaxis ax) text :fontsize fontsize)))

(defun title (text &key (fontsize nil) (color nil) (loc :center))
  "Set the title on the current axes.

TEXT — title string.
FONTSIZE — font size in points.
COLOR — text color.
LOC — position: :center, :left, :right."
  (declare (ignore loc color))
  (let* ((ax (gca))
         ;; Fontsize in points (text-artist draw handles pt→px conversion)
         (fontsize-pts (or fontsize 12.0))
         (fig (mpl.containers:axes-base-figure ax))
         (dpi (if fig (mpl.containers:figure-dpi fig) 100))
         ;; Title pad: matplotlib axes.titlepad = 6.0 points + 1px adjustment for font baseline
         (title-pad-px (+ (* 6.0 (/ dpi 72.0)) 1.0))
         ;; axes height in pixels
         (pos (mpl.containers:axes-base-position ax))
         (axes-h-px (* (fourth pos)
                       (if fig
                           (float (mpl.containers:figure-height-px fig) 1.0d0)
                           500.0d0)))
         ;; y in axes coords: 1.0 + pad_px / axes_h_px
         (y-title (+ 1.0d0 (if (> axes-h-px 0.0d0) (/ title-pad-px axes-h-px) 0.02d0)))
         (txt (make-instance 'mpl.rendering:text-artist
                              :x 0.5d0 :y y-title
                              :text text
                              :fontsize fontsize-pts
                              :horizontalalignment :center
                               :verticalalignment :baseline
                              :zorder 3)))
    ;; Set transform to transAxes (title is in axes coordinates)
    (setf (mpl.rendering:artist-transform txt)
          (mpl.containers:axes-base-trans-axes ax))
    ;; Add to axes texts
    (push txt (mpl.containers:axes-base-texts ax))
    (setf (mpl.rendering:artist-stale ax) t)
    txt))

(defun xlim (&optional xmin xmax)
  "Get or set the X-axis limits on the current axes.

If called with no arguments, returns (values xmin xmax).
If called with arguments, sets the limits."
  (let ((ax (gca)))
    (if (and (null xmin) (null xmax))
        (mpl.containers:axes-get-xlim ax)
        (mpl.containers:axes-set-xlim ax :min xmin :max xmax))))

(defun ylim (&optional ymin ymax)
  "Get or set the Y-axis limits on the current axes.

If called with no arguments, returns (values ymin ymax).
If called with arguments, sets the limits."
  (let ((ax (gca)))
    (if (and (null ymin) (null ymax))
        (mpl.containers:axes-get-ylim ax)
        (mpl.containers:axes-set-ylim ax :min ymin :max ymax))))

(defun grid (&key (visible t) (which :major) (axis :both)
                   (color nil) (linewidth nil) (linestyle nil) (alpha nil))
  "Toggle grid lines on the current axes.

VISIBLE — T to show grid, NIL to hide.
WHICH — :major, :minor, or :both.
AXIS — :both, :x, or :y.
COLOR — grid line color.
LINEWIDTH — grid line width.
LINESTYLE — grid line style.
ALPHA — grid line transparency."
  (mpl.containers:axes-grid-toggle (gca) :visible visible :which which :axis axis
                                   :color color :linewidth linewidth
                                   :linestyle linestyle :alpha alpha))

(defun legend (&key handles labels (loc :best) (fontsize 10.0)
                    (frameon t) (facecolor "white") (edgecolor "#cccccc")
                    (framealpha 0.8) (title-text "") (ncol 1))
  "Create a legend on the current axes.

If HANDLES/LABELS not provided, auto-extracts from labeled artists.
LOC — position keyword (e.g., :best, :upper-right).
FONTSIZE — legend font size.
FRAMEON — draw frame.
TITLE-TEXT — legend title."
  (mpl.containers:axes-legend (gca)
                              :handles handles :labels labels :loc loc
                              :fontsize fontsize :frameon frameon
                              :facecolor facecolor :edgecolor edgecolor
                              :framealpha framealpha :title title-text
                              :ncol ncol))

(defun colorbar (mappable &key (orientation :vertical) (label "")
                               ticks format (n-levels 256))
  "Add a colorbar for MAPPABLE to the current figure.

MAPPABLE — a scalar-mappable (e.g., from imshow).
ORIENTATION — :vertical or :horizontal.
LABEL — colorbar label.
TICKS — tick locations.
FORMAT — tick format string.
N-LEVELS — number of color levels."
  (mpl.containers:make-colorbar (gca) mappable
                                :orientation orientation :label label
                                :ticks ticks :format format
                                :n-levels n-levels))

(defun annotate (text xy &key (xytext nil) (xycoords :data) (textcoords nil)
                              (arrowprops nil) (bbox nil) (fontsize 12.0)
                              (color "black") (horizontalalignment :left)
                              (verticalalignment :baseline) (zorder 3))
  "Annotate a point on the current axes with text and optional arrow.

TEXT — annotation text.
XY — target point (x y).
XYTEXT — text position (defaults to XY).
ARROWPROPS — plist of arrow properties.

Returns the created Annotation."
  (mpl.containers:annotate (gca) text xy
                            :xytext xytext :xycoords xycoords
                            :textcoords textcoords :arrowprops arrowprops
                            :bbox bbox :fontsize fontsize :color color
                            :horizontalalignment horizontalalignment
                            :verticalalignment verticalalignment
                            :zorder zorder))

(defun text (x y s &key (fontsize 12.0) (color "black") (alpha nil)
                        (ha :left) (va :baseline) (rotation 0.0)
                        (zorder 3))
  "Place text S at position (X, Y) in data coordinates on the current axes.

HA — horizontal alignment: :left, :center, :right.
VA — vertical alignment: :top, :center, :bottom, :baseline.
ROTATION — text rotation in degrees.

Returns the created text-artist."
  (mpl.containers:text (gca) x y s
                        :fontsize fontsize :color color :alpha alpha
                        :ha ha :va va :rotation rotation :zorder zorder))

;;; ============================================================
;;; Figure-level title and axis labels
;;; ============================================================

(defun suptitle (text &key (fontsize 12.0) (color "black") (alpha nil))
  "Set the figure super-title — centered text above all subplots."
  (mpl.containers:suptitle (gcf) text :fontsize fontsize :color color :alpha alpha))

(defun supxlabel (text &key (fontsize 12.0) (color "black") (alpha nil))
  "Set the figure super-xlabel — centered text at the bottom of the figure."
  (mpl.containers:supxlabel (gcf) text :fontsize fontsize :color color :alpha alpha))

(defun supylabel (text &key (fontsize 12.0) (color "black") (alpha nil))
  "Set the figure super-ylabel — rotated text at the left of the figure."
  (mpl.containers:supylabel (gcf) text :fontsize fontsize :color color :alpha alpha))

;;; ============================================================
;;; Axis inversion
;;; ============================================================

(defun invert-xaxis ()
  "Invert the x-axis of the current axes."
  (mpl.containers:axes-invert-xaxis (gca)))

(defun invert-yaxis ()
  "Invert the y-axis of the current axes."
  (mpl.containers:axes-invert-yaxis (gca)))

;;; ============================================================
;;; Reference line wrappers
;;; ============================================================

(defun axhline (y &key (xmin 0.0) (xmax 1.0) (color "C0") (linewidth 1.5)
                       (linestyle :solid) (alpha nil) (label "") (zorder 2))
  "Draw a horizontal line at Y across the current axes.
XMIN, XMAX — fraction of axes width (0=left, 1=right).
Returns the created Line2D."
  (mpl.containers:axhline (gca) y
                            :xmin xmin :xmax xmax :color color
                            :linewidth linewidth :linestyle linestyle
                            :alpha alpha :label label :zorder zorder))

(defun axvline (x &key (ymin 0.0) (ymax 1.0) (color "C0") (linewidth 1.5)
                       (linestyle :solid) (alpha nil) (label "") (zorder 2))
  "Draw a vertical line at X across the current axes.
YMIN, YMAX — fraction of axes height (0=bottom, 1=top).
Returns the created Line2D."
  (mpl.containers:axvline (gca) x
                            :ymin ymin :ymax ymax :color color
                            :linewidth linewidth :linestyle linestyle
                            :alpha alpha :label label :zorder zorder))

(defun hlines (y xmin xmax &key (colors "C0") (linestyles :solid)
                                 (linewidth 1.5) (alpha nil) (label "") (zorder 2))
  "Draw horizontal lines at each Y from XMIN to XMAX (data coordinates).
Returns list of Line2D objects."
  (mpl.containers:hlines (gca) y xmin xmax
                           :colors colors :linestyles linestyles
                           :linewidth linewidth :alpha alpha
                           :label label :zorder zorder))

(defun vlines (x ymin ymax &key (colors "C0") (linestyles :solid)
                                 (linewidth 1.5) (alpha nil) (label "") (zorder 2))
  "Draw vertical lines at each X from YMIN to YMAX (data coordinates).
Returns list of Line2D objects."
  (mpl.containers:vlines (gca) x ymin ymax
                           :colors colors :linestyles linestyles
                           :linewidth linewidth :alpha alpha
                           :label label :zorder zorder))

;;; ============================================================
;;; Output functions
;;; ============================================================

(defun savefig (filename &key (dpi nil) (format nil) (facecolor nil)
                              (edgecolor nil) (transparent nil))
  "Save the current figure to FILENAME.

Detects format from file extension unless FORMAT specified.
Creates canvas, renders figure, and saves.

FILENAME — output file path.
DPI — resolution override.
FORMAT — output format keyword (:png, etc.).
FACECOLOR — override figure facecolor.
EDGECOLOR — override figure edgecolor.
TRANSPARENT — if T, use transparent background."
  (mpl.containers:savefig (gcf) filename
                           :dpi dpi :format format
                           :facecolor facecolor :edgecolor edgecolor
                           :transparent transparent))

(defun show ()
  "Display the current figure (no-op for non-interactive backend).
In a non-interactive backend, this does nothing.
For interactive use, consider using savefig instead."
  (format t "~&; pyplot: Non-interactive backend — use (savefig \"file.png\") to save.~%")
  (values))
