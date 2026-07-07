;;;; extend.lisp — ggplot.extend (gg.ext): the extension API package
;;;; Loaded last so every re-exported symbol already exists in #:ggplot.
;;;; See docs/gg-extending.md.

(defpackage #:ggplot.extend
  (:nicknames #:gg.ext)
  (:use)
  (:import-from #:ggplot
                ;; component base classes
                #:geom #:stat #:ggposition #:scale
                #:scale-continuous #:scale-discrete
                #:coord #:facet #:ggtheme #:layer
                ;; geom protocol
                #:geom-default-aes #:geom-setup-data #:geom-draw-panel
                #:geom-legend-artist #:geom-key-glyph
                ;; stat protocol
                #:stat-default-aes #:stat-compute-panel #:map-stat-groups
                ;; position protocol
                #:position-adjust
                ;; scale protocol
                #:scale-train #:scale-transform #:scale-map #:scale-limits
                #:scale-breaks #:scale-break-labels #:scale-expanded-range
                #:scale-minor-breaks
                ;; layers and composition
                #:make-layer #:make-geom-layer #:ggadd
                ;; registries
                #:register-stat #:register-position #:register-aesthetic
                #:resolve-stat #:resolve-position
                ;; gtables
                #:gtable #:make-gtable #:gtable-column #:gtable-column-names
                #:gtable-set-column #:gtable-select #:gtable-split
                #:gtable-rbind #:gtable-sort-by #:gtable-nrows
                ;; helpers
                #:size-to-linewidth #:size-to-scatter-s
                #:extended-breaks #:finite-range #:discrete-value-p
                #:after-stat #:aes-ref #:eval-aesthetic)
  (:export
   #:geom #:stat #:ggposition #:scale
   #:scale-continuous #:scale-discrete
   #:coord #:facet #:ggtheme #:layer
   #:geom-default-aes #:geom-setup-data #:geom-draw-panel
   #:geom-legend-artist #:geom-key-glyph
   #:stat-default-aes #:stat-compute-panel #:map-stat-groups
   #:position-adjust
   #:scale-train #:scale-transform #:scale-map #:scale-limits
   #:scale-breaks #:scale-break-labels #:scale-expanded-range
   #:scale-minor-breaks
   #:make-layer #:make-geom-layer #:ggadd
   #:register-stat #:register-position #:register-aesthetic
   #:resolve-stat #:resolve-position
   #:gtable #:make-gtable #:gtable-column #:gtable-column-names
   #:gtable-set-column #:gtable-select #:gtable-split
   #:gtable-rbind #:gtable-sort-by #:gtable-nrows
   #:size-to-linewidth #:size-to-scatter-s
   #:extended-breaks #:finite-range #:discrete-value-p
   #:after-stat #:aes-ref #:eval-aesthetic)
  (:documentation "Extension API for the ggplot system: protocol classes,
generics, gtable operations, and registries needed to define third-party
geoms, stats, positions, scales, and aesthetics. See docs/gg-extending.md.
The gg package itself stays purely user-facing."))
