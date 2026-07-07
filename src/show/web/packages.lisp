;;;; packages.lisp — package for the browser display backend.

(defpackage #:cl-matplotlib.show.web
  (:use #:cl)
  (:nicknames #:mpl.show.web)
  (:documentation "Browser display backend: a Clack/hunchentoot server
pushes PNG frames over a websocket to an HTML canvas; the page sends
zoom/pan/home/resize events back. Registered as the :web show adapter.")
  (:export
   ;; events.lisp — pure, unit-tested
   #:parse-event
   #:coalesce-events
   #:apply-event
   #:coords-json
   ;; server.lisp
   #:web-show-adapter
   #:ensure-server
   #:stop-server
   #:*port*))
