;;;; packages.lisp — package definition for cl-matplotlib-show
;;;; Lives here (not src/packages.lisp) because -show is an optional
;;;; system, like ggplot's src/ggplot/packages.lisp.

(defpackage #:cl-matplotlib.show
  (:use #:cl)
  (:nicknames #:mpl.show)
  (:documentation "Interactive display core: in-memory figure rendering,
a backend-agnostic zoom/pan interactor, and the adapter protocol that
display backends (web, SDL2, CAPI) implement.

All interactor methods take pixel coordinates with the TOP-LEFT origin
(the native convention of browsers, SDL, and CAPI); the y flip into the
figure's bottom-left display space happens internally.")
  (:export
   ;; render.lisp — figure → in-memory buffer
   #:render-figure-to-rgba
   #:render-figure-to-png-octets
   ;; interactor.lisp — zoom/pan/reset state machine
   #:interactor
   #:make-interactor
   #:interactor-figure
   #:interactor-render-rgba
   #:interactor-render-png
   #:interactor-zoom
   #:interactor-pan-start
   #:interactor-pan-move
   #:interactor-pan-end
   #:interactor-reset
   #:interactor-resize
   #:interactor-cursor-coords
   #:interactor-cursor-info
   #:interactor-hit-axes
   #:interactor-mode #:interactor-selection #:interactor-select #:interactor-clear-selection
   #:interactor-pins #:interactor-pin-point #:interactor-clear-pins
   #:interactor-rotate-start #:interactor-rotate-move
   ;; pick.lisp — hit testing
   #:interactor-pick #:interactor-nearest-point #:interactor-legend-hit
   ;; commands.lisp — clipboard and undo
   #:plot-trace #:make-plot-trace #:trace-from-artist #:trace-instantiate #:*trace-clipboard*
   #:interactor-copy #:interactor-cut #:interactor-paste #:interactor-delete
   #:interactor-undo #:interactor-redo #:interactor-toggle-visible
   #:interactor-can-undo-p #:interactor-can-redo-p
   ;; events.lisp — backend-agnostic event dispatch
   #:interactor-handle-event #:*key-bindings*
   ;; protocol.lisp — adapter registry + show entry point
   #:show-figure
   #:register-show-adapter
   #:*show-backend*
   #:show))
