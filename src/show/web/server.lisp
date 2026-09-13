;;;; server.lisp — the Clack/hunchentoot server behind the :web adapter.
;;;;
;;;; One global lazily-started server serving one page for all figures.
;;;; The figures on display are the window manager's windows
;;;; (mpl.show:*wm*); the page shows them as tabs. A browser page opens
;;;; ONE websocket to /ws over which every window's traffic is
;;;; multiplexed: binary messages to the client are frames prefixed by a
;;;; 4-byte big-endian window id, text messages are JSON ("windows" —
;;;; the tab list, "coords" — a readout update with its "fig"); client
;;;; events are JSON carrying "fig". Events are queued per connection and
;;;; drained by a worker thread that coalesces bursts (events.lisp) so a
;;;; fast mouse can't outrun renders.
;;;;
;;;; A window manager listener pushes tab-list updates and fresh frames
;;;; to every connected page, so a figure shown from the REPL appears as
;;;; a new tab everywhere.

(in-package #:cl-matplotlib.show.web)

(defvar *server* nil)
(defvar *port* nil
  "Port the show web server is listening on, or NIL when not running.")
(defvar *server-lock* (bt:make-lock "mpl-show-web"))
(defvar *conns* '()
  "Open page connections.")
(defvar *conns-lock* (bt:make-lock "mpl-show-web-conns"))
(defvar *ever-connected-p* nil
  "Set once a page has connected; closing the last page then closes every window.")

(defstruct conn
  ws
  (queue '())
  (lock (bt:make-lock))
  (cv (bt:make-condition-variable))
  (stop-p nil)
  thread)

;;; ============================================================
;;; Server lifecycle
;;; ============================================================

(defun %static-path (name)
  (asdf:system-relative-pathname
   :cl-matplotlib-show-web (format nil "src/show/web/static/~A" name)))

(defun %pick-port ()
  (let ((env (uiop:getenv "SHOW_WEB_PORT")))
    (if (and env (plusp (length env)))
        (parse-integer env)
        (+ 49152 (random 16000 (make-random-state t))))))

(defun ensure-server ()
  "Start the show web server if it is not already running; return the
port. Honors the SHOW_WEB_PORT environment variable, otherwise picks a
random ephemeral port (up to 10 attempts)."
  (bt:with-lock-held (*server-lock*)
    (unless *server*
      (loop repeat 10
            for port = (%pick-port)
            do (handler-case
                   (progn
                     ;; :debug nil — the interactive debugger would hang
                     ;; hunchentoot worker threads on any handler error
                     (setf *server* (clack:clackup #'%app :server :hunchentoot
                                                   :port port :silent t :debug nil)
                           *port* port)
                     (return))
                 (error (e)
                   (when (uiop:getenv "SHOW_WEB_PORT")
                     (error "show web server could not bind port ~D: ~A" port e))))
            finally (error "show web server: no free port found after 10 attempts"))
      (mpl.show:wm-add-listener #'%wm-listener))
    *port*))

(defun stop-server ()
  "Stop the show web server and close every window."
  (bt:with-lock-held (*server-lock*)
    (when *server*
      (mpl.show:wm-remove-listener #'%wm-listener)
      (clack:stop *server*)
      (setf *server* nil *port* nil *ever-connected-p* nil)))
  (mpl.show:wm-close-all)
  (values))

;;; ============================================================
;;; Routing
;;; ============================================================

(defun %respond-file (name content-type)
  (let ((path (%static-path name)))
    (if (probe-file path)
        `(200 (:content-type ,(format nil "~A; charset=utf-8" content-type)
               :cache-control "no-store")
              (,(uiop:read-file-string path)))
        `(404 (:content-type "text/plain") ("missing static asset")))))

(defun %app (env)
  (let ((path (getf env :path-info)))
    (cond
      ((or (equal path "/") (equal path "/index.html")
           (and (stringp path) (uiop:string-prefix-p "/figure/" path)))
       ;; /figure/<id> serves the same page; the client activates that tab
       (%respond-file "index.html" "text/html"))
      ((equal path "/app.js")
       (%respond-file "app.js" "application/javascript"))
      ((equal path "/ws")
       (%handle-ws env))
      (t '(404 (:content-type "text/plain") ("not found"))))))

;;; ============================================================
;;; Sending
;;; ============================================================

(defun %send-text (conn text)
  (handler-case (websocket-driver:send-text (conn-ws conn) text)
    (error (e) (format *error-output* "~&; show-web send failed: ~A~%" e))))

(defun %send-frame (conn window)
  "Render WINDOW and send it as an id-prefixed binary frame."
  (handler-case
      (let ((png (mpl.show:interactor-render-png (mpl.show:figure-window-interactor window))))
        (websocket-driver:send-binary (conn-ws conn)
                                      (frame-message (mpl.show:figure-window-id window) png)))
    (error (e) (format *error-output* "~&; show-web frame failed: ~A~%" e))))

(defun %send-windows (conn)
  (%send-text conn (windows-json)))

(defun %broadcast (fn)
  (dolist (c (bt:with-lock-held (*conns-lock*) (copy-list *conns*)))
    (funcall fn c)))

(defun %wm-listener (event window)
  "Window manager → pages: tab list on add/remove/activate, a frame on
add/change."
  (case event
    (:added (%broadcast (lambda (c) (%send-windows c) (%send-frame c window))))
    (:removed (%broadcast #'%send-windows))
    (:activated (%broadcast #'%send-windows))
    (:changed (%broadcast (lambda (c) (%send-frame c window))))))

;;; ============================================================
;;; Receiving
;;; ============================================================

(defun %enqueue (conn message)
  ;; binary client messages are unexpected; ignore them
  (when (stringp message)
    (let ((event (ignore-errors (parse-event message))))
      (when event
        (bt:with-lock-held ((conn-lock conn))
          (push event (conn-queue conn))
          (bt:condition-notify (conn-cv conn)))))))

(defun %drain (conn)
  "Block until events arrive or the connection stops;
(values events-in-order stop-p)."
  (bt:with-lock-held ((conn-lock conn))
    (loop while (and (null (conn-queue conn)) (not (conn-stop-p conn)))
          do (bt:condition-wait (conn-cv conn) (conn-lock conn)))
    (let ((events (nreverse (conn-queue conn))))
      (setf (conn-queue conn) '())
      (values events (conn-stop-p conn)))))

(defun %event-window (event)
  "The window an event addresses: its :fig, else the active window."
  (let ((id (getf event :fig)))
    (if id (mpl.show:wm-find id) (mpl.show:wm-active-window))))

(defun %handle-page-event (conn event)
  "Events about windows rather than about a figure's content. Returns T
when handled."
  (case (getf event :type)
    (:activate
     (let ((id (getf event :fig)))
       (when id (mpl.show:wm-activate id)))
     t)
    (:close
     (let ((id (getf event :fig)))
       (when id (mpl.show:wm-close id)))
     t)
    (:new
     ;; a fresh pyplot figure, shown here
     (let ((fig (mpl.pyplot:figure)))
       (mpl.show:wm-register fig))
     t)
    (:refresh
     (let ((w (%event-window event)))
       (when w (%send-frame conn w)))
     t)
    (t nil)))

(defun %conn-worker (conn)
  (loop
    (multiple-value-bind (events stop-p) (%drain conn)
      (dolist (event (coalesce-events events))
        (handler-case
            (unless (%handle-page-event conn event)
              (let ((window (%event-window event)))
                (when window
                  (let ((interactor (mpl.show:figure-window-interactor window)))
                    (case (apply-event interactor event)
                      (:frame
                       ;; an edit may have pasted into another figure: every
                       ;; page refreshes this window; other windows refresh
                       ;; through wm-notify-changed
                       (%broadcast (lambda (c) (%send-frame c window))))
                      (:coords
                       (%send-text conn
                                   (coords-json interactor (getf event :x) (getf event :y)
                                                :fig (mpl.show:figure-window-id window)))))))))
          (error (e)
            (format *error-output* "~&; show-web event error: ~A~%" e))))
      (when stop-p (return)))))

(defun %conn-opened (conn)
  (bt:with-lock-held (*conns-lock*)
    (push conn *conns*)
    (setf *ever-connected-p* t))
  (setf (conn-thread conn)
        (bt:make-thread (lambda ()
                          (handler-case (%conn-worker conn)
                            (error (e)
                              (format *error-output*
                                      "~&; show-web worker died: ~A~%" e))))
                        :name "mpl-show-web-worker"))
  ;; the tab list and a frame per window, so the page is complete at once
  (%send-windows conn)
  (dolist (w (mpl.show:wm-windows))
    (%send-frame conn w)))

(defun %conn-closed (conn)
  (bt:with-lock-held ((conn-lock conn))
    (setf (conn-stop-p conn) t)
    (bt:condition-notify (conn-cv conn)))
  (let ((last-p nil))
    (bt:with-lock-held (*conns-lock*)
      (setf *conns* (remove conn *conns*))
      (setf last-p (and (null *conns*) *ever-connected-p*)))
    ;; the last page went away: every window is closed, which unblocks
    ;; (show :block t) callers
    (when last-p
      (mpl.show:wm-close-all))))

(defun %handle-ws (env)
  (declare (ignore env))
  (let* ((ws (websocket-driver:make-server env))
         (conn (make-conn :ws ws)))
    (websocket-driver:on :open ws (lambda () (%conn-opened conn)))
    (websocket-driver:on :message ws (lambda (msg) (%enqueue conn msg)))
    (websocket-driver:on :close ws
                         (lambda (&key code reason)
                           (declare (ignore code reason))
                           (%conn-closed conn)))
    (lambda (responder)
      (declare (ignore responder))
      (websocket-driver:start-connection ws))))

;;; ============================================================
;;; The :web adapter
;;; ============================================================

(defclass web-show-adapter () ()
  (:documentation "Browser display backend. Always available (opens the
system browser; headless callers read the printed URL instead)."))

(defmethod mpl.show:show-figure ((adapter web-show-adapter) figure &key block)
  "Show FIGURE as a tab of the page, opening a browser on it the first
time, and return the URL. With BLOCK, return only after the figure's
window is closed (its tab, (close-figure), or the last page going away).
Set SHOW_WEB_NO_BROWSER=1 to skip opening a browser."
  (ensure-server)
  (let* ((window (mpl.show:wm-register figure))
         (url (format nil "http://127.0.0.1:~D/figure/~D" *port* (mpl.show:figure-window-id window))))
    (format t "~&; showing figure at ~A~%" url)
    (unless (or (uiop:getenv "SHOW_WEB_NO_BROWSER")
                ;; a page is already open: it gets the new tab pushed
                (bt:with-lock-held (*conns-lock*) *conns*))
      (ignore-errors (trivial-open-browser:open-browser url)))
    (when block
      (mpl.show:wm-wait-closed window))
    url))

(defvar *web-adapter* (make-instance 'web-show-adapter))

(mpl.show:register-show-adapter :web (lambda () *web-adapter*)
                                :priority 10)
