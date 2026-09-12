;;;; sdl2-adapter.lisp — native window display backend via SDL2.
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
;;;; h = home, c = cursor mode, ctrl-c/x/v = copy/cut/paste, Delete,
;;;; ctrl-z / ctrl-shift-z = undo/redo, Escape = clear selection and pins.
;;;; SDL2-only: s = save PNG in the current directory, q = close.
;;;; The cursor readout lives in the window title.
;;;;
;;;; Threading: cl-sdl2 routes window/event calls through its own main
;;;; thread channel, so show-figure :block t simply waits for the loop;
;;;; non-blocking runs it on a worker thread. On macOS call
;;;; (show ... :block t) from the initial thread (Cocoa requirement).

(defpackage #:cl-matplotlib.show.sdl2
  (:use #:cl)
  (:nicknames #:mpl.show.sdl2)
  (:export #:sdl2-show-adapter
           #:run-sdl2-show-loop))

(in-package #:cl-matplotlib.show.sdl2)

(defconstant +texture-format+ :abgr8888
  "SDL pixel format matching zpng's RGBA byte order on little-endian.")

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

(defun run-sdl2-show-loop (interactor &key (title "cl-matplotlib"))
  "Open an SDL2 window on INTERACTOR's figure and run its event loop.
Returns when the window closes."
  (multiple-value-bind (rgba w h) (mpl.show:interactor-render-rgba interactor)
    (sdl2:with-init (:video)
      (sdl2:with-window (win :title title :w w :h h
                             :flags '(:shown :resizable))
        (sdl2:with-renderer (renderer win)
          (let ((texture (sdl2:create-texture renderer +texture-format+
                                              :streaming w h))
                (fbuf (cffi:foreign-alloc :uint8 :count (* 4 w h))))
            (let ((dirty nil) (dragging nil) (moved nil) (press-x 0) (press-y 0))
            (labels ((dispatch (event)
                       (mpl.show:interactor-handle-event interactor event))
                     (mod-p (&rest names)
                       (apply #'sdl2:mod-value-p (sdl2:get-mod-state) names))
                     (ctrl-p () (mod-p :lctrl :rctrl :lgui :rgui))
                     (shift-p () (mod-p :lshift :rshift))
                     (key-name (keysym)
                       ;; the browser KeyboardEvent.key names the shared key map uses
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
                     (update-title (x y)
                       (let ((info (mpl.show:interactor-cursor-info interactor x y)))
                         (sdl2:set-window-title
                          win
                          (cond ((getf info :label)
                                 (format nil "~A — ~A[~D] x=~,6G y=~,6G~@[ z=~,6G~]" title
                                         (getf info :label) (getf info :index)
                                         (getf info :px) (getf info :py) (getf info :z)))
                                ((getf info :x)
                                 (format nil "~A — x=~,6G y=~,6G" title (getf info :x) (getf info :y)))
                                (t title)))))
                     (blit (buf)
                       (%upload-frame texture fbuf buf w)
                       (sdl2:render-copy renderer texture)
                       (sdl2:render-present renderer))
                     (refresh ()
                       ;; Deferred to the loop's idle step: a drag delivers
                       ;; many motion events per frame, and rendering once
                       ;; per event let the backlog grow ("glacial" drags).
                       (setf dirty t))
                     (flush ()
                       (when dirty
                         (setf dirty nil)
                         (blit (mpl.show:interactor-render-rgba interactor))))
                     (sync-size ()
                       ;; window size changed → re-render at the new size
                       (multiple-value-bind (ww wh) (sdl2:get-window-size win)
                         (unless (and (= ww w) (= wh h))
                           (mpl.show:interactor-resize interactor ww wh)
                           (setf w ww h wh)
                           (sdl2:destroy-texture texture)
                           (setf texture (sdl2:create-texture
                                          renderer +texture-format+
                                          :streaming w h))
                           (cffi:foreign-free fbuf)
                           (setf fbuf (cffi:foreign-alloc
                                       :uint8 :count (* 4 w h)))
                           (refresh)))))
              (unwind-protect
                   (progn
                     (blit rgba)
                     (sdl2:with-event-loop (:method :poll)
                       (:idle ()
                         (if dirty
                             (flush)
                             (sdl2:delay 8)))
                       (:mousewheel (:y wy)
                         (multiple-value-bind (mx my) (sdl2:mouse-state)
                           (when (eq (dispatch (list :type :wheel :x mx :y my
                                                     :delta-y (* -100 wy)))
                                     :frame)
                             (refresh))))
                       (:mousebuttondown (:button button :x x :y y)
                         (when (= button 1)
                           (setf dragging t moved nil press-x x press-y y)
                           (dispatch (list :type :mousedown :x x :y y :shift (shift-p) :button 0))))
                       (:mousemotion (:x x :y y)
                         (when (and dragging (or (> (abs (- x press-x)) 2) (> (abs (- y press-y)) 2)))
                           (setf moved t))
                         (case (dispatch (list :type :mousemove :x x :y y))
                           (:frame (refresh))
                           (:coords (update-title x y))))
                       (:mousebuttonup (:button button :x x :y y)
                         (when (= button 1)
                           (setf dragging nil)
                           (dispatch (list :type :mouseup))
                           (unless moved
                             (when (eq (dispatch (list :type :click :x x :y y :shift (shift-p))) :frame)
                               (refresh)))))
                       (:keydown (:keysym keysym)
                         (let ((name (key-name keysym)))
                           (cond
                             ((null name))
                             ((string= name "s") (%save-frame interactor))
                             ((string= name "q") (sdl2:push-quit-event))
                             (t (multiple-value-bind (mx my) (sdl2:mouse-state)
                                  (case (dispatch (list :type :keydown :key name
                                                        :ctrl (ctrl-p) :shift (shift-p)
                                                        :x mx :y my))
                                    (:frame (refresh))
                                    (:coords (update-title mx my))))))))
                       (:windowevent (:event event)
                         (declare (ignore event))
                         (sync-size))
                       (:quit () t)))
                (cffi:foreign-free fbuf)
                (sdl2:destroy-texture texture))))))))))

;;; ============================================================
;;; The :sdl2 adapter
;;; ============================================================

(defclass sdl2-show-adapter () ()
  (:documentation "Native SDL2 window backend. Available when a display
(or SDL_VIDEODRIVER, e.g. dummy) is present; preferred over :web by
:auto when both are loaded."))

(defmethod mpl.show:show-figure ((adapter sdl2-show-adapter) figure &key block)
  "Open FIGURE in an SDL2 window. BLOCK runs the event loop in the
calling thread (required on macOS from the initial thread); otherwise
the window runs on a worker thread."
  (let ((interactor (mpl.show:make-interactor figure)))
    (if block
        (run-sdl2-show-loop interactor)
        (bt:make-thread (lambda ()
                          (handler-case (run-sdl2-show-loop interactor)
                            (error (e)
                              (format *error-output*
                                      "~&; show-sdl2 window died: ~A~%" e))))
                        :name "mpl-show-sdl2"))))

(defun %display-available-p ()
  (flet ((set-p (name)
           (let ((v (uiop:getenv name)))
             (and v (plusp (length v))))))
    (or (set-p "DISPLAY") (set-p "WAYLAND_DISPLAY") (set-p "SDL_VIDEODRIVER"))))

(defvar *sdl2-adapter* (make-instance 'sdl2-show-adapter))

(mpl.show:register-show-adapter :sdl2 (lambda () *sdl2-adapter*)
                                :available-fn #'%display-available-p
                                :priority 20)
