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
    ;; minor gridlines: scale-provided positions (midpoints for linear
    ;; scales, 2..9 x 10^k for log scales), midpoint fallback
    (when (element-line-p minor)
      (let ((x-minor (or (getf panel :x-minor)
                         (%midpoints (getf panel :x-breaks))))
            (y-minor (or (getf panel :y-minor)
                         (%midpoints (getf panel :y-breaks)))))
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
                                                         (zorder 3)
                                                         (ha :center)
                                                         (va :center))
  "Attach TEXT to AXES at axes-fraction coordinates (values outside [0,1]
place it in the margins). Drawn through transAxes, so it tracks the panel."
  (let ((artist (make-instance 'cl-matplotlib.rendering:text-artist
                               :x (float x-frac 1.0d0)
                               :y (float y-frac 1.0d0)
                               :text text
                               :fontsize (float fontsize 1.0d0)
                               :color color
                               :horizontalalignment ha
                               :verticalalignment va
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
;; 34.2: calibrated so base + matplotlib-metric tick-label widths
;; (%mpl-text-width-px) reproduces plotnine's panel edge (verified:
;; '10' -> panel left 50, '10.0' -> 61, at dpi 100).
(defparameter *panel-left-base-px* 34.2d0)
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

(defparameter *dejavu-advance-table*
  ;; DejaVu Sans horizontal advances for ASCII 32..126, in 1/8 em units
  ;; (extracted from matplotlib's FT2Font; divide by 8 for em fractions).
  ;; plotnine's layout is driven by these metrics, so margin/legend
  ;; geometry must measure text the same way matplotlib does - our own
  ;; rasterizer's ink extents run ~14% narrower.
  (make-array 95 :element-type 'double-float :initial-contents
   '(2.543d0 3.207d0 3.681d0 6.702d0 5.090d0 7.601d0 6.238d0 2.200d0
     3.121d0 3.122d0 3.999d0 6.704d0 2.542d0 2.887d0 2.542d0 2.695d0
     5.089d0 5.089d0 5.090d0 5.090d0 5.090d0 5.089d0 5.090d0 5.090d0
     5.090d0 5.090d0 2.695d0 2.695d0 6.704d0 6.704d0 6.704d0 4.246d0
     8.000d0 5.473d0 5.488d0 5.586d0 6.160d0 5.055d0 4.601d0 6.199d0
     6.015d0 2.359d0 2.359d0 5.246d0 4.457d0 6.902d0 5.984d0 6.296d0
     4.824d0 6.296d0 5.559d0 5.077d0 4.888d0 5.855d0 5.473d0 7.910d0
     5.480d0 4.887d0 5.480d0 3.121d0 2.695d0 3.122d0 6.703d0 4.000d0
     4.000d0 4.902d0 5.079d0 4.398d0 5.078d0 4.922d0 2.817d0 5.078d0
     5.071d0 2.223d0 2.223d0 4.634d0 2.223d0 7.794d0 5.071d0 4.895d0
     5.079d0 5.078d0 3.289d0 4.168d0 3.137d0 5.071d0 4.734d0 6.543d0
     4.734d0 4.734d0 4.200d0 5.090d0 2.696d0 5.090d0 6.704d0)))

(defun %mpl-text-width-px (text fontsize-pt dpi)
  "Width of TEXT in pixels using matplotlib's DejaVu Sans advance widths
(what plotnine's layout engine sees). Non-ASCII characters fall back to
the average advance."
  (let ((em 0.0d0))
    (loop for ch across text
          for code = (char-code ch)
          do (incf em (/ (if (<= 32 code 126)
                             (aref *dejavu-advance-table* (- code 32))
                             5.0d0)
                         8.0d0)))
    (* em (float fontsize-pt 1.0d0) (/ dpi 72.0d0))))

;; Legend geometry, measured from plotnine 0.15.7 right-side legends at
;; dpi 100 (probe plots with controlled title/label widths):
;;   panel -> key-box gap 21.5px; key boxes 22x22 #F2F2F2 at 24.5px pitch;
;;   labels 5px right of the key at 8.8pt; title (11pt, ~14.5px line box)
;;   above the keys with a 5px gap; 7.5px to the figure edge. The whole
;;   block (title line + keys) is vertically centered on the panel.
(defparameter *legend-gap-px* 21.5d0)
(defparameter *legend-key-px* 22.0d0)
(defparameter *legend-key-pitch-px* 24.5d0)
(defparameter *legend-label-gap-px* 5.0d0)
(defparameter *legend-right-margin-px* 7.5d0)
(defparameter *legend-title-lh-px* 14.5d0)
(defparameter *legend-title-gap-px* 5.0d0)

(defun %gradient-scale (built)
  "The first continuous color/fill scale needing a colorbar guide, or NIL."
  (loop for (aes . scale) in (ggbuilt-scales built)
        when (and (member aes '(:color :fill))
                  (typep scale '(or scale-gradient-obj scale-gradientn-obj))
                  (not (eq (scale-guide scale) :none)))
          return scale))

(defun %legend-width-px (built theme dpi)
  "Horizontal space to reserve right of the panel for legends, in px."
  (when (%gradient-scale built)
    ;; colorbar guide: 19px gap + 20px bar + labels + margin (measured
    ;; from plotnine tile references: panel right at 553/640)
    (return-from %legend-width-px (* 87.0d0 (/ dpi 100.0d0))))
  (let ((legends (ggbuilt-legends built)))
    (if (null legends)
        0.0d0
        (let* ((axis-text (theme-element theme :axis-text))
               (label-size (or (and (element-text-p axis-text)
                                    (element-text-size axis-text))
                               8.8d0))
               (title-size 11.0d0)
               (scale (/ dpi 100.0d0))
               (inner 0.0d0))
          ;; widest of: title, or key box + gap + label, in matplotlib
          ;; advance-width metrics (what the plotnine constants were
          ;; calibrated against)
          (dolist (spec legends)
            (setf inner (max inner
                             (%mpl-text-width-px (getf spec :title)
                                                 title-size dpi)))
            ;; label contribution: key + 3.5px box gap + label advance width
            ;; (probes p1/p3: reserve 62 with 'a', 132 with 'gamma-long')
            (dolist (label (getf spec :labels))
              (setf inner (max inner
                               (+ (* (+ *legend-key-px* 3.5d0) scale)
                                  (%mpl-text-width-px label label-size
                                                      dpi))))))
          (+ (* (+ *legend-gap-px* *legend-right-margin-px*) scale) inner)))))

(defun %compute-margins (built theme width-px height-px dpi)
  "Panel margins in figure fractions, adapting the left margin to the
widest y tick label and the right margin to any legend, like plotnine's
layout engine does."
  (let* ((panel (first (ggbuilt-panels built)))
         (axis-text (theme-element theme :axis-text))
         (tick-size (or (and (element-text-p axis-text)
                             (element-text-size axis-text))
                        8.8d0))
         ;; widest y tick label in the FIRST panel column (free-scale
         ;; labels of inner columns live in the panel spacing instead)
         (max-ytick-w (loop for p in (ggbuilt-panels built)
                            when (zerop (or (getf p :col) 0))
                              maximize
                              (reduce #'max (getf p :y-labels)
                                      :key (lambda (l)
                                             (%mpl-text-width-px l tick-size
                                                                 dpi))
                                      :initial-value 0.0d0)))
         (scale (/ dpi 100.0d0))    ; constants measured at dpi 100
         (left-px (fround (+ (* *panel-left-base-px* scale) max-ytick-w)))
         ;; plotnine widens the right margin when the last x tick label
         ;; would overflow the figure: the label may overhang its break by
         ;; the scale-expansion gap minus ~8px before the margin grows
         ;; (probed with %y / %Y-%m / %Y-%m-%dTT date labels)
         (label-overflow-px
           (let ((x-breaks (getf panel :x-breaks))
                 (x-labels (getf panel :x-labels))
                 (x-range (getf panel :x-range)))
             (if (and x-breaks x-labels x-range)
                 (let* ((x0 (first x-range)) (x1 (second x-range))
                        (f (/ (- (car (last x-breaks)) x0)
                              (max (- x1 x0) 1.0d-12)))
                        (hw (* 0.5d0
                               (%mpl-text-width-px (car (last x-labels))
                                                   tick-size dpi)))
                        (slack (* (- 1.0d0 f)
                                  (- width-px left-px
                                     (* *panel-right-px* scale)))))
                   (max 0.0d0 (+ (- hw slack) (* 4.3d0 scale))))
                 0.0d0)))
         ;; vertical analogue for the top margin: a y break at the very
         ;; top edge pushes the panel down so its label fits (tile refs:
         ;; top margin 13 when the last break sits at fraction 1.0)
         (top-overflow-px
           (let ((y-breaks (getf panel :y-breaks))
                 (y-range (getf panel :y-range)))
             (if (and y-breaks y-range)
                 (let* ((y0 (first y-range)) (y1 (second y-range))
                        (f (/ (- (reduce #'max y-breaks) y0)
                              (max (- y1 y0) 1.0d-12)))
                        (slack (* (- 1.0d0 f)
                                  (- height-px
                                     (* (+ *panel-top-px* *panel-bottom-px*)
                                        scale)))))
                   (max 0.0d0 (- (* 7.0d0 scale) slack)))
                 0.0d0))))
    ;; Snap the panel edges to whole pixels: a fractional edge antialiases
    ;; into two columns and costs visible SSIM against plotnine's crisp box.
    (list :left (/ left-px width-px)
          ;; a legend/colorbar reservation REPLACES the bare right margin
          ;; (plotnine's measured totals already include the figure-edge gap)
          :right (- 1.0d0 (/ (fround (max (+ (* *panel-right-px* scale)
                                             label-overflow-px)
                                          (%legend-width-px built theme dpi)))
                             width-px))
          :top (- 1.0d0 (/ (fround (+ (* *panel-top-px* scale)
                                      top-overflow-px))
                           height-px))
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
measured from plotnine 0.15.7 at dpi 100: 19.5px gap, 34px-wide 161px-tall
bar; title line (14.5px) + 5px gap above the bar, the whole block centered
on the panel; white tick marks inside both bar edges at the breaks; labels
5px right of the bar, vertically centered on their break."
  (declare (ignore theme))
  (let* ((scale (/ dpi 100.0d0))
         (left-px (* (getf margins :left) width-px))
         (right-px (* (getf margins :right) width-px))
         (bottom-px (* (getf margins :bottom) height-px))
         (top-px (* (getf margins :top) height-px))
         (panel-w (- right-px left-px))
         (panel-h (- top-px bottom-px))
         (bar-x0-px (+ right-px (* 19.5d0 scale)))
         (bar-w-px (* 34.0d0 scale))
         (bar-h-px (* 161.0d0 scale))
         (title-lh (* *legend-title-lh-px* scale))
         (title-gap (* *legend-title-gap-px* scale))
         (block-h (+ title-lh title-gap bar-h-px))
         (block-top (+ (/ (+ bottom-px top-px) 2.0d0) (/ block-h 2.0d0)))
         (bar-y1-px (- block-top title-lh title-gap))   ; bar top, y-up
         (bar-y0-px (- bar-y1-px bar-h-px))
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
    (flet ((add-rect (x0 y0 w h color &optional (zorder 4))
             (let ((rect (make-instance 'cl-matplotlib.rendering:rectangle
                                        :x0 x0 :y0 y0 :width w :height h
                                        :facecolor color :edgecolor nil
                                        :linewidth 0.0d0 :zorder zorder)))
               (setf (cl-matplotlib.rendering:artist-transform rect)
                     trans-axes)
               (cl-matplotlib.containers:axes-add-patch axes rect))))
      ;; gradient bar as a stack of rectangles (slight overlap kills seams)
      (dotimes (i n-steps)
        (let* ((v (+ lo (* (/ (+ i 0.5d0) n-steps) (- hi lo))))
               (color (svref (scale-map gscale (vector v)) 0)))
          (add-rect fx0 (+ fy0 (* fh (/ (float i 1.0d0) n-steps)))
                    fw (* fh (/ 1.5d0 n-steps)) color)))
      ;; breaks: white tick marks inside both edges + labels right of bar
      (let ((breaks (remove-if-not (lambda (b) (<= lo b hi))
                                   (extended-breaks lo hi 5)))
            (tick-w (/ (* 6.0d0 scale) panel-w))
            (tick-h (/ (* 1.0d0 scale) panel-h)))
        (loop for b in breaks
              for label in (%format-break-set breaks)
              for yf = (+ fy0 (* fh (/ (- b lo) (max (- hi lo) 1.0d-12))))
              do (add-rect (+ fx0 (/ (* 2.0d0 scale) panel-w))
                           (- yf (/ tick-h 2.0d0)) tick-w tick-h "white" 5)
                 (add-rect (+ fx0 fw (/ (* -8.0d0 scale) panel-w))
                           (- yf (/ tick-h 2.0d0)) tick-w tick-h "white" 5)
                 (%axes-fraction-text
                  axes label
                  (+ fx0 fw (/ (* 5.0d0 scale) panel-w)) yf
                  :fontsize 8.8d0 :color "black" :ha :left :zorder 5)))
      ;; title on its line above the bar, left-aligned with it
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
          (%axes-fraction-text
           axes title
           (+ fx0 (/ (* 2.0d0 scale) panel-w))
           (/ (- (- block-top (/ title-lh 2.0d0)) bottom-px) panel-h)
           :fontsize 11.0d0 :ha :left :zorder 5))))))

(defun %legend-glyph-size (spec)
  "gg size aesthetic for legend glyphs: layer param, else geom default."
  (let* ((geom (getf spec :geom))
         (params (getf spec :params))
         (defaults (geom-default-aes geom)))
    (or (getf params :size) (getf defaults :size) 0.5d0)))

(defun %draw-legend (built theme spec axes margins width-px height-px dpi)
  "plotnine-style legend right of the panel: #F2F2F2 key boxes with geom
glyphs, labels right of the keys, title above, the whole block vertically
centered on the panel area. All geometry constants are pixel measurements
of plotnine 0.15.7 output (see *legend-*-px* above)."
  (declare (ignore built theme))
  (let* ((scale (/ dpi 100.0d0))
         ;; grid area (all panels) in figure px: drives centering and the
         ;; legend x position
         (right-px (* (getf margins :right) width-px))
         (bottom-px (* (getf margins :bottom) height-px))
         (top-px (* (getf margins :top) height-px))
         ;; anchor panel box in figure px: the coordinate system the
         ;; artists are drawn in (trans-axes fractions of THIS panel)
         (anchor-pos (cl-matplotlib.containers:axes-base-position axes))
         (left-px (* (first anchor-pos) width-px))
         (panel-w (* (third anchor-pos) width-px))
         (anchor-bottom-px (* (second anchor-pos) height-px))
         (panel-h (* (fourth anchor-pos) height-px))
         (entry-labels (getf spec :labels))
         (values (getf spec :values))
         (geom (getf spec :geom))
         (aesthetic (getf spec :aesthetic))
         (n (length entry-labels))
         (key (* *legend-key-px* scale))
         (pitch (* *legend-key-pitch-px* scale))
         (title-lh (* *legend-title-lh-px* scale))
         (title-gap (* *legend-title-gap-px* scale))
         (keys-h (+ key (* (1- n) pitch)))
         (block-h (+ title-lh title-gap keys-h))
         (block-top (+ (/ (+ bottom-px top-px) 2.0d0) (/ block-h 2.0d0)))
         (key-x0 (+ right-px (* *legend-gap-px* scale)))
         (label-x (+ key-x0 key (* *legend-label-gap-px* scale)))
         (trans-axes (cl-matplotlib.containers:axes-base-trans-axes axes))
         (glyph (geom-key-glyph geom)))
    (flet ((fx (px) (/ (- px left-px) panel-w))
           (fy (px) (/ (- px anchor-bottom-px) panel-h))
           (add-rect (x0-px y0-px w-px h-px color)
             (let ((rect (make-instance
                          'cl-matplotlib.rendering:rectangle
                          :x0 (/ (- x0-px left-px) panel-w)
                          :y0 (/ (- y0-px anchor-bottom-px) panel-h)
                          :width (/ w-px panel-w)
                          :height (/ h-px panel-h)
                          :facecolor color :edgecolor nil
                          :linewidth 0.0d0 :zorder 4)))
               (setf (cl-matplotlib.rendering:artist-transform rect)
                     trans-axes)
               (cl-matplotlib.containers:axes-add-patch axes rect))))
      (%axes-fraction-text axes (getf spec :title)
                           (fx key-x0) (fy (- block-top (/ title-lh 2.0d0)))
                           :fontsize 11.0d0 :ha :left :zorder 5)
      (loop for i from 0 below n
            for label in entry-labels
            for v in values
            for key-top = (- block-top title-lh title-gap (* i pitch))
            for cy = (- key-top (/ key 2.0d0))
            do (add-rect key-x0 (- key-top key) key key "#F2F2F2")
               (let ((color (if (eq aesthetic :shape) "black" v)))
                 (ecase glyph
                   (:rect (add-rect key-x0 (- key-top key) key key color))
                   (:line (let ((lw-px (* (size-to-linewidth
                                           (%legend-glyph-size spec))
                                          (/ dpi 72.0d0))))
                            (add-rect key-x0 (- cy (/ lw-px 2.0d0))
                                      key lw-px color)))
                   (:point
                    (let* ((size (or (getf (getf spec :params) :size) 1.5d0))
                           (d-px (* (sqrt (size-to-scatter-s size))
                                    (/ dpi 72.0d0)))
                           (dot (make-instance
                                 'cl-matplotlib.rendering:ellipse
                                 :center (list (fx (+ key-x0 (/ key 2.0d0)))
                                               (fy cy))
                                 :width (/ d-px panel-w)
                                 :height (/ d-px panel-h)
                                 :facecolor color :edgecolor nil
                                 :linewidth 0.0d0 :zorder 5)))
                      (setf (cl-matplotlib.rendering:artist-transform dot)
                            trans-axes)
                      (cl-matplotlib.containers:axes-add-patch axes dot)))))
               (%axes-fraction-text axes label (fx label-x) (fy cy)
                                    :fontsize 8.8d0 :ha :left :zorder 5)))))

;; Facet cell geometry, measured from plotnine facet_wrap renders at
;; dpi 100: strips are 19px tall above each panel, panels separated by 7px.
(defparameter *strip-height-px* 19.0d0)
(defparameter *panel-spacing-px* 7.0d0)

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

(defun %draw-strip-right (axes label theme strip-frac)
  "facet-grid row strip: a #D9D9D9 band right of the panel (axes-fraction
x in [1, 1+strip-frac]) with the label rotated -90."
  (let* ((strip-bg (theme-element theme :strip-background))
         (fill (if (element-rect-p strip-bg)
                   (or (element-rect-fill strip-bg) "#D9D9D9")
                   "#D9D9D9"))
         (rect (make-instance 'cl-matplotlib.rendering:rectangle
                              :x0 1.0d0 :y0 0.0d0
                              :width strip-frac :height 1.0d0
                              :facecolor fill
                              :edgecolor nil
                              :linewidth 0.0d0
                              :zorder 4)))
    (setf (cl-matplotlib.rendering:artist-transform rect)
          (cl-matplotlib.containers:axes-base-trans-axes axes))
    (cl-matplotlib.containers:axes-add-patch axes rect)
    (%axes-fraction-text axes label (+ 1.0d0 (/ strip-frac 2.0d0)) 0.5d0
                         :rotation -90.0d0
                         :fontsize 8.8d0 :color "#1A1A1A" :zorder 5)))

(defmethod ggrender ((built ggbuilt) &key figure (width 6.4d0) (height 4.8d0) (dpi 100))
  (let* ((theme (ggbuilt-theme built))
         (nrow (or (ggbuilt-nrow built) 1))
         (ncol (or (ggbuilt-ncol built) 1))
         (facet (or (plot-facet (ggbuilt-plot built))
                    (make-instance 'facet-null-obj)))
         (grid-p (typep facet 'facet-grid-obj))
         (free-x (facet-free-x-p facet))
         (free-y (facet-free-y-p facet))
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
              ;; facet-grid: one strip band above the whole top row and
              ;; (with row vars) right of the last column, carved out of
              ;; the margins; facet-wrap: a strip above every cell
              (grid-strip-top-p (and grid-p
                                     (facet-col-vars facet)
                                     multi))
              (grid-strip-right-p (and grid-p
                                       (facet-row-vars facet)
                                       multi))
              (margins (if (or grid-strip-top-p grid-strip-right-p)
                           (list :left (getf margins :left)
                                 :right (- (getf margins :right)
                                           (if grid-strip-right-p
                                               (/ (* *strip-height-px* scale)
                                                  width-px)
                                               0.0d0))
                                 :top (- (getf margins :top)
                                         (if grid-strip-top-p
                                             (/ (* *strip-height-px* scale)
                                                height-px)
                                             0.0d0))
                                 :bottom (getf margins :bottom))
                           margins))
              (strip-px (if (and multi (not grid-p))
                            (* *strip-height-px* scale)
                            0.0d0))
              ;; free scales: inner panels keep their tick labels, so the
              ;; spacing widens to fit them (measured: 7px + label + 7px)
              (spacing-x-px
                (if multi
                    (+ (* *panel-spacing-px* scale)
                       (if free-y
                           (let ((label-size 8.8d0))
                             (+ (* *panel-spacing-px* scale)
                                (loop for p in (ggbuilt-panels built)
                                      when (plusp (or (getf p :col) 0))
                                        maximize
                                        (reduce
                                         #'max (getf p :y-labels)
                                         :key (lambda (l)
                                                (%mpl-text-width-px
                                                 l label-size dpi))
                                         :initial-value 0.0d0))))
                           0.0d0))
                    0.0d0))
              (spacing-y-px
                (if multi
                    (+ (* *panel-spacing-px* scale)
                       ;; free-x inner rows keep x labels: one line box
                       (if free-x (* 18.0d0 scale) 0.0d0))
                    0.0d0))
              (area-w (* (- (getf margins :right) (getf margins :left)) width-px))
              (area-h (* (- (getf margins :top) (getf margins :bottom)) height-px))
              (cell-w (/ (- area-w (* (1- ncol) spacing-x-px)) ncol))
              (cell-h (/ (- area-h (* (1- nrow) spacing-y-px)) nrow))
              (panel-h (- cell-h strip-px))
              (axes-list '()))
         (apply #'cl-matplotlib.containers:figure-subplots-adjust
                fig (append margins
                            (when multi
                              (list :wspace (/ spacing-x-px cell-w)
                                    :hspace (/ spacing-y-px cell-h)))))
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
             ;; Shared-axis tick label suppression (fixed dims only:
             ;; free scales label every panel, like plotnine)
             (when multi
               (unless (or free-x (= row (1- nrow)))
                 (setf (cl-matplotlib.containers:axis-tick-labels-visible-p
                        (cl-matplotlib.containers:axes-base-xaxis axes))
                       nil))
               (unless (or free-y (zerop col))
                 (setf (cl-matplotlib.containers:axis-tick-labels-visible-p
                        (cl-matplotlib.containers:axes-base-yaxis axes))
                       nil)))
             ;; Theme: tick label size/color; plotnine tick geometry
             ;; (2.75px major marks, NO minor marks - only minor gridlines;
             ;; inner facet panels get no tick marks at all)
             (let ((axis-text (theme-element theme :axis-text))
                   (x-axis (cl-matplotlib.containers:axes-base-xaxis axes))
                   (y-axis (cl-matplotlib.containers:axes-base-yaxis axes)))
               (dolist (axis (list x-axis y-axis))
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
                    axis :size 0.0 :which :minor)))
               (when multi
                 (unless (or free-x (= row (1- nrow)))
                   (cl-matplotlib.containers:axis-set-tick-params
                    x-axis :size 0.0 :which :major))
                 (unless (or free-y (zerop col))
                   (cl-matplotlib.containers:axis-set-tick-params
                    y-axis :size 0.0 :which :major))))
             (%apply-panel-theme theme axes panel)
             ;; Layers, filtered to this panel
             (loop for (layer . table) in (ggbuilt-layer-tables built)
                   for subset = (%gtable-panel-subset table idx)
                   when (plusp (gtable-nrows subset))
                     do (geom-draw-panel (layer-geom layer) subset panel axes))
             ;; Strips: facet-wrap above every cell; facet-grid above the
             ;; top row and right of the last column, in the margin bands
             (cond
               (grid-p
                (let ((sf-h (/ (* *strip-height-px* scale) panel-h))
                      (sf-w (/ (* *strip-height-px* scale) cell-w)))
                  (when (getf panel :label)
                    (%draw-strip axes (getf panel :label) theme sf-h))
                  (when (getf panel :row-label)
                    (%draw-strip-right axes (getf panel :row-label) theme
                                       sf-w))))
               ((and multi (getf panel :label))
                (%draw-strip axes (getf panel :label) theme
                             (/ strip-px panel-h))))))
         (setf axes-list (nreverse axes-list))
         ;; Colorbar guide for continuous color/fill
         (let ((gscale (%gradient-scale built)))
           (when gscale
             (%draw-colorbar built theme gscale
                             (cdr (assoc (1- ncol) axes-list))
                             margins (* width dpi) (* height dpi) dpi)))
         ;; Legend drawn manually (plotnine geometry), anchored to the
         ;; first panel of the last column but positioned in figure px
         (let ((spec (first (ggbuilt-legends built))))
           (when spec
             (when (rest (ggbuilt-legends built))
               (warn "Multiple legends requested; only the ~S guide is drawn"
                     (getf spec :aesthetic)))
             (let ((anchor-axes (cdr (assoc (1- ncol) axes-list))))
               (when anchor-axes
                 (%draw-legend built theme spec anchor-axes margins
                               width-px height-px dpi)))))
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
