;;;; server.lisp — the Clack/hunchentoot server behind the :web adapter.
;;;;
;;;; One global lazily-started server. Each show-figure call registers a
;;;; session (an interactor keyed by an integer id); the browser page at
;;;; /figure/<id> opens a websocket to /ws?fig=<id>. Binary messages to
;;;; the client are PNG frames; text messages are coords updates. Client
;;;; events are queued per connection and drained by a worker thread that
;;;; coalesces bursts (events.lisp) so a fast mouse can't outrun renders.

(in-package #:cl-matplotlib.show.web)

(defvar *server* nil)
(defvar *port* nil
  "Port the show web server is listening on, or NIL when not running.")
(defvar *sessions* (make-hash-table)
  "Figure id → wsession.")
(defvar *session-counter* 0)
(defvar *server-lock* (bt:make-lock "mpl-show-web"))

(defstruct wsession
  id
  interactor
  (lock (bt:make-lock))
  (cv (bt:make-condition-variable))
  (open-count 0)
  (ever-opened-p nil)
  (closed-p nil))

(defstruct conn
  ws
  session
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
            finally (error "show web server: no free port found after 10 attempts")))
    *port*))

(defun stop-server ()
  "Stop the show web server and drop all figure sessions."
  (bt:with-lock-held (*server-lock*)
    (when *server*
      (clack:stop *server*)
      (setf *server* nil *port* nil)
      (clrhash *sessions*)))
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

(defun %query-fig-id (env)
  (let* ((qs (or (getf env :query-string) ""))
         (pos (search "fig=" qs)))
    (when pos
      (parse-integer qs :start (+ pos 4) :junk-allowed t))))

(defun %app (env)
  (let ((path (getf env :path-info)))
    (cond
      ((and (stringp path) (uiop:string-prefix-p "/figure/" path))
       (%respond-file "index.html" "text/html"))
      ((equal path "/app.js")
       (%respond-file "app.js" "application/javascript"))
      ((equal path "/ws")
       (%handle-ws env))
      (t '(404 (:content-type "text/plain") ("not found"))))))

;;; ============================================================
;;; Websocket connection
;;; ============================================================

(defun %send-frame (conn)
  (let ((png (mpl.show:interactor-render-png
              (wsession-interactor (conn-session conn)))))
    (websocket-driver:send-binary (conn-ws conn) png)))

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

(defun %conn-worker (conn)
  (let ((interactor (wsession-interactor (conn-session conn))))
    (loop
      (multiple-value-bind (events stop-p) (%drain conn)
        (dolist (event (coalesce-events events))
          (handler-case
              (case (apply-event interactor event)
                (:frame (%send-frame conn))
                (:coords (websocket-driver:send-text
                          (conn-ws conn)
                          (coords-json interactor
                                       (getf event :x) (getf event :y)))))
            (error (e)
              (format *error-output* "~&; show-web event error: ~A~%" e))))
        (when stop-p (return))))))

(defun %conn-opened (conn)
  (let ((session (conn-session conn)))
    (bt:with-lock-held ((wsession-lock session))
      (incf (wsession-open-count session))
      (setf (wsession-ever-opened-p session) t))
    (setf (conn-thread conn)
          (bt:make-thread (lambda ()
                            (handler-case (%conn-worker conn)
                              (error (e)
                                (format *error-output*
                                        "~&; show-web worker died: ~A~%" e))))
                          :name "mpl-show-web-worker"))
    ;; initial frame so the page shows the figure immediately
    (handler-case (%send-frame conn)
      (error (e)
        (format *error-output* "~&; show-web initial frame failed: ~A~%" e)))))

(defun %conn-closed (conn)
  (let ((session (conn-session conn)))
    (bt:with-lock-held ((conn-lock conn))
      (setf (conn-stop-p conn) t)
      (bt:condition-notify (conn-cv conn)))
    (bt:with-lock-held ((wsession-lock session))
      (decf (wsession-open-count session))
      (when (and (<= (wsession-open-count session) 0)
                 (wsession-ever-opened-p session))
        ;; last tab closed → unblock show-figure :block waiters
        (setf (wsession-closed-p session) t)
        (bt:condition-notify (wsession-cv session))))))

(defun %handle-ws (env)
  (let* ((id (%query-fig-id env))
         (session (and id (gethash id *sessions*))))
    (if (null session)
        '(404 (:content-type "text/plain") ("unknown figure id"))
        (let* ((ws (websocket-driver:make-server env))
               (conn (make-conn :ws ws :session session)))
          (websocket-driver:on :open ws (lambda () (%conn-opened conn)))
          (websocket-driver:on :message ws (lambda (msg) (%enqueue conn msg)))
          (websocket-driver:on :close ws
                               (lambda (&key code reason)
                                 (declare (ignore code reason))
                                 (%conn-closed conn)))
          (lambda (responder)
            (declare (ignore responder))
            (websocket-driver:start-connection ws))))))

;;; ============================================================
;;; The :web adapter
;;; ============================================================

(defclass web-show-adapter () ()
  (:documentation "Browser display backend. Always available (opens the
system browser; headless callers read the printed URL instead)."))

(defmethod mpl.show:show-figure ((adapter web-show-adapter) figure &key block)
  "Register FIGURE with the web server, open a browser tab on its page,
and return the URL. With BLOCK, return only after the page's last
websocket closes. Set SHOW_WEB_NO_BROWSER=1 to skip opening a browser."
  (ensure-server)
  (let* ((id (incf *session-counter*))
         (session (make-wsession :id id
                                 :interactor (mpl.show:make-interactor figure)))
         (url (format nil "http://127.0.0.1:~D/figure/~D" *port* id)))
    (setf (gethash id *sessions*) session)
    (format t "~&; showing figure at ~A~%" url)
    (unless (uiop:getenv "SHOW_WEB_NO_BROWSER")
      (ignore-errors (trivial-open-browser:open-browser url)))
    (when block
      (bt:with-lock-held ((wsession-lock session))
        (loop until (wsession-closed-p session)
              do (bt:condition-wait (wsession-cv session)
                                    (wsession-lock session)))))
    url))

(defvar *web-adapter* (make-instance 'web-show-adapter))

(mpl.show:register-show-adapter :web (lambda () *web-adapter*)
                                :priority 10)
