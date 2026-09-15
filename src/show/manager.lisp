;;;; manager.lisp — the window manager: the set of figures on display.
;;;;
;;;; Every (show) registers its figure here as a figure-window with an
;;;; id, a title and an interactor; backends render windows and route
;;;; input to them but do not own the list. Listeners (a web page's tab
;;;; bar, later an SDL2 window per figure) are told when windows are
;;;; added, removed, activated or changed, so a figure shown from the
;;;; REPL appears everywhere at once. The active window is the paste
;;;; target and becomes pyplot's current figure.

(in-package #:cl-matplotlib.show)

(defstruct figure-window
  id
  title
  figure
  interactor
  (created-at (get-universal-time))
  (lock (bt:make-lock "figure-window"))
  (cv (bt:make-condition-variable))
  (closed-p nil))

(defclass window-manager ()
  ((lock :initform (bt:make-lock "window-manager") :reader %wm-lock)
   (windows :initform nil :accessor %wm-windows
            :documentation "figure-windows in creation order.")
   (active-id :initform nil :accessor %wm-active-id)
   (counter :initform 0 :accessor %wm-counter)
   (listeners :initform nil :accessor %wm-listeners
              :documentation "Functions of (event window): event is :added :removed :activated or :changed.")))

(defvar *wm* (make-instance 'window-manager)
  "The window manager shared by every display backend.")

(defun %wm-notify (event window)
  "Call the listeners outside the lock (they may render or block)."
  (dolist (fn (%wm-listeners *wm*))
    (handler-case (funcall fn event window)
      (error (e)
        (format *error-output* "~&; window-manager listener error (~A): ~A~%" event e)))))

(defun %default-title (figure id)
  (let ((n (ignore-errors (mpl.pyplot:figure-number figure))))
    (format nil "Figure ~D" (or n id))))

(defun wm-window-for-figure (figure)
  "The window showing FIGURE, or NIL."
  (bt:with-lock-held ((%wm-lock *wm*))
    (find figure (%wm-windows *wm*) :key #'figure-window-figure)))

(defun wm-register (figure &key title)
  "Register FIGURE as a window (or return its existing window). The new
window becomes active. Listeners get :added then :activated."
  (let ((existing (wm-window-for-figure figure))
        (window nil))
    (if existing
        (setf window existing)
        (bt:with-lock-held ((%wm-lock *wm*))
          (let ((id (incf (%wm-counter *wm*))))
            (setf window (make-figure-window :id id
                                             :title (or title (%default-title figure id))
                                             :figure figure
                                             :interactor (make-interactor figure)))
            (setf (%wm-windows *wm*) (append (%wm-windows *wm*) (list window))))))
    (unless existing (%wm-notify :added window))
    (wm-activate (figure-window-id window))
    window))

(defun wm-windows ()
  "The windows in creation order."
  (bt:with-lock-held ((%wm-lock *wm*))
    (copy-list (%wm-windows *wm*))))

(defun wm-find (id)
  "The window with ID, or NIL."
  (bt:with-lock-held ((%wm-lock *wm*))
    (find id (%wm-windows *wm*) :key #'figure-window-id)))

(defun wm-active-window ()
  (bt:with-lock-held ((%wm-lock *wm*))
    (let ((id (%wm-active-id *wm*)))
      (and id (find id (%wm-windows *wm*) :key #'figure-window-id)))))

(defun wm-activate (id)
  "Make window ID active — also pyplot's current figure — and notify
:activated. Returns the window, or NIL for an unknown id."
  (let ((window (wm-find id)))
    (when window
      (bt:with-lock-held ((%wm-lock *wm*))
        (setf (%wm-active-id *wm*) id))
      (let ((n (ignore-errors (mpl.pyplot:figure-number (figure-window-figure window)))))
        (when n (setf mpl.pyplot:*current-figure* n)))
      (%wm-notify :activated window)
      window)))

(defun wm-close (id)
  "Remove window ID: wake anyone blocked on it, notify :removed, and if
it was active make the most recent remaining window active. Returns the
window, or NIL."
  (let ((window nil) (next nil))
    (bt:with-lock-held ((%wm-lock *wm*))
      (setf window (find id (%wm-windows *wm*) :key #'figure-window-id))
      (when window
        (setf (%wm-windows *wm*) (remove window (%wm-windows *wm*)))
        (when (eql (%wm-active-id *wm*) id)
          (setf next (car (last (%wm-windows *wm*)))
                (%wm-active-id *wm*) (and next (figure-window-id next))))))
    (when window
      (bt:with-lock-held ((figure-window-lock window))
        (setf (figure-window-closed-p window) t)
        (bt:condition-notify (figure-window-cv window)))
      (%wm-notify :removed window)
      (when next (%wm-notify :activated next)))
    window))

(defun wm-close-all ()
  (dolist (w (wm-windows)) (wm-close (figure-window-id w)))
  (values))

(defun wm-wait-closed (window)
  "Block until WINDOW is closed."
  (bt:with-lock-held ((figure-window-lock window))
    (loop until (figure-window-closed-p window)
          do (bt:condition-wait (figure-window-cv window) (figure-window-lock window))))
  (values))

(defun wm-notify-changed (figure)
  "Tell listeners the figure's window needs a fresh frame (an edit, a
paste from another window, ...)."
  (let ((window (wm-window-for-figure figure)))
    (when window (%wm-notify :changed window))
    window))

(defun wm-add-listener (fn)
  "Register FN, a function of (event window). Returns FN."
  (bt:with-lock-held ((%wm-lock *wm*))
    (pushnew fn (%wm-listeners *wm*)))
  fn)

(defun wm-remove-listener (fn)
  (bt:with-lock-held ((%wm-lock *wm*))
    (setf (%wm-listeners *wm*) (remove fn (%wm-listeners *wm*))))
  (values))

;;; pyplot's (close-figure) closes the figure's window too.
(setf mpl.pyplot:*close-figure-hook*
      (lambda (figures)
        (dolist (fig figures)
          (let ((w (wm-window-for-figure fig)))
            (when w (wm-close (figure-window-id w)))))))
