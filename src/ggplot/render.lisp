;;;; render.lisp — ggrender: ggbuilt -> cl-matplotlib figure

(in-package #:ggplot)

(defun default-axis-label (plot aesthetic)
  "Fallback axis title: the literal column reference from the mapping."
  (let* ((mapping (plot-mapping plot))
         (ref (and mapping (aes-ref mapping aesthetic))))
    (typecase ref
      (null nil)
      (string ref)
      (symbol (string-downcase (symbol-name ref)))
      (t nil))))

(defun %stat-default-label (built aesthetic)
  "When a stat supplies AESTHETIC (e.g. stat-count's y), plotnine titles
the axis with the computed column's name (\"count\")."
  (loop for (layer . nil) in (ggbuilt-layer-tables built)
        for default = (getf (stat-default-aes (layer-stat layer)) aesthetic)
        when (after-stat-ref-p default)
          return (string-downcase
                  (symbol-name (after-stat-ref-name default)))))

(defun %plot-label (built key)
  "Label for KEY (:x :y :title ...): explicit labs (already swapped for
coord-flip by ggbuild), else mapping fallback, else stat fallback."
  (or (cdr (assoc key (ggbuilt-labs built)))
      (let* ((flipped (typep (plot-coord (ggbuilt-plot built)) 'coord-flip-obj))
             (aesthetic (case key
                          (:x (if flipped :y :x))
                          (:y (if flipped :x :y))
                          (t nil))))
        (when aesthetic
          (or (default-axis-label (ggbuilt-plot built) aesthetic)
              (%stat-default-label built aesthetic))))))

(defun %midpoints (breaks)
  (loop for (a b) on breaks
        while b
        collect (/ (+ a b) 2.0d0)))

(defun %apply-panel-theme (theme axes panel)
  "Stage-2 theme application: per-axes settings rc can't express."
  (let ((major (theme-element theme :panel-grid-major))
        (minor (theme-element theme :panel-grid-minor)))
    (when (element-line-p major)
      (cl-matplotlib.containers:axes-grid-toggle
       axes
       :visible t
       :which :major
       :axis :both
       :color (or (element-line-color major) "white")
       :linewidth (or (element-line-linewidth major) 1.0)
       :linestyle :solid
       :alpha 1.0))
    ;; plotnine's minor gridlines sit at the midpoints between major breaks
    (when (element-line-p minor)
      (let ((x-minor (%midpoints (getf panel :x-breaks)))
            (y-minor (%midpoints (getf panel :y-breaks))))
        (when x-minor
          (cl-matplotlib.containers:axis-set-minor-locator
           (cl-matplotlib.containers:axes-base-xaxis axes)
           (make-instance 'cl-matplotlib.containers:fixed-locator :locs x-minor)))
        (when y-minor
          (cl-matplotlib.containers:axis-set-minor-locator
           (cl-matplotlib.containers:axes-base-yaxis axes)
           (make-instance 'cl-matplotlib.containers:fixed-locator :locs y-minor)))
        (cl-matplotlib.containers:axes-grid-toggle
         axes
         :visible t
         :which :minor
         :axis :both
         :color (or (element-line-color minor) "white")
         :linewidth (or (element-line-linewidth minor) 0.5)
         :linestyle :solid
         :alpha 1.0)))))

(defun %axes-fraction-text (axes text x-frac y-frac &key (rotation 0.0d0)
                                                         (fontsize 11.0d0)
                                                         (color "black")
                                                         (zorder 3))
  "Attach TEXT to AXES at axes-fraction coordinates (values outside [0,1]
place it in the margins). Drawn through transAxes, so it tracks the panel."
  (let ((artist (make-instance 'cl-matplotlib.rendering:text-artist
                               :x (float x-frac 1.0d0)
                               :y (float y-frac 1.0d0)
                               :text text
                               :fontsize (float fontsize 1.0d0)
                               :color color
                               :horizontalalignment :center
                               :verticalalignment :center
                               :rotation (float rotation 1.0d0)
                               :zorder zorder)))
    (setf (cl-matplotlib.rendering:artist-transform artist)
          (cl-matplotlib.containers:axes-base-trans-axes axes))
    (push artist (cl-matplotlib.containers:axes-base-texts axes))
    artist))

;; Axis-title anchor positions, measured from plotnine renders at dpi 100:
;; y title centered 14px from the figure's left edge, x title centered 10px
;; up from the bottom edge; both centered on the panel in the other axis.
(defparameter *y-title-x-px* 14.0d0)
(defparameter *x-title-y-px* 10.0d0)

(defun %add-axis-titles (built theme fig axes width-px height-px dpi)
  (let* ((margins (%compute-margins built theme width-px height-px dpi))
         (left-px (* (getf margins :left) width-px))
         (right-px (* (getf margins :right) width-px))
         (top-px (* (getf margins :top) height-px))
         (bottom-px (* (getf margins :bottom) height-px))
         (panel-w (- right-px left-px))
         (panel-h (- top-px bottom-px))
         (scale (/ dpi 100.0d0))
         (title-el (theme-element theme :axis-title))
         (fontsize (or (and (element-text-p title-el)
                            (element-text-size title-el))
                       11.0d0))
         (xlab (%plot-label built :x))
         (ylab (%plot-label built :y))
         (title (%plot-label built :title)))
    (when ylab
      (%axes-fraction-text axes ylab
                           (/ (- (* *y-title-x-px* scale) left-px) panel-w)
                           0.5d0
                           :rotation 90.0d0 :fontsize fontsize))
    (when xlab
      (%axes-fraction-text axes xlab
                           0.5d0
                           (/ (- (* *x-title-y-px* scale) bottom-px) panel-h)
                           :fontsize fontsize))
    (when title
      (cl-matplotlib.containers:suptitle fig title))))

(defgeneric ggrender (built &key figure width height dpi)
  (:documentation "Render a ggbuilt (from ggbuild) into a cl-matplotlib
figure and return it. The figure is created inside the theme's rc context
so theme-driven figure defaults apply; pass :figure only to draw into an
existing one."))

;;; Panel layout constants, measured in pixels from plotnine's default
;;; single-panel renders at dpi 100 (ggblank / gg-line-basic references):
;;; the panel's left edge sits a fixed 39px (y-title column + tick + pads)
;;; plus the widest y tick label from the panel edge; the other three
;;; margins are constant when an x title is present.
;; 37.7 rather than the raw measured 39: the base is calibrated so that
;; base + THIS BACKEND's tick-label widths reproduces plotnine's panel edge
;; (its font metrics run ~1.5px narrower than ours at 8.8pt).
(defparameter *panel-left-base-px* 37.7d0)
(defparameter *panel-right-px* 6.0d0)
(defparameter *panel-top-px* 6.0d0)
(defparameter *panel-bottom-px* 46.0d0)

(defun %text-width-px (text fontsize-pt dpi)
  "Width of TEXT in pixels at FONTSIZE-PT, using the backend's font metrics."
  (let ((loader (cl-matplotlib.rendering:load-font "sans-serif")))
    (* (cl-matplotlib.primitives:bbox-width
        (cl-matplotlib.rendering:get-text-extents text loader
                                                  (float fontsize-pt 1.0d0)))
       (/ dpi 72.0d0))))

;; Legend box reservation, measured from plotnine right-side legends:
;; fixed chrome (outer margin + key + key-text gap) plus the widest entry
;; label at the legend text size.
(defparameter *legend-base-px* 42.0d0)

(defun %gradient-scale (built)
  "The first continuous color/fill scale needing a colorbar guide, or NIL."
  (loop for (aes . scale) in (ggbuilt-scales built)
        when (and (member aes '(:color :fill))
                  (typep scale 'scale-gradient-obj)
                  (not (eq (scale-guide scale) :none)))
          return scale))

(defun %legend-width-px (built theme dpi)
  "Horizontal space to reserve right of the panel for legends, in px."
  (when (%gradient-scale built)
    ;; colorbar guide: 19px gap + 20px bar + labels + margin (measured
    ;; from plotnine tile references: panel right at 553/640)
    (return-from %legend-width-px (* 81.0d0 (/ dpi 100.0d0))))
  (let ((legends (ggbuilt-legends built)))
    (if (null legends)
        0.0d0
        (let* ((axis-text (theme-element theme :axis-text))
               (label-size (or (and (element-text-p axis-text)
                                    (element-text-size axis-text))
                               8.8d0))
               (title-size 11.0d0)
               (max-w 0.0d0))
          (dolist (spec legends)
            (setf max-w (max max-w
                             (%text-width-px (getf spec :title) title-size dpi)))
            (dolist (label (getf spec :labels))
              (setf max-w (max max-w (%text-width-px label label-size dpi)))))
          (+ (* *legend-base-px* (/ dpi 100.0d0)) max-w)))))

(defun %compute-margins (built theme width-px height-px dpi)
  "Panel margins in figure fractions, adapting the left margin to the
widest y tick label and the right margin to any legend, like plotnine's
layout engine does."
  (let* ((panel (first (ggbuilt-panels built)))
         (axis-text (theme-element theme :axis-text))
         (tick-size (or (and (element-text-p axis-text)
                             (element-text-size axis-text))
                        8.8d0))
         (max-ytick-w (reduce #'max (getf panel :y-labels)
                              :key (lambda (l) (%text-width-px l tick-size dpi))
                              :initial-value 0.0d0))
         (scale (/ dpi 100.0d0)))   ; constants measured at dpi 100
    ;; Snap the panel edges to whole pixels: a fractional edge antialiases
    ;; into two columns and costs visible SSIM against plotnine's crisp box.
    (list :left (/ (fround (+ (* *panel-left-base-px* scale) max-ytick-w)) width-px)
          :right (- 1.0d0 (/ (fround (+ (* *panel-right-px* scale)
                                        (%legend-width-px built theme dpi)))
                             width-px))
          :top (- 1.0d0 (/ (fround (* *panel-top-px* scale)) height-px))
          :bottom (/ (fround (* *panel-bottom-px* scale)) height-px))))

(defun %panel-facecolor (theme)
  (let ((panel (theme-element theme :panel-background)))
    (typecase panel
      (element-rect (or (element-rect-fill panel) "white"))
      (t "white"))))

(defun %hide-spines-p (theme)
  (element-blank-p (theme-element theme :axis-line)))

(defun %draw-colorbar (built theme gscale axes margins width-px height-px dpi)
  "Vertical colorbar right of the panel, drawn as a stack of gradient
rectangles in the anchor panel's axes-fraction coordinates. Geometry
measured from plotnine: 19px gap, 20px bar, 161px tall, centered on the
panel, value labels right of the bar, title above."
  (declare (ignore theme))
  (let* ((scale (/ dpi 100.0d0))
         (left-px (* (getf margins :left) width-px))
         (right-px (* (getf margins :right) width-px))
         (bottom-px (* (getf margins :bottom) height-px))
         (top-px (* (getf margins :top) height-px))
         (panel-w (- right-px left-px))
         (panel-h (- top-px bottom-px))
         (bar-x0-px (+ right-px (* 19.0d0 scale)))
         (bar-w-px (* 20.0d0 scale))
         (bar-h-px (* 161.0d0 scale))
         (bar-y0-px (- (/ (+ bottom-px top-px) 2.0d0) (/ bar-h-px 2.0d0)))
         ;; axes-fraction coordinates of the bar
         (fx0 (/ (- bar-x0-px left-px) panel-w))
         (fw (/ bar-w-px panel-w))
         (fy0 (/ (- bar-y0-px bottom-px) panel-h))
         (fh (/ bar-h-px panel-h))
         (n-steps 64)
         (limits (scale-limits gscale))
         (lo (first limits))
         (hi (second limits))
         (trans-axes (cl-matplotlib.containers:axes-base-trans-axes axes)))
    ;; gradient bar as a stack of rectangles
    (dotimes (i n-steps)
      (let* ((v (+ lo (* (/ (+ i 0.5d0) n-steps) (- hi lo))))
             (color (svref (scale-map gscale (vector v)) 0))
             (rect (make-instance 'cl-matplotlib.rendering:rectangle
                                  :x0 fx0
                                  :y0 (+ fy0 (* fh (/ (float i 1.0d0) n-steps)))
                                  :width fw
                                  :height (* fh (/ 1.05d0 n-steps))
                                  :facecolor color
                                  :edgecolor nil
                                  :linewidth 0.0d0
                                  :zorder 4)))
        (setf (cl-matplotlib.rendering:artist-transform rect) trans-axes)
        (cl-matplotlib.containers:axes-add-patch axes rect)))
    ;; tick labels right of the bar
    (let ((breaks (remove-if-not (lambda (b) (<= lo b hi))
                                 (extended-breaks lo hi 5))))
      (loop for b in breaks
            for label in (%format-break-set breaks)
            do (%axes-fraction-text
                axes label
                (+ fx0 fw (/ (* 10.0d0 scale) panel-w))
                (+ fy0 (* fh (/ (- b lo) (max (- hi lo) 1.0d-12))))
                :fontsize 8.8d0 :color "#4D4D4D" :zorder 5)))
    ;; title above the bar
    (let ((title (or (scale-name gscale)
                     (let* ((plot (ggbuilt-plot built))
                            (mapping (plot-mapping plot))
                            (ref (and mapping
                                      (or (aes-ref mapping :fill)
                                          (aes-ref mapping :color)))))
                       (typecase ref
                         (string ref)
                         (symbol (string-downcase (symbol-name ref)))
                         (t ""))))))
      (when (plusp (length title))
        (%axes-fraction-text axes title
                             (+ fx0 (/ fw 2.0d0))
                             (+ fy0 fh (/ (* 14.0d0 scale) panel-h))
                             :fontsize 11.0d0 :zorder 5)))))

;; Facet cell geometry, measured from plotnine facet_wrap renders at
;; dpi 100: strips are 19px tall above each panel, panels separated by 7px.
(defparameter *strip-height-px* 19.0d0)
(defparameter *panel-spacing-px* 7.0d0)

(defun %gtable-panel-subset (table panel-index)
  "Rows of TABLE belonging to PANEL-INDEX (all rows when no :panel column)."
  (let ((panel-col (gtable-column table :panel)))
    (if (null panel-col)
        table
        (gtable-select table
                       (loop for i from 0 below (gtable-nrows table)
                             when (eql (svref panel-col i) panel-index)
                               collect i)))))

(defun %draw-strip (axes label theme strip-frac)
  "Facet strip: a #D9D9D9 band with a centered label, sitting directly
above the panel (axes-fraction y in [1, 1+strip-frac])."
  (let* ((strip-bg (theme-element theme :strip-background))
         (fill (if (element-rect-p strip-bg)
                   (or (element-rect-fill strip-bg) "#D9D9D9")
                   "#D9D9D9"))
         (rect (make-instance 'cl-matplotlib.rendering:rectangle
                              :x0 0.0d0 :y0 1.0d0
                              :width 1.0d0 :height strip-frac
                              :facecolor fill
                              :edgecolor nil
                              :linewidth 0.0d0
                              :zorder 4)))
    (setf (cl-matplotlib.rendering:artist-transform rect)
          (cl-matplotlib.containers:axes-base-trans-axes axes))
    (cl-matplotlib.containers:axes-add-patch axes rect)
    (%axes-fraction-text axes label 0.5d0 (+ 1.0d0 (/ strip-frac 2.0d0))
                         :fontsize 8.8d0 :color "#1A1A1A" :zorder 5)))

(defmethod ggrender ((built ggbuilt) &key figure (width 6.4d0) (height 4.8d0) (dpi 100))
  (let* ((theme (ggbuilt-theme built))
         (nrow (or (ggbuilt-nrow built) 1))
         (ncol (or (ggbuilt-ncol built) 1))
         (multi (> (length (ggbuilt-panels built)) 1)))
    (call-with-rc-alist
     (theme-rc-alist theme)
     (lambda ()
       (let* ((width-px (* width dpi))
              (height-px (* height dpi))
              (scale (/ dpi 100.0d0))
              (fig (or figure
                       (cl-matplotlib.containers:make-figure
                        :figsize (list (float width 1.0d0) (float height 1.0d0))
                        :dpi dpi)))
              (margins (%compute-margins built theme width-px height-px dpi))
              (strip-px (if multi (* *strip-height-px* scale) 0.0d0))
              (spacing-px (if multi (* *panel-spacing-px* scale) 0.0d0))
              (area-w (* (- (getf margins :right) (getf margins :left)) width-px))
              (area-h (* (- (getf margins :top) (getf margins :bottom)) height-px))
              (cell-w (/ (- area-w (* (1- ncol) spacing-px)) ncol))
              (cell-h (/ (- area-h (* (1- nrow) spacing-px)) nrow))
              (panel-h (- cell-h strip-px))
              (axes-list '()))
         (apply #'cl-matplotlib.containers:figure-subplots-adjust
                fig (append margins
                            (when multi
                              (list :wspace (/ spacing-px cell-w)
                                    :hspace (/ spacing-px cell-h)))))
         ;; One axes per panel; the top strip-px of each grid cell is
         ;; reserved for the strip, so the axes box is shrunk after
         ;; add-subplot computes the cell.
         (dolist (panel (ggbuilt-panels built))
           (let* ((idx (getf panel :index))
                  (row (getf panel :row))
                  (col (getf panel :col))
                  (axes (cl-matplotlib.containers:add-subplot
                         fig nrow ncol (1+ idx)
                         :facecolor (%panel-facecolor theme))))
             (when multi
               (let ((pos (cl-matplotlib.containers:axes-base-position axes)))
                 (setf (cl-matplotlib.containers:axes-base-position axes)
                       (list (first pos) (second pos) (third pos)
                             (- (fourth pos) (/ strip-px height-px))))))
             (push (cons idx axes) axes-list)
             (when (%hide-spines-p theme)
               ;; the spines container is keyed by STRINGS
               (let ((spines (cl-matplotlib.containers:axes-base-spines axes)))
                 (when spines
                   (dolist (side (list "left" "right" "top" "bottom"))
                     (let ((spine (cl-matplotlib.containers:spines-ref spines side)))
                       (when spine
                         (cl-matplotlib.containers:spine-set-visible spine nil)))))))
             ;; Ranges and ticks (fixed scales: identical on every panel)
             (destructuring-bind (x0 x1) (getf panel :x-range)
               (cl-matplotlib.containers:axes-set-xlim axes :min x0 :max x1))
             (destructuring-bind (y0 y1) (getf panel :y-range)
               (cl-matplotlib.containers:axes-set-ylim axes :min y0 :max y1))
             (cl-matplotlib.containers:axes-set-xticks
              axes (getf panel :x-breaks) :labels (getf panel :x-labels))
             (cl-matplotlib.containers:axes-set-yticks
              axes (getf panel :y-breaks) :labels (getf panel :y-labels))
             ;; Shared-axis tick label suppression (plotnine fixed scales)
             (when multi
               (unless (= row (1- nrow))
                 (setf (cl-matplotlib.containers:axis-tick-labels-visible-p
                        (cl-matplotlib.containers:axes-base-xaxis axes))
                       nil))
               (unless (zerop col)
                 (setf (cl-matplotlib.containers:axis-tick-labels-visible-p
                        (cl-matplotlib.containers:axes-base-yaxis axes))
                       nil)))
             ;; Theme: tick label size/color; plotnine tick geometry
             ;; (2.75px major marks, NO minor marks - only minor gridlines)
             (let ((axis-text (theme-element theme :axis-text)))
               (dolist (axis (list (cl-matplotlib.containers:axes-base-xaxis axes)
                                   (cl-matplotlib.containers:axes-base-yaxis axes)))
                 (when axis
                   (when (element-text-p axis-text)
                     (cl-matplotlib.containers:axis-set-tick-params
                      axis
                      :labelsize (element-text-size axis-text)
                      :labelcolor (or (element-text-color axis-text) "black")
                      :which :both))
                   (cl-matplotlib.containers:axis-set-tick-params
                    axis :size 2.75 :which :major)
                   (cl-matplotlib.containers:axis-set-tick-params
                    axis :size 0.0 :which :minor))))
             (%apply-panel-theme theme axes panel)
             ;; Layers, filtered to this panel
             (loop for (layer . table) in (ggbuilt-layer-tables built)
                   for subset = (%gtable-panel-subset table idx)
                   when (plusp (gtable-nrows subset))
                     do (geom-draw-panel (layer-geom layer) subset panel axes))
             ;; Strip
             (when (and multi (getf panel :label))
               (%draw-strip axes (getf panel :label) theme
                            (/ strip-px panel-h)))))
         (setf axes-list (nreverse axes-list))
         ;; Colorbar guide for continuous color/fill
         (let ((gscale (%gradient-scale built)))
           (when gscale
             (%draw-colorbar built theme gscale
                             (cdr (assoc (1- ncol) axes-list))
                             margins (* width dpi) (* height dpi) dpi)))
         ;; Legend on the first panel of the last column (anchored outside)
         (let ((spec (first (ggbuilt-legends built))))
           (when spec
             (when (rest (ggbuilt-legends built))
               (warn "Multiple legends requested; only the ~S guide is drawn"
                     (getf spec :aesthetic)))
             (let ((handles (mapcar (lambda (v)
                                      (geom-legend-artist (getf spec :geom)
                                                          (list :value v)))
                                    (getf spec :values)))
                   (anchor-axes (cdr (assoc (1- ncol) axes-list))))
               (when (and anchor-axes (every #'identity handles))
                 (cl-matplotlib.containers:axes-legend
                  anchor-axes
                  :handles handles
                  :labels (getf spec :labels)
                  :title (getf spec :title)
                  :loc :center-left
                  :bbox-to-anchor (list 1.02d0
                                        (if multi
                                            ;; center on the whole grid
                                            (- 0.5d0 (* (/ area-h panel-h) 0.0d0))
                                            0.5d0))
                  :frameon nil
                  :fontsize 8.8)))))
         ;; Axis titles: centered across the whole panel grid, attached to
         ;; the bottom-left panel
         (let ((anchor (cdr (assoc (* (1- nrow) ncol) axes-list))))
           (when anchor
             (%add-grid-axis-titles built theme fig anchor margins
                                    width-px height-px dpi
                                    :panel-w cell-w :panel-h panel-h
                                    :nrow nrow :ncol ncol)))
         fig)))))

(defun %add-grid-axis-titles (built theme fig anchor margins width-px height-px dpi
                              &key panel-w panel-h nrow ncol)
  "Axis titles centered over the full panel grid, in the anchor panel\'s
axes-fraction coordinates."
  (declare (ignore nrow ncol))
  (let* ((left-px (* (getf margins :left) width-px))
         (right-px (* (getf margins :right) width-px))
         (bottom-px (* (getf margins :bottom) height-px))
         (top-px (* (getf margins :top) height-px))
         (grid-center-x (/ (+ left-px right-px) 2.0d0))
         (grid-center-y (/ (+ bottom-px top-px) 2.0d0))
         (scale (/ dpi 100.0d0))
         (title-el (theme-element theme :axis-title))
         (fontsize (or (and (element-text-p title-el)
                            (element-text-size title-el))
                       11.0d0))
         (xlab (%plot-label built :x))
         (ylab (%plot-label built :y))
         (title (%plot-label built :title)))
    ;; anchor is the bottom-left panel; its axes box starts at the outer
    ;; left/bottom margins
    (when ylab
      (%axes-fraction-text anchor ylab
                           (/ (- (* *y-title-x-px* scale) left-px) panel-w)
                           (/ (- grid-center-y bottom-px) panel-h)
                           :rotation 90.0d0 :fontsize fontsize))
    (when xlab
      (%axes-fraction-text anchor xlab
                           (/ (- grid-center-x left-px) panel-w)
                           (/ (- (* *x-title-y-px* scale) bottom-px) panel-h)
                           :fontsize fontsize))
    (when title
      (cl-matplotlib.containers:suptitle fig title))))

(defun ggdraw (plot &key figure (width 6.4d0) (height 4.8d0) (dpi 100))
  "Build and render PLOT; returns the cl-matplotlib figure."
  (ggrender (ggbuild plot) :figure figure :width width :height height :dpi dpi))
