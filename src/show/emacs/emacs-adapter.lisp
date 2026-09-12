;;;; emacs-adapter.lisp — display backend that shows figures in Emacs.
;;;;
;;;; The figure is rendered to an SVG string (savefig with a NIL
;;;; destination) and pushed to Emacs through the SLIME/SLY server's
;;;; eval-in-emacs, where a self-contained form puts the text in a buffer
;;;; and turns on image-mode. Emacs renders SVG natively (librsvg), so
;;;; nothing touches the filesystem and no elisp needs installing. The
;;;; one piece of Emacs configuration is enabling Lisp→Emacs evaluation:
;;;;
;;;;   (setq slime-enable-evaluate-in-emacs t)   ; SLIME
;;;;   (setq sly-enable-evaluate-in-emacs t)     ; SLY
;;;;
;;;; swank/slynk are reached lazily by name, so this system loads without
;;;; either; the adapter reports itself unavailable until an Emacs
;;;; connection exists. The image buffer is static (no zoom/pan), and
;;;; :block is a no-op — there is nothing to wait for once the buffer is
;;;; displayed.

(defpackage #:cl-matplotlib.show.emacs
  (:use #:cl)
  (:nicknames #:mpl.show.emacs)
  (:export #:emacs-show-adapter
           #:adapter-buffer-name
           #:*buffer-name*
           #:emacs-connection-p))

(in-package #:cl-matplotlib.show.emacs)

(defvar *buffer-name* "*cl-matplotlib*"
  "Name of the Emacs buffer figures are displayed in. Each show replaces
the buffer's contents.")

(defclass emacs-show-adapter ()
  ((buffer-name :initarg :buffer-name :initform nil
                :accessor adapter-buffer-name
                :documentation "Buffer name override; NIL means *buffer-name*."))
  (:documentation "Show adapter that renders to SVG and displays it in an
Emacs image buffer over the SLIME/SLY connection."))

;;; ------------------------------------------------------------
;;; Locating the SLIME/SLY server
;;; ------------------------------------------------------------

(defun %server-package ()
  "The loaded Lisp-side SLIME/SLY server package (SWANK or SLYNK), or NIL."
  (or (find-package '#:swank) (find-package '#:slynk)))

(defun %connection (pkg)
  "The Emacs connection object for server package PKG, or NIL. Prefers the
connection bound on this thread (a REPL request), falling back to the
server's default connection so background threads can display too."
  (let ((bound (find-symbol "*EMACS-CONNECTION*" pkg))
        (default (find-symbol "DEFAULT-CONNECTION" pkg)))
    (or (and bound (boundp bound) (symbol-value bound))
        (and default (fboundp default) (funcall default)))))

(defun emacs-connection-p ()
  "True when swank or slynk is loaded and has a live Emacs connection."
  (let ((pkg (%server-package)))
    (and pkg (%connection pkg) t)))

;;; ------------------------------------------------------------
;;; The Emacs-side form
;;; ------------------------------------------------------------

(defun %display-form (svg buffer-name)
  "The elisp form that shows SVG text in BUFFER-NAME as an image.
The buffer is made unibyte and receives the UTF-8 encoding of the text,
so non-ASCII labels reach librsvg as the bytes the XML declaration
promises. Returns the buffer name so the RPC has a printable value."
  `(let ((buf (get-buffer-create ,buffer-name)))
     (with-current-buffer buf
       (let ((inhibit-read-only t))
         (fundamental-mode)
         (erase-buffer)
         (set-buffer-multibyte nil)
         (insert (encode-coding-string ,svg 'utf-8))
         (image-mode)))
     (display-buffer buf)
     ,buffer-name))

(defun %eval-in-emacs (form)
  "Evaluate FORM in Emacs through swank/slynk and return its value.
Waits for the reply so an Emacs-side error (most likely eval-in-emacs
being disabled) surfaces here as a Lisp error."
  (let ((pkg (%server-package)))
    (unless pkg
      (error "cl-matplotlib-show-emacs: no SLIME/SLY server loaded (neither SWANK nor SLYNK is present)."))
    (let ((conn (%connection pkg))
          (conn-var (find-symbol "*EMACS-CONNECTION*" pkg))
          (evaluator (find-symbol "EVAL-IN-EMACS" pkg)))
      (unless conn
        (error "cl-matplotlib-show-emacs: no Emacs connection — run this from a SLIME/SLY REPL."))
      (handler-case
          ;; PROGV rather than swank's WITH-CONNECTION macro: same effect
          ;; (the connection bound for send/receive) without a compile-time
          ;; dependency on either server.
          (progv (list conn-var) (list conn)
            (funcall evaluator form))
        (error (e)
          (let ((text (princ-to-string e)))
            (if (search "disabled" text)
                (error "cl-matplotlib-show-emacs: Emacs refused the evaluation. Enable it with~@
                        (setq slime-enable-evaluate-in-emacs t)  ; or sly-enable-evaluate-in-emacs under SLY~@
                        Original message: ~A" text)
                (error e))))))))

;;; ------------------------------------------------------------
;;; Adapter protocol
;;; ------------------------------------------------------------

(defmethod mpl.show:show-figure ((adapter emacs-show-adapter) figure &key block)
  "Render FIGURE to SVG and display it in the Emacs buffer named by the
adapter (default *buffer-name*). Returns the buffer name. BLOCK is
ignored: the image buffer is static, so there is nothing to wait for."
  (declare (ignore block))
  (let* ((name (or (adapter-buffer-name adapter) *buffer-name*))
         (svg (mpl.containers:savefig figure nil :format :svg)))
    (%eval-in-emacs (%display-form svg name))
    name))

(defvar *emacs-adapter* (make-instance 'emacs-show-adapter))

;; Priority 15: above the browser (10) — if you are in Emacs you want the
;; plot in Emacs — but below a native window (20) when one is possible.
;; (setf mpl.show:*show-backend* :emacs) forces it.
(mpl.show:register-show-adapter :emacs (lambda () *emacs-adapter*)
                                :available-fn #'emacs-connection-p
                                :priority 15)
