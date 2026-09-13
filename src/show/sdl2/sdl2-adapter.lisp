;;;; sdl2-adapter.lisp — native window display backend via SDL2.
;;;;
;;;; One native window per figure, all driven by ONE event loop: the
;;;; loop mirrors the window manager (mpl.show:*wm*) — every registered
;;;; figure-window gets an SDL2 window, a window closed anywhere (its
;;;; close button, `q`, (close-figure), a web tab) goes away here too,
;;;; and a figure shown from the REPL while the loop runs pops up as a
;;;; new window. SDL window ids route events to the right figure.
;;;;
;;;; Frames are the interactor's RGBA buffers uploaded into a streaming
;;;; texture. :abgr8888 on a little-endian machine reads bytes as
;;;; R,G,B,A — exactly zpng's layout; +texture-format+ is the single
;;;; constant to flip if a platform disagrees.
;;;;
;;;; Interaction goes through the shared dispatcher
;;;; (mpl.show:interactor-handle-event), so it matches the web backend:
;;;; wheel = zoom, left-drag = pan (2D) or rotate (3D; shift-drag pans),
;;;; click = select a trace / toggle a legend entry / pin a data cursor,
;;;; h = home, c = cursor mode, ctrl-c/x/v = copy/cut/paste (across
;;;; windows), Delete, ctrl-z / ctrl-shift-z = undo/redo, Escape = clear
;;;; selection and pins. SDL2-only: s = save PNG in the current
;;;; directory, q = close the window. The cursor readout lives in the
;;;; window title. Focusing a window makes its figure the active one
;;;; (pyplot's current figure).
;;;;
;;;; Threading: the first (show) starts the loop — in the calling thread
;;;; for :block t (it returns when that figure's window closes, handing
;;;; any remaining windows to a worker thread), else on a worker. Later
;;;; (show)s just register a window; :block t waits for it to close. On
;;;; macOS call the first (show ... :block t) from the initial thread
;;;; (Cocoa requirement).

(defpackage #:cl-matplotlib.show.sdl2
  (:use #:cl)
  (:nicknames #:mpl.show.sdl2)
  (:export #:sdl2-show-adapter
           #:run-sdl2-show-loop
           #:loop-running-p))

(in-package #:cl-matplotlib.show.sdl2)

(defconstant +texture-format+ :abgr8888
  "SDL pixel format matching zpng's RGBA byte order on little-endian.")

(defconstant +windowevent-close+ 14 "SDL_WINDOWEVENT_CLOSE")
(defconstant +windowevent-size-changed+ 6 "SDL_WINDOWEVENT_SIZE_CHANGED")
(defconstant +windowevent-focus-gained+ 12 "SDL_WINDOWEVENT_FOCUS_GAINED")

(defun %upload-frame (texture fbuf rgba width)
  "Upload the lisp RGBA buffer into TEXTURE in one copy. FBUF is unused
(kept for the call signature): the buffer is pinned and its address
handed to SDL directly, instead of the former byte-by-byte copy through
foreign memory, which cost more than the render for large windows."
  (declare (type (simple-array (unsigned-byte 8) (*)) rgba)
           (ignore fbuf))
  (cffi:with-pointer-to-vector-data (ptr rgba)
    (sdl2:update-texture texture nil ptr (* 4 width))))

(defun %save-frame (interactor)
  "Save the figure as figure-<universal-time>.png in the cwd."
  (let ((path (format nil "figure-~D.png" (get-universal-time))))
    (mpl.containers:savefig (mpl.show:interactor-figure interactor) path)
    (format t "~&; saved ~A~%" path)
    path))

;;; ============================================================
;;; Views: one SDL2 window per figure-window
;;; ============================================================

(defstruct view
  sdl-id win renderer texture w h
  window                                ; the mpl.show:figure-window
  (dirty nil) (dragging nil) (moved nil) (press-x 0) (press-y 0))

(defvar *views* (make-hash-table #+sbcl :synchronized #+sbcl t)
  "SDL window id → view, written by the loop thread (tests read it).")
(defvar *loop-lock* (bt:make-lock "mpl-show-sdl2"))
(defvar *loop-running-p* nil)
(defvar *changed* '()
  "Figure-window ids flagged :changed by the window manager since the
last idle step (any thread → loop thread, under *loop-lock*).")

(defun loop-running-p ()
  "True while the SDL2 event loop is driving windows."
  (bt:with-lock-held (*loop-lock*) *loop-running-p*))

(defun %wm-listener (event window)
  (when (eq event :changed)
    (bt:with-lock-held (*loop-lock*)
      (pushnew (mpl.show:figure-window-id window) *changed*))))

(defun %view-interactor (view)
  (mpl.show:figure-window-interactor (view-window view)))

(defun %view-title (view)
  (mpl.show:figure-window-title (view-window view)))

(defun %open-view (window)
  "Create the SDL2 window, renderer and texture for WINDOW and show its
first frame."
  (let ((interactor (mpl.show:figure-window-interactor window)))
    (multiple-value-bind (rgba w h) (mpl.show:interactor-render-rgba interactor)
      (let* ((win (sdl2:create-window :title (mpl.show:figure-window-title window)
                                      :w w :h h :flags '(:shown :resizable)))
             (renderer (sdl2:create-renderer win -1 nil))
             (texture (sdl2:create-texture renderer +texture-format+ :streaming w h))
             (view (make-view :sdl-id (sdl2:get-window-id win) :win win
                              :renderer renderer :texture texture :w w :h h
                              :window window)))
        (setf (gethash (view-sdl-id view) *views*) view)
        (%blit view rgba)
        view))))

(defun %close-view (view)
  (remhash (view-sdl-id view) *views*)
  (ignore-errors (sdl2:destroy-texture (view-texture view)))
  (ignore-errors (sdl2:destroy-renderer (view-renderer view)))
  (ignore-errors (sdl2:destroy-window (view-win view))))

(defun %blit (view rgba)
  (%upload-frame (view-texture view) nil rgba (view-w view))
  (sdl2:render-copy (view-renderer view) (view-texture view))
  (sdl2:render-present (view-renderer view)))

(defun %flush (view)
  "Render and show VIEW's frame if it is dirty."
  (when (view-dirty view)
    (setf (view-dirty view) nil)
    (%blit view (mpl.show:interactor-render-rgba (%view-interactor view)))))

(defun %sync-size (view)
  "The window size changed → re-render at the new size."
  (multiple-value-bind (ww wh) (sdl2:get-window-size (view-win view))
    (unless (and (= ww (view-w view)) (= wh (view-h view)))
      (mpl.show:interactor-resize (%view-interactor view) ww wh)
      (setf (view-w view) ww (view-h view) wh)
      (sdl2:destroy-texture (view-texture view))
      (setf (view-texture view)
            (sdl2:create-texture (view-renderer view) +texture-format+ :streaming ww wh))
      (setf (view-dirty view) t))))

(defun %update-title (view x y)
  (let* ((title (%view-title view))
         (info (mpl.show:interactor-cursor-info (%view-interactor view) x y)))
    (sdl2:set-window-title
     (view-win view)
     (cond ((getf info :label)
            (format nil "~A — ~A[~D] x=~,6G y=~,6G~@[ z=~,6G~]" title
                    (getf info :label) (getf info :index)
                    (getf info :px) (getf info :py) (getf info :z)))
           ((getf info :x)
            (format nil "~A — x=~,6G y=~,6G" title (getf info :x) (getf info :y)))
           (t title)))))

(defun %sync-views ()
  "Mirror the window manager: open a view for every figure-window that
has none, close the views of windows that are gone, and mark the ones
flagged :changed dirty."
  (let ((windows (mpl.show:wm-windows)))
    (dolist (view (loop for view being the hash-values of *views*
                        unless (member (view-window view) windows) collect view))
      (%close-view view))
    (dolist (w windows)
      (unless (loop for view being the hash-values of *views*
                      thereis (eq (view-window view) w))
        (handler-case (%open-view w)
          (error (e)
            ;; a window that cannot open is closed, not retried every idle step
            (format *error-output* "~&; show-sdl2: cannot open a window for ~A: ~A~%"
                    (mpl.show:figure-window-title w) e)
            (mpl.show:wm-close (mpl.show:figure-window-id w))))))
    (let ((changed (bt:with-lock-held (*loop-lock*)
                     (prog1 *changed* (setf *changed* '())))))
      (when changed
        (loop for view being the hash-values of *views*
              when (member (mpl.show:figure-window-id (view-window view)) changed)
                do (setf (view-dirty view) t))))))

(defun %view-for-figure-window (window)
  (loop for view being the hash-values of *views*
        when (eq (view-window view) window) return view))

;;; ============================================================
;;; The loop
;;; ============================================================

(defun %key-name (keysym)
  "The browser KeyboardEvent.key name the shared key map uses."
  (cond ((sdl2:scancode= keysym :scancode-h) "h")
        ((sdl2:scancode= keysym :scancode-c) "c")
        ((sdl2:scancode= keysym :scancode-x) "x")
        ((sdl2:scancode= keysym :scancode-v) "v")
        ((sdl2:scancode= keysym :scancode-z) "z")
        ((sdl2:scancode= keysym :scancode-y) "y")
        ((sdl2:scancode= keysym :scancode-s) "s")
        ((sdl2:scancode= keysym :scancode-q) "q")
        ((sdl2:scancode= keysym :scancode-escape) "Escape")
        ((sdl2:scancode= keysym :scancode-delete) "Delete")
        ((sdl2:scancode= keysym :scancode-backspace) "Backspace")
        (t nil)))

(defun %mod-p (&rest names)
  (apply #'sdl2:mod-value-p (sdl2:get-mod-state) names))
(defun %ctrl-p () (%mod-p :lctrl :rctrl :lgui :rgui))
(defun %shift-p () (%mod-p :lshift :rshift))

(defun run-sdl2-show-loop (&key (stop-fn (lambda () (null (mpl.show:wm-windows)))))
  "Drive an SDL2 window per window-manager window until STOP-FN returns
true (default: no windows left). Runs in the calling thread; returns
when done. Windows opened here are destroyed on exit; their
figure-windows stay registered so another loop can pick them up."
  (bt:with-lock-held (*loop-lock*)
    (when *loop-running-p* (error "the SDL2 show loop is already running"))
    (setf *loop-running-p* t *changed* '()))
  (mpl.show:wm-add-listener #'%wm-listener)
  (unwind-protect
       (sdl2:with-init (:video)
         (unwind-protect
              (progn
                (%sync-views)
                (flet ((view (id) (gethash id *views*))
                       (dispatch (view event)
                         (mpl.show:interactor-handle-event (%view-interactor view) event))
                       (refresh (view) (setf (view-dirty view) t)))
                  (sdl2:with-event-loop (:method :poll)
                    (:idle ()
                      (%sync-views)
                      (cond ((funcall stop-fn) (sdl2:push-quit-event))
                            ((loop for v being the hash-values of *views*
                                   when (view-dirty v) do (%flush v) and count t))
                            (t (sdl2:delay 8))))
                    (:mousewheel (:window-id id :y wy)
                      (let ((v (view id)))
                        (when v
                          (multiple-value-bind (mx my) (sdl2:mouse-state)
                            (when (eq (dispatch v (list :type :wheel :x mx :y my
                                                        :delta-y (* -100 wy)))
                                      :frame)
                              (refresh v))))))
                    (:mousebuttondown (:window-id id :button button :x x :y y)
                      (let ((v (view id)))
                        (when (and v (= button 1))
                          (setf (view-dragging v) t (view-moved v) nil
                                (view-press-x v) x (view-press-y v) y)
                          (dispatch v (list :type :mousedown :x x :y y :shift (%shift-p) :button 0)))))
                    (:mousemotion (:window-id id :x x :y y)
                      (let ((v (view id)))
                        (when v
                          (when (and (view-dragging v)
                                     (or (> (abs (- x (view-press-x v))) 2)
                                         (> (abs (- y (view-press-y v))) 2)))
                            (setf (view-moved v) t))
                          (case (dispatch v (list :type :mousemove :x x :y y))
                            (:frame (refresh v))
                            (:coords (%update-title v x y))))))
                    (:mousebuttonup (:window-id id :button button :x x :y y)
                      (let ((v (view id)))
                        (when (and v (= button 1))
                          (setf (view-dragging v) nil)
                          (dispatch v (list :type :mouseup))
                          (unless (view-moved v)
                            (when (eq (dispatch v (list :type :click :x x :y y :shift (%shift-p)))
                                      :frame)
                              (refresh v))))))
                    (:keydown (:window-id id :keysym keysym)
                      (let ((v (view id))
                            (name (%key-name keysym)))
                        (cond
                          ((or (null v) (null name)))
                          ((string= name "s") (%save-frame (%view-interactor v)))
                          ((string= name "q")
                           (mpl.show:wm-close (mpl.show:figure-window-id (view-window v))))
                          (t (multiple-value-bind (mx my) (sdl2:mouse-state)
                               (case (dispatch v (list :type :keydown :key name
                                                       :ctrl (%ctrl-p) :shift (%shift-p)
                                                       :x mx :y my))
                                 (:frame
                                  ;; a paste may have landed in another figure
                                  (loop for other being the hash-values of *views*
                                        do (refresh other)))
                                 (:coords (%update-title v mx my))))))))
                    (:windowevent (:window-id id :event event)
                      (let ((v (view id)))
                        (when v
                          (cond ((= event +windowevent-close+)
                                 (mpl.show:wm-close (mpl.show:figure-window-id (view-window v))))
                                ((= event +windowevent-focus-gained+)
                                 (mpl.show:wm-activate (mpl.show:figure-window-id (view-window v))))
                                ((= event +windowevent-size-changed+)
                                 (%sync-size v))))))
                    (:quit () t))))
           (dolist (view (loop for view being the hash-values of *views* collect view))
             (%close-view view))
           (clrhash *views*)))
    (mpl.show:wm-remove-listener #'%wm-listener)
    (bt:with-lock-held (*loop-lock*)
      (setf *loop-running-p* nil))))

(defun %start-worker ()
  "Run the loop on a worker thread until every window is closed."
  (bt:make-thread (lambda ()
                    (handler-case (run-sdl2-show-loop)
                      (error (e)
                        (format *error-output* "~&; show-sdl2 loop died: ~A~%" e))))
                  :name "mpl-show-sdl2"))

;;; ============================================================
;;; The :sdl2 adapter
;;; ============================================================

(defclass sdl2-show-adapter () ()
  (:documentation "Native SDL2 window backend: one window per figure on
one event loop. Available when a display (or SDL_VIDEODRIVER, e.g.
dummy) is present; preferred over :web by :auto when both are loaded."))

(defmethod mpl.show:show-figure ((adapter sdl2-show-adapter) figure &key block)
  "Open FIGURE in an SDL2 window (its window-manager window). With BLOCK
return when that window closes; the loop runs in the calling thread if
it is not running yet (required on macOS from the initial thread), else
on the worker that already drives the other windows."
  (let ((window (mpl.show:wm-register figure)))
    (cond ((loop-running-p)
           (when block (mpl.show:wm-wait-closed window)))
          (block
           (run-sdl2-show-loop :stop-fn (lambda () (mpl.show:figure-window-closed-p window)))
           ;; other windows are still open: keep them alive on a worker
           (when (mpl.show:wm-windows) (%start-worker)))
          (t (%start-worker)))
    window))

(defun %display-available-p ()
  (flet ((set-p (name)
           (let ((v (uiop:getenv name)))
             (and v (plusp (length v))))))
    (or (set-p "DISPLAY") (set-p "WAYLAND_DISPLAY") (set-p "SDL_VIDEODRIVER"))))

(defvar *sdl2-adapter* (make-instance 'sdl2-show-adapter))

(mpl.show:register-show-adapter :sdl2 (lambda () *sdl2-adapter*)
                                :available-fn #'%display-available-p
                                :priority 20)
