;;;; packages.lisp — package definition for the ggplot system

(defpackage #:ggplot
  (:nicknames #:gg)
  (:use #:cl)
  ;; NOTE: deliberately does NOT :use cl-matplotlib.pyplot or .containers —
  ;; their exports (plot, bar, text, position, ...) clash with grammar names.
  ;; Backend calls are package-qualified.
  (:import-from #:cl-matplotlib.containers
                ;; shared calendar/date engine (src/containers/dates.lisp)
                #:format-date #:date-break-uts #:date-add-months
                #:auto-date-spec #:auto-date-fmt #:ut-to-num #:num-to-ut)
  (:export
   ;; core entry points
   #:ggplot #:aes #:stack #:ggsave #:ggdraw #:ggbuild #:ggrender #:qplot
   ;; data protocol
   #:ggcolumns #:ggcolumn #:ggnrows #:ggdata-p
   #:ggdata #:make-ggdata
   ;; component folding
   #:ggadd
   ;; layers / geoms
   #:layer #:geom-blank #:geom-point #:geom-line #:geom-path
   #:geom-bar #:geom-col
   #:geom-histogram #:geom-freqpoly #:geom-area #:geom-ribbon
   #:geom-density #:geom-boxplot #:geom-violin
   #:geom-smooth #:geom-tile #:geom-raster #:geom-text #:geom-label
   #:geom-segment #:geom-hline #:geom-vline #:geom-rect #:annotate
   #:geom-step #:geom-rug #:geom-linerange #:geom-errorbar
   #:geom-abline #:geom-jitter #:geom-crossbar
   #:geom-bin2d #:geom-bin-2d #:geom-count
   #:geom-pointrange #:geom-qq
   ;; positions
   #:position-identity #:position-stack #:position-fill #:position-dodge
   #:position-jitter #:position-nudge
   ;; coords
   #:coord-cartesian #:coord-flip
   ;; facets
   #:facet-wrap #:facet-grid
   ;; helpers
   #:labs #:xlab #:ylab #:ggtitle #:lims #:xlim #:ylim
   ;; scales
   #:scale-x-continuous #:scale-y-continuous
   #:scale-x-discrete #:scale-y-discrete
   #:scale-color-discrete #:scale-fill-discrete
   #:scale-color-manual #:scale-fill-manual
   #:scale-shape-manual #:scale-size #:scale-alpha
   #:scale-color-gradient #:scale-fill-gradient
   #:scale-color-cmap #:scale-fill-cmap
   #:scale-color-gradient2 #:scale-fill-gradient2
   #:scale-color-gradientn #:scale-fill-gradientn
   #:scale-color-brewer #:scale-fill-brewer
   #:scale-x-sqrt #:scale-y-sqrt #:scale-x-reverse #:scale-y-reverse
   #:scale-color-identity #:scale-fill-identity
   #:scale-shape-identity #:scale-size-identity
   #:scale-x-log10 #:scale-y-log10
   #:scale-x-date #:scale-y-date #:date #:format-date
   #:scale-color-grey #:scale-fill-grey
   #:expand-limits
   ;; themes
   #:theme #:theme-gray #:theme-grey #:theme-minimal #:theme-bw
   #:theme-classic #:theme-dark #:theme-void
   #:element-line #:element-rect #:element-text #:element-blank
   #:theme-set #:theme-get
   ;; aes marker
   #:after-stat))
