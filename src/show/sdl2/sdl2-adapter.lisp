;;;; sdl2-adapter.lisp — native window display backend via SDL2.
;;;;
;;;; Frames are the interactor's RGBA buffers uploaded into a streaming
;;;; texture. :abgr8888 on a little-endian machine reads bytes as
;;;; R,G,B,A — exactly zpng's layout; +texture-format+ is the single
;;;; constant to flip if a platform disagrees.
;;;;
;;;; Interaction: scroll wheel = cursor-anchored zoom, left-drag = pan,
;;;; h = home, s = save PNG in the current directory, q/Escape = close.
;;;; The cursor's data coordinates live in the window title.
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
  "Copy the lisp RGBA buffer through foreign memory into TEXTURE."
  (declare (type (simple-array (unsigned-byte 8) (*)) rgba))
  (loop for i of-type fixnum below (length rgba)
        do (setf (cffi:mem-aref fbuf :uint8 i) (aref rgba i)))
  (sdl2:update-texture texture nil fbuf (* 4 width)))

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
                (fbuf (cffi:foreign-alloc :uint8 :count (* 4 w h)))
                (dragging nil))
            (labels ((blit (buf)
                       (%upload-frame texture fbuf buf w)
                       (sdl2:render-copy renderer texture)
                       (sdl2:render-present renderer))
                     (refresh ()
                       (blit (mpl.show:interactor-render-rgba interactor)))
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
                     (sdl2:with-event-loop (:method :wait)
                       (:mousewheel (:y wy)
                         (multiple-value-bind (mx my) (sdl2:mouse-state)
                           (when (mpl.show:interactor-zoom
                                  interactor mx my (expt 1.1d0 wy))
                             (refresh))))
                       (:mousebuttondown (:button button :x x :y y)
                         (when (= button 1)
                           (setf dragging t)
                           (mpl.show:interactor-pan-start interactor x y)))
                       (:mousemotion (:x x :y y)
                         (if dragging
                             (when (mpl.show:interactor-pan-move interactor x y)
                               (refresh))
                             (multiple-value-bind (dx dy)
                                 (mpl.show:interactor-cursor-coords interactor x y)
                               (sdl2:set-window-title
                                win
                                (if dx
                                    (format nil "~A — x=~,6G y=~,6G" title dx dy)
                                    title)))))
                       (:mousebuttonup (:button button)
                         (when (= button 1)
                           (setf dragging nil)
                           (mpl.show:interactor-pan-end interactor)))
                       (:keydown (:keysym keysym)
                         (cond
                           ((sdl2:scancode= keysym :scancode-h)
                            (mpl.show:interactor-reset interactor)
                            (refresh))
                           ((sdl2:scancode= keysym :scancode-s)
                            (%save-frame interactor))
                           ((or (sdl2:scancode= keysym :scancode-q)
                                (sdl2:scancode= keysym :scancode-escape))
                            (sdl2:push-quit-event))))
                       (:windowevent (:event event)
                         (declare (ignore event))
                         (sync-size))
                       (:quit () t)))
                (cffi:foreign-free fbuf)
                (sdl2:destroy-texture texture)))))))))

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
