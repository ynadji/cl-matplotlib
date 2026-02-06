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
  (:export #:mpl-path #:make-mpl-path
           #:bbox #:make-bbox
           #:+moveto+ #:+lineto+ #:+curve3+ #:+curve4+ #:+closepoly+))

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
