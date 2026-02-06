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
  (:documentation "Path, BBox, FontProperties — geometry primitives.")
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
           #:isclose))

(defpackage #:cl-matplotlib.rendering
  (:use #:cl)
  (:nicknames #:mpl.rendering)
  (:documentation "Graphics context, renderer protocol.")
  (:export #:graphics-context #:make-gc
           #:renderer-base #:draw-path #:draw-image #:draw-text
           #:get-canvas-width-height))

(defpackage #:cl-matplotlib.containers
  (:use #:cl)
  (:nicknames #:mpl.containers)
  (:documentation "Figure, Axes, Artist hierarchy.")
  (:export #:figure #:axes #:artist
           #:line-2d #:patch #:text-artist))

(defpackage #:cl-matplotlib.backends
  (:use #:cl)
  (:nicknames #:mpl.backends)
  (:documentation "Backend implementations (Vecto/cl-aa based).")
  (:export #:renderer-agg #:canvas-agg
           #:save-png #:save-pdf))

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
