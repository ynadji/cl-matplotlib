;;;; Package definitions for cl-matplotlib
;;;; Phase 0 — Feasibility PoC + Phase 1 — Foundation

;;; ============================================================
;;; Foundation packages (Phase 1)
;;; ============================================================

(defpackage #:cl-matplotlib.cbook
  (:use #:cl)
  (:nicknames #:mpl.cbook)
  (:documentation "Utility functions ported from matplotlib.cbook.")
  (:export #:check-isinstance #:check-in-list #:check-shape #:check-error
           #:ls-mapper #:*ls-mapper*
           #:normalize-kwargs #:*kwarg-aliases*
           #:make-silent-list #:silent-list #:silent-list-type #:silent-list-items
           #:flatten #:safe-first #:pairwise #:index-of
           #:str-lower-equal #:str-equal))

(defpackage #:cl-matplotlib.api
  (:use #:cl)
  (:nicknames #:mpl.api)
  (:documentation "Deprecation warning system and caching utilities.")
  (:export #:matplotlib-deprecation-warning
           #:warn-deprecated
           #:suppress-matplotlib-deprecation-warning
           #:deprecated
           #:define-cached-function #:clear-cache
           #:*unset* #:unsetp #:unset-type
           #:nargs-error #:getitem-checked #:levenshtein-distance))

(defpackage #:cl-matplotlib.rc
  (:use #:cl)
  (:nicknames #:mpl.rc)
  (:documentation "RC parameter system with validators.")
  (:export ;; Conditions
           #:rc-validation-error #:rc-validation-error-key #:rc-validation-error-value
           #:rc-key-error
           ;; Validators
           #:validate-any #:validate-bool #:validate-float #:validate-float-or-none
           #:validate-int #:validate-int-or-none #:validate-string #:validate-string-or-none
           #:validate-positive-float #:validate-non-negative-float #:validate-float-0-to-1
           #:validate-non-negative-int #:validate-dpi #:validate-fontsize
           #:validate-fontsize-or-none #:validate-fontweight #:validate-fontstretch
           #:validate-color #:validate-color-or-auto #:validate-color-or-inherit
           #:validate-color-or-none
           #:validate-linestyle #:validate-linestyle-or-none
           #:validate-joinstyle #:validate-capstyle
           #:validate-aspect #:validate-bbox #:validate-fonttype
           #:validate-stringlist #:validate-floatlist #:validate-intlist
           #:validate-axisbelow #:validate-sketch #:validate-marker
           #:validate-fillstyle #:validate-pathlike #:validate-hatch
           #:make-validate-in-strings
           ;; RC store
           #:*rc-validators* #:*rc-params* #:*rc-defaults*
           #:register-rc-param #:define-rc-param
           ;; Accessor
           #:rc #:with-rc #:rc-reset #:rc-update #:rc-find-all
           ;; RC file parser
           #:strip-comment #:parse-rc-line #:parse-matplotlibrc #:load-matplotlibrc
           ;; Initialization
           #:initialize-default-rc-params))

(defpackage #:cl-matplotlib.colors
  (:use #:cl)
  (:nicknames #:mpl.colors)
  (:documentation "Color name database and conversion utilities.")
  (:export #:*base-colors* #:*tableau-colors* #:*css4-colors* #:*all-named-colors*
           #:hex-to-rgba #:rgb-to-rgba #:to-rgba #:is-color-like
           #:initialize-color-databases))

;;; ============================================================
;;; Original packages (Phase 0 — preserved)
;;; ============================================================

(defpackage #:cl-matplotlib.foundation
  (:use #:cl)
  (:nicknames #:mpl.foundation)
  (:documentation "Core types, math utilities, color, transforms.")
  (:export #:rgba-color #:make-rgba
           #:affine-2d #:make-affine-2d #:affine-multiply
           #:deg->rad #:rad->deg
           #:clamp))

(defpackage #:cl-matplotlib.primitives
  (:use #:cl)
  (:nicknames #:mpl.primitives)
  (:documentation "Path, BBox, FontProperties, Transforms, Colors — geometry and color primitives.")
  (:export ;; Path code constants
           #:+stop+ #:+moveto+ #:+lineto+ #:+curve3+ #:+curve4+ #:+closepoly+
           #:*num-vertices-for-code*
           ;; BBox
           #:bbox #:make-bbox #:bbox-null #:bbox-null-p
           #:bbox-x0 #:bbox-y0 #:bbox-x1 #:bbox-y1
           #:bbox-extents #:bbox-width #:bbox-height
           #:bbox-union #:bbox-contains-point-p
           ;; Path struct
           #:mpl-path #:make-path #:%make-mpl-path
           #:mpl-path-vertices #:mpl-path-codes #:mpl-path-readonly
           #:mpl-path-should-simplify #:mpl-path-simplify-threshold
           #:mpl-path-interpolation-steps
           #:path-length
           ;; Path operations
           #:path-iter-segments #:path-get-extents
           #:path-contains-point #:path-contains-points
           #:path-intersects-path #:path-intersects-bbox
           #:path-transformed #:path-clip-to-bbox
           #:path-to-polygons #:path-to-polygon-points
           #:path-interpolated #:path-cleaned
           #:path-copy #:path-deepcopy
           #:path-create-closed
           ;; Path constructors
           #:path-make-compound-path
           #:path-unit-rectangle #:path-unit-circle #:path-circle
           #:path-arc #:path-wedge
           ;; Algorithms (public)
           #:point-in-path-crossings #:point-in-polygon-p
           #:sutherland-hodgman-clip
           #:douglas-peucker
           #:de-casteljau-split-cubic #:de-casteljau-split-quadratic
           #:cubic-bezier-extrema-t #:quadratic-bezier-extrema-t
           #:cubic-bezier-point-at #:quadratic-bezier-point-at
           #:segments-intersect-p #:segment-intersects-rectangle-p
           #:snap-to-pixel #:simple-linear-interpolation
           #:isclose
           ;; Transform invalidation constants
           #:+valid+ #:+invalid-affine-only+ #:+invalid-full+
           ;; Affine matrix operations
           #:affine-matrix
           #:make-identity-matrix #:affine-matrix-multiply #:affine-matrix-invert
           #:affine-transform-point #:copy-matrix #:matrix-equal-p
           #:matrix-a #:matrix-b #:matrix-c #:matrix-d #:matrix-e #:matrix-f
           ;; Transform node base
           #:transform-node #:transform-node-invalid #:transform-node-is-affine-p
           #:invalidate #:set-children #:frozen
           ;; Transform base
           #:transform #:get-matrix #:transform-point #:transform-path
           #:invert #:compose
           ;; Affine 2D transforms
           #:affine-2d-base #:affine-2d #:make-affine-2d
           #:affine-2d-matrix #:set-matrix #:affine-2d-clear
           #:affine-2d-translate #:set-translate
           #:affine-2d-scale #:affine-2d-rotate #:affine-2d-rotate-deg
           #:affine-2d-rotate-around #:affine-2d-rotate-deg-around
           #:affine-2d-skew #:affine-2d-skew-deg
           ;; Identity transform
           #:identity-transform #:make-identity-transform #:*identity-transform*
           ;; Frozen transform
           #:frozen-transform
           ;; Composite transforms
           #:composite-affine-2d #:composite-a #:composite-b
           #:composite-generic-transform
           ;; Blended transforms
           #:blended-affine-2d #:blended-generic-transform
           #:blended-x-transform #:blended-y-transform
           #:make-blended-transform
           ;; BBox transform
           #:bbox-transform #:make-bbox-transform
           ;; Transform wrapper
           #:transform-wrapper #:transform-wrapper-child #:transform-wrapper-set
           ;; TransformedBbox
           #:transformed-bbox #:make-transformed-bbox
           #:transformed-bbox-x0 #:transformed-bbox-y0
           #:transformed-bbox-x1 #:transformed-bbox-y1
            ;; TransformedPath
            #:transformed-path-node #:transformed-path-get
            ;; Scale transforms
            #:log-transform #:log-transform-base #:log-transform-nonpositive
            #:inverted-log-transform #:inverted-log-transform-base
            #:symlog-transform #:symlog-transform-base #:symlog-transform-linthresh
            #:symlog-transform-linscale
            #:inverted-symlog-transform #:inverted-symlog-transform-base
            #:inverted-symlog-transform-linthresh #:inverted-symlog-transform-linscale
            #:logit-transform #:logit-transform-nonpositive
            #:logistic-transform #:logistic-transform-nonpositive
            #:func-transform #:func-transform-forward #:func-transform-inverse
            ;; Color conversion (extends foundation)
            #:to-hex #:to-rgb
           ;; Colormap classes
           #:colormap #:colormap-name #:colormap-n #:colormap-call
           #:linear-segmented-colormap #:make-linear-segmented-colormap
           #:linear-segmented-colormap-from-list
           #:listed-colormap #:make-listed-colormap
           ;; Colormap registry
           #:*colormaps* #:register-colormap #:get-colormap #:list-colormaps
           #:initialize-colormaps
           ;; Normalize classes
           #:normalize #:make-normalize #:normalize-call #:normalize-inverse
           #:norm-vmin #:norm-vmax #:norm-clip
           #:no-norm #:make-no-norm
           #:log-norm #:make-log-norm
           #:sym-log-norm #:make-sym-log-norm
           #:power-norm #:make-power-norm
           #:two-slope-norm #:make-two-slope-norm
           #:boundary-norm #:make-boundary-norm
           ;; ScalarMappable
           #:scalar-mappable #:make-scalar-mappable
           #:scalar-mappable-to-rgba #:scalar-mappable-autoscale
           #:sm-norm #:sm-cmap))

(defpackage #:cl-matplotlib.rendering
  (:use #:cl)
  (:nicknames #:mpl.rendering)
  (:documentation "Artist hierarchy, rendering primitives, and draw protocol.")
  (:export ;; Draw protocol
           #:draw #:get-path #:get-patch-transform #:get-artist-transform
           #:get-extents #:stale-p
           ;; Artist base class
           #:artist #:artist-transform #:artist-transform-set-p
           #:artist-alpha #:artist-visible #:artist-clip-box #:artist-clip-path
           #:artist-clip-on #:artist-label #:artist-zorder #:artist-animated
           #:artist-picker #:artist-url #:artist-gid #:artist-rasterized
           #:artist-sketch-params #:artist-stale #:artist-axes #:artist-figure
           #:artist-children #:artist-set
           ;; Graphics context
           #:graphics-context #:make-gc
           #:gc-foreground #:gc-background #:gc-linewidth #:gc-linestyle
           #:gc-alpha #:gc-capstyle #:gc-joinstyle #:gc-clip-rectangle
           #:gc-clip-path #:gc-antialiased #:gc-dashes #:gc-hatch #:gc-url
           ;; Mock renderer
           #:mock-renderer #:make-mock-renderer #:mock-renderer-calls
           #:mock-renderer-record
           #:renderer-draw-path #:renderer-draw-text #:renderer-draw-image
           ;; Line2D
           #:line-2d #:line-2d-xdata #:line-2d-ydata
           #:line-2d-linewidth #:line-2d-linestyle #:line-2d-color
           #:line-2d-marker #:line-2d-markersize
           #:line-2d-markeredgecolor #:line-2d-markerfacecolor
           #:line-2d-markeredgewidth #:line-2d-drawstyle
           #:line-2d-antialiased #:line-2d-pickradius
           #:line-2d-path #:line-2d-set-data
           ;; Patch base
           #:patch #:patch-edgecolor #:patch-facecolor
           #:patch-linewidth #:patch-linestyle #:patch-antialiased
           #:patch-hatch #:patch-fill #:patch-capstyle #:patch-joinstyle
           ;; Rectangle
           #:rectangle #:rectangle-x0 #:rectangle-y0
           #:rectangle-width #:rectangle-height #:rectangle-angle
           ;; Ellipse
           #:ellipse #:ellipse-center #:ellipse-width #:ellipse-height #:ellipse-angle
           ;; Circle
           #:circle #:circle-radius
           ;; Polygon
           #:polygon #:polygon-xy #:polygon-closed
           ;; Wedge
           #:wedge #:wedge-center #:wedge-r #:wedge-theta1 #:wedge-theta2 #:wedge-width
           ;; Arc
           #:arc #:arc-theta1 #:arc-theta2
           ;; PathPatch
           #:path-patch #:path-patch-path
           ;; FancyBboxPatch
           #:fancy-bbox-patch #:fancy-bbox-x0 #:fancy-bbox-y0
           #:fancy-bbox-width #:fancy-bbox-height #:fancy-bbox-boxstyle #:fancy-bbox-pad
           ;; Text
           #:text-artist #:text-x #:text-y #:text-text #:text-color
           #:text-fontsize #:text-fontfamily #:text-fontweight #:text-fontstyle
           #:text-rotation #:text-horizontalalignment #:text-verticalalignment
           #:text-multialignment #:text-linespacing #:text-wrap
           #:text-rotation-mode #:text-usetex
           #:text-ha #:text-va #:text-set-position
            ;; FancyArrowPatch
            #:fancy-arrow-patch #:fancy-arrow-posA #:fancy-arrow-posB
            #:fancy-arrow-arrowstyle #:fancy-arrow-connectionstyle
            #:fancy-arrow-shrinkA #:fancy-arrow-shrinkB
            #:fancy-arrow-mutation-scale #:fancy-arrow-patchA #:fancy-arrow-patchB
            #:fancy-arrow-path-original #:fancy-arrow-cached-path
            ;; ConnectionStyle
            #:connection-style #:connect #:make-connection-style
            #:arc3-connection #:arc3-rad
            #:angle3-connection #:angle3-angleA #:angle3-angleB
            #:angle-connection #:angle-angleA
            ;; BoxStyle
            #:box-style #:box-transmute #:make-box-style
            #:square-box #:round-box #:round4-box #:sawtooth-box #:roundtooth-box
            #:square-box-pad #:round-box-pad #:round-box-rounding-size
            #:round4-box-pad #:round4-box-rounding-size
            #:sawtooth-box-pad #:roundtooth-box-pad
            ;; Annotation
            #:annotation #:annotation-xy #:annotation-xytext
            #:annotation-xycoords #:annotation-textcoords
            #:annotation-arrowprops #:annotation-bbox
            #:annotation-arrow-patch
            #:annotation-set-position #:annotation-set-target
            ;; AnchoredText
            #:anchored-text #:anchored-text-text #:anchored-text-loc
            #:anchored-text-pad #:anchored-text-borderpad
            #:anchored-text-frameon #:anchored-text-fontsize
            #:anchored-text-color #:anchored-text-facecolor #:anchored-text-edgecolor
            ;; MarkerStyle
           #:marker-style #:marker-style-marker #:marker-style-fillstyle
           #:marker-style-path #:marker-style-transform
           #:marker-style-filled-p #:marker-style-joinstyle #:marker-style-capstyle
           #:make-marker-path #:make-marker-style
           #:*marker-names* #:*filled-markers*
           ;; AxesImage
            #:axes-image #:image-data #:image-extent #:image-interpolation
            #:image-origin #:image-cmap #:image-norm #:image-vmin #:image-vmax
            #:image-aspect
            #:image-shape #:image-rows #:image-cols
             #:*interpolation-methods*
             ;; Interpolation algorithms
             #:interpolate-nearest #:interpolate-bilinear
             #:interpolate-nearest-rgba #:interpolate-bilinear-rgba
            ;; Font Manager
            #:font-entry #:make-font-entry
            #:font-entry-fname #:font-entry-name #:font-entry-style
            #:font-entry-weight #:font-entry-stretch
            #:font-properties #:make-font-properties
            #:font-properties-family #:font-properties-style
            #:font-properties-weight #:font-properties-size
            #:font-manager #:*font-manager* #:ensure-font-manager #:reset-font-manager
            #:find-font #:findfont #:load-font #:load-font-by-path
            #:find-system-fonts #:shipped-font-directory #:shipped-font-files
            #:build-font-database #:save-font-cache #:load-font-cache
            #:get-glyph-advance-width #:get-font-units-per-em
            #:get-font-ascender #:get-font-descender
            #:font-units-to-points #:get-text-extents
            #:normalize-weight #:resolve-font-family
            #:*font-scalings* #:*weight-dict* #:*font-family-aliases*
            #:*default-font-families* #:*system-font-directories*
            ;; Text-to-Path
            #:text-to-path #:text-to-compound-path
            #:glyph-to-path #:glyph-contour-to-vertices-and-codes
            #:layout-multiline-text #:get-text-width-height-descent
            ;; AFM Parser
            #:afm-font #:parse-afm-file
            #:afm-char-metrics #:afm-char-metrics-width
            #:afm-char-metrics-name #:afm-char-metrics-bbox
            #:afm-get-fontname #:afm-get-fullname #:afm-get-familyname
            #:afm-get-weight #:afm-get-angle
            #:afm-get-ascender #:afm-get-descender
            #:afm-get-capheight #:afm-get-xheight #:afm-get-bbox
            #:afm-get-char-width #:afm-get-width-from-name
            #:afm-get-kern-dist #:afm-get-str-bbox-and-descent
             #:afm-unicode-to-type1-name #:*unicode-to-type1*
             ;; Hatch patterns
             #:hatch-get-path #:*valid-hatch-patterns*
             ;; Collection protocol
             #:collection-get-paths #:collection-get-transforms
             ;; Collection base class
             #:collection #:collection-offsets #:collection-trans-offset
             #:collection-facecolors #:collection-edgecolors
             #:collection-linewidths #:collection-linestyles
             #:collection-antialiaseds #:collection-hatch
             #:collection-pickradius #:collection-capstyle #:collection-joinstyle
             #:collection-set-offsets #:collection-set-facecolor
             #:collection-set-edgecolor #:collection-set-linewidth
             #:collection-set-color
             ;; LineCollection
             #:line-collection #:line-collection-segments
             #:collection-set-segments #:make-line-collection
             ;; PathCollection
             #:path-collection #:path-collection-paths #:path-collection-sizes
             #:collection-set-paths #:collection-set-sizes
             #:make-path-collection
             ;; PatchCollection
             #:patch-collection #:patch-collection-patches
             #:collection-set-patches
             ;; PolyCollection
             #:poly-collection #:poly-collection-verts
             #:collection-set-verts
             ;; QuadMesh
             #:quad-mesh #:quad-mesh-width #:quad-mesh-height
             #:quad-mesh-coordinates))

(defpackage #:cl-matplotlib.containers
  (:use #:cl)
  (:nicknames #:mpl.containers)
  (:documentation "Figure, Axes, Artist hierarchy.")
   (:export ;; Layout engine protocol
           #:layout-engine #:layout-engine-execute #:layout-engine-set
           #:layout-engine-get #:layout-engine-params
           #:layout-engine-adjust-compatible-p #:layout-engine-colorbar-gridspec-p
           ;; PlaceHolder layout
           #:placeholder-layout-engine #:make-placeholder-layout-engine
           ;; Tight layout
           #:tight-layout-engine #:make-tight-layout-engine
           ;; Figure class
           #:mpl-figure #:make-figure
           #:figure-figsize #:figure-dpi #:figure-facecolor #:figure-edgecolor
           #:figure-linewidth #:figure-frameon-p
           #:figure-axes #:figure-artists #:figure-lines #:figure-patches
           #:figure-texts #:figure-images #:figure-legends #:figure-subfigs
           #:figure-canvas #:figure-layout-engine #:figure-subplot-params
           #:figure-suptitle-artist #:figure-patch
           ;; Figure functions
           #:figure-width-inches #:figure-height-inches
           #:figure-width-px #:figure-height-px #:figure-size-px
           #:figure-set-size-inches #:figure-get-size-inches
           #:figure-set-layout-engine #:figure-get-layout-engine
           #:figure-add-artist #:figure-remove-artist #:figure-get-children
           #:figure-subplots-adjust #:figure-ensure-canvas
           #:draw-figure-background
           ;; savefig pipeline
           #:savefig #:detect-format #:print-figure
           ;; SubFigure
           #:sub-figure #:make-subfigure #:subfigure-parent #:subfigure-position
           ;; AxesBase class
           #:axes-base #:axes-base-figure #:axes-base-position
           #:axes-base-facecolor #:axes-base-frameon-p
           #:axes-base-trans-data #:axes-base-trans-axes #:axes-base-trans-scale
           #:axes-base-data-lim #:axes-base-view-lim
           #:axes-base-lines #:axes-base-patches #:axes-base-artists
           #:axes-base-texts #:axes-base-images #:axes-base-patch
           #:axes-base-autoscale-x-p #:axes-base-autoscale-y-p
           #:axes-base-autoscale-margin
           ;; AxesBase functions
           #:axes-update-datalim #:axes-autoscale-view
           #:axes-set-xlim #:axes-set-ylim
           #:axes-get-xlim #:axes-get-ylim
           #:axes-add-line #:axes-add-patch #:axes-add-artist
           #:axes-get-all-artists
            ;; Axes class (rectilinear)
            #:mpl-axes
            ;; Axes axis/spine accessors
            #:axes-base-xaxis #:axes-base-yaxis #:axes-base-spines
             ;; Plotting functions
             #:add-subplot
              #:plot #:scatter #:bar #:axes-fill #:fill-between
              #:imshow #:axes-add-image
              ;; Additional plot types (Phase 6b)
              #:hist #:pie #:errorbar #:stem #:axes-step
               #:stackplot #:barh #:boxplot
               #:annotate
            ;; Grid
            #:axes-grid-toggle
            ;; Ticker — Locator base
            #:locator #:locator-axis #:locator-tick-values #:locator-call
            ;; Locators (7 total)
            #:null-locator
            #:fixed-locator #:fixed-locator-locs #:fixed-locator-nbins
            #:linear-locator #:linear-locator-numticks
            #:multiple-locator #:multiple-locator-base #:multiple-locator-offset
            #:max-n-locator #:max-n-locator-nbins #:max-n-locator-steps
            #:max-n-locator-integer-p #:max-n-locator-symmetric-p
            #:max-n-locator-prune #:max-n-locator-min-n-ticks
            #:auto-locator
            #:log-locator #:log-locator-base #:log-locator-subs
            ;; Ticker — Formatter base
            #:tick-formatter #:tick-formatter-axis #:tick-formatter-call
            #:tick-formatter-format-ticks
            ;; Formatters (6 total)
            #:null-formatter
            #:fixed-formatter #:fixed-formatter-seq
            #:scalar-formatter #:scalar-formatter-use-offset-p
            #:scalar-formatter-scientific-p #:scalar-formatter-power-limits
            #:str-method-formatter #:str-method-formatter-fmt
            #:log-formatter #:log-formatter-base #:log-formatter-label-only-base-p
            #:percent-formatter #:percent-formatter-xmax
            #:percent-formatter-decimals #:percent-formatter-symbol
            ;; Spine
            #:spine #:spine-axes #:spine-spine-type #:spine-path
            #:spine-visible-p #:spine-position-spec #:spine-bounds
            #:spine-set-visible #:spine-set-position #:spine-set-color
            #:spine-set-linewidth
            ;; Spines container
            #:spines #:make-spines #:spines-ref #:spines-all #:spines-draw-all
            ;; Axis
            #:axis-obj #:axis-axes #:axis-major-locator #:axis-minor-locator
            #:axis-major-formatter #:axis-minor-formatter
            #:axis-label-text #:axis-label-artist
            #:axis-tick-size-major #:axis-tick-size-minor
            #:axis-tick-direction #:axis-tick-label-fontsize
            #:axis-grid-on-p #:axis-grid-color #:axis-grid-linewidth
            #:axis-grid-linestyle #:axis-grid-alpha
             #:axis-set-major-locator #:axis-set-minor-locator
             #:axis-set-major-formatter #:axis-set-minor-formatter
             #:axis-set-label-text #:axis-grid #:axis-set-tick-params
             #:axis-get-view-interval #:axis-get-data-interval
             #:axis-get-major-ticks #:axis-get-minor-ticks
             ;; Axis scale
             #:axis-scale #:axis-set-scale
             ;; XAxis / YAxis
             #:x-axis #:y-axis
             ;; Scale base
             #:scale-base #:scale-name #:scale-axis
             #:scale-get-transform #:scale-set-default-locators-and-formatters
             #:scale-limit-range-for-scale
             ;; Scale classes
             #:linear-scale
             #:log-scale #:log-scale-base #:log-scale-subs #:log-scale-nonpositive
             #:symlog-scale #:symlog-scale-base #:symlog-scale-linthresh
             #:symlog-scale-linscale #:symlog-scale-subs
             #:logit-scale #:logit-scale-nonpositive
             #:func-scale #:func-scale-functions
             ;; Scale factory
             #:make-scale
             ;; Axes scale methods
             #:axes-set-xscale #:axes-set-yscale
             ;; Tick
             #:tick #:tick-loc #:tick-major-p #:tick-size #:tick-width
             #:tick-color #:tick-direction #:tick-pad
             #:tick-label-text #:tick-label-fontsize #:tick-label-color
             #:tick-gridline-visible-p
             ;; Legend slot on axes
             #:axes-base-legend
             ;; Legend handler classes
             #:handler-base #:handler-line-2d #:handler-patch
             #:handler-line-collection #:handler-path-collection
             #:create-legend-artists #:legend-artist
             #:get-legend-handler #:*default-handler-map*
             ;; Legend class
             #:mpl-legend #:legend-parent #:legend-handles #:legend-labels
             #:legend-loc #:legend-bbox-to-anchor #:legend-ncol
             #:legend-fontsize #:legend-frameon-p #:legend-facecolor
             #:legend-edgecolor #:legend-framealpha #:legend-title
             #:legend-title-fontsize #:legend-handleheight #:legend-handlelength
             #:legend-handletextpad #:legend-columnspacing #:legend-borderpad
             #:legend-labelspacing #:legend-handler-map
             #:legend-entry-artists #:legend-frame
             #:*legend-codes* #:*legend-loc-positions*
             ;; Legend convenience
             #:axes-legend
             ;; Colorbar class
             #:mpl-colorbar #:colorbar-mappable #:colorbar-cax #:colorbar-ax
             #:colorbar-orientation #:colorbar-label #:colorbar-ticks
             #:colorbar-format #:colorbar-n-levels #:colorbar-extend
             ;; Colorbar convenience
              #:make-colorbar
              ;; GridSpec classes
              #:gridspec-base #:gridspec #:gridspec-from-subplot-spec
              #:subplot-spec
              ;; GridSpec constructors
              #:make-gridspec #:make-subplot-spec #:make-gridspec-from-subplot-spec
              ;; GridSpec accessors
              #:gridspec-nrows #:gridspec-ncols #:gridspec-figure
              #:gridspec-left #:gridspec-right #:gridspec-top #:gridspec-bottom
              #:gridspec-wspace #:gridspec-hspace
              #:gridspec-width-ratios #:gridspec-height-ratios
              ;; GridSpec functions
              #:gridspec-get-geometry #:gridspec-get-subplot-params
              #:gridspec-get-grid-positions #:gridspec-subplotspec
              ;; SubplotSpec accessors/functions
              #:subplotspec-gridspec #:subplotspec-num1 #:subplotspec-num2
              #:subplotspec-get-gridspec #:subplotspec-get-rows-columns
              #:subplotspec-rowspan #:subplotspec-colspan
              #:subplotspec-get-position
              ;; GridSpecFromSubplotSpec
              #:gridspec-from-ss-parent #:gridspec-from-ss-wspace
              #:gridspec-from-ss-hspace #:gridspec-from-ss-get-topmost-subplotspec
              ;; Subplots and mosaic
              #:subplots #:subplot-mosaic
               ;; Shared axes
               #:axes-share-x #:axes-share-y
               #:axes-base-sharex-group #:axes-base-sharey-group
               ;; Marching squares algorithm
               #:marching-squares-single-level #:marching-squares-levels
               #:marching-squares-filled
               #:auto-select-levels #:auto-select-levels-filled
               ;; ContourSet classes
               #:contour-set #:contourset-levels #:contourset-collections
               #:contourset-cmap #:contourset-norm #:contourset-filled-p
               #:contourset-linewidths #:contourset-linestyles
               #:contourset-colors #:contourset-label-texts
               #:contourset-get-paths
               ;; QuadContourSet
               #:quad-contour-set #:qcs-x #:qcs-y #:qcs-z
               ;; Contour plotting functions
               #:contour #:contourf #:clabel))

(defpackage #:cl-matplotlib.backends
  (:use #:cl)
  (:nicknames #:mpl.backends)
  (:documentation "Backend implementations (Vecto/cl-aa based).")
   (:export ;; RendererBase protocol (generic functions)
            #:draw-path #:draw-image #:draw-text #:draw-markers
            #:draw-path-collection #:draw-gouraud-triangles
           #:get-canvas-width-height #:points-to-pixels
           #:renderer-clear #:renderer-option-image-nocomposite
           ;; RendererBase class
           #:renderer-base #:renderer-width #:renderer-height #:renderer-dpi
           ;; Canvas protocol
           #:canvas-draw #:print-png #:get-renderer
           ;; Canvas base class
           #:canvas-base #:canvas-width #:canvas-height #:canvas-dpi
           #:canvas-renderer #:canvas-figure
           ;; Vecto renderer
           #:renderer-vecto #:renderer-active-p #:renderer-font-cache
           ;; Vecto canvas
           #:canvas-vecto #:canvas-render-fn
           ;; Deferred canvas
           #:canvas-vecto-deferred #:canvas-draw-calls
           #:canvas-record-draw-path
           ;; Convenience
           #:make-graphics-context #:render-to-png
           ;; Font config
           #:*default-font-path*))

(defpackage #:cl-matplotlib.pyplot
  (:use #:cl)
  (:nicknames #:mpl.pyplot #:plt)
  (:documentation "Top-level plotting API matching matplotlib.pyplot.")
  (:export #:figure #:subplots #:plot #:show #:savefig
           #:xlabel #:ylabel #:title #:legend
           #:xlim #:ylim #:grid))

(defpackage #:cl-matplotlib
  (:use #:cl)
  (:nicknames #:mpl)
  (:documentation "Main cl-matplotlib package — re-exports key symbols.")
  (:export #:version))
