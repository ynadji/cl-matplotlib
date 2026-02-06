;;;; Package definitions for cl-matplotlib
;;;; Phase 0 — Feasibility PoC

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
