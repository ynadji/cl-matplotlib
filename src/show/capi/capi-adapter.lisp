;;;; capi-adapter.lisp — LispWorks CAPI display backend.
;;;;
;;;; BEST-EFFORT, UNVALIDATED: written without a LispWorks environment
;;;; (CAPI is proprietary). The structure follows the same interactor
;;;; protocol as the web and SDL2 adapters; expect to touch the
;;;; input-model gesture specs and the image path when first running it.
;;;;
;;;; Frames arrive as PNG octets and are decoded by CAPI itself
;;;; (gp:external-image :data), which sidesteps platform byte-order
;;;; questions entirely. If per-frame PNG decode is too slow on your
;;;; machine, switch to render-figure-to-rgba +
;;;; gp:image-access-pixels-from-bgra (needs an RGBA→BGRA shuffle).

(defpackage #:cl-matplotlib.show.capi
  (:use #:cl)
  (:nicknames #:mpl.show.capi)
  (:export #:capi-show-adapter #:figure-viewer))

(in-package #:cl-matplotlib.show.capi)

#-lispworks
(eval-when (:compile-toplevel :load-toplevel :execute)
  (error "cl-matplotlib-show-capi requires LispWorks (CAPI)."))

#+lispworks
(progn

(defvar +zoom-per-notch+ 1.1d0)

(capi:define-interface figure-viewer ()
  ((interactor :initarg :interactor :reader viewer-interactor)
   (dragging :initform nil :accessor viewer-dragging)
   (close-lock :initform (mp:make-lock) :reader viewer-close-lock)
   (close-flag :initform (mp:make-condition-variable) :reader viewer-close-flag)
   (closed-p :initform nil :accessor viewer-closed-p))
  (:panes
   (toolbar capi:push-button-panel
            :items '("Home" "Save")
            :callback-type :interface-data
            :selection-callback 'viewer-toolbar)
   (coords capi:title-pane :text "" :visible-min-width '(:character 30))
   (canvas capi:output-pane
           :display-callback 'viewer-display
           :resize-callback 'viewer-resize
           :input-model '(((:button-1 :press) viewer-press)
                          ((:button-1 :release) viewer-release)
                          ((:motion) viewer-motion)
                          ;; wheel gestures: adjust for your LispWorks
                          ;; version if these specs don't take
                          ((:gesture-spec :wheel-up) viewer-wheel-up)
                          ((:gesture-spec :wheel-down) viewer-wheel-down))
           :visible-min-width 640
           :visible-min-height 480))
  (:layouts
   (bar capi:row-layout '(toolbar nil coords))
   (main capi:column-layout '(bar canvas)))
  (:default-initargs
   :title "cl-matplotlib"
   :destroy-callback 'viewer-destroyed))

(defun %redraw (viewer)
  (gp:invalidate-rectangle (slot-value viewer 'canvas)))

(defun viewer-display (pane x y width height)
  (declare (ignore x y width height))
  (let* ((viewer (capi:element-interface pane))
         (png (mpl.show:interactor-render-png (viewer-interactor viewer)))
         (ext (make-instance 'gp:external-image :data png :type :png))
         (image (gp:convert-external-image pane ext)))
    (unwind-protect
         (gp:draw-image pane image 0 0)
      (gp:free-image pane image))))

(defun viewer-resize (pane x y width height)
  (declare (ignore x y))
  (let ((viewer (capi:element-interface pane)))
    (mpl.show:interactor-resize (viewer-interactor viewer) width height)
    (%redraw viewer)))

(defun viewer-press (pane x y)
  (let ((viewer (capi:element-interface pane)))
    (setf (viewer-dragging viewer) t)
    (mpl.show:interactor-pan-start (viewer-interactor viewer) x y)))

(defun viewer-release (pane x y)
  (declare (ignore x y))
  (let ((viewer (capi:element-interface pane)))
    (setf (viewer-dragging viewer) nil)
    (mpl.show:interactor-pan-end (viewer-interactor viewer))))

(defun viewer-motion (pane x y)
  (let ((viewer (capi:element-interface pane)))
    (if (viewer-dragging viewer)
        (when (mpl.show:interactor-pan-move (viewer-interactor viewer) x y)
          (%redraw viewer))
        (multiple-value-bind (dx dy)
            (mpl.show:interactor-cursor-coords (viewer-interactor viewer) x y)
          (setf (capi:title-pane-text (slot-value viewer 'coords))
                (if dx (format nil "x=~,6G  y=~,6G" dx dy) ""))))))

(defun %wheel (pane direction)
  (let ((viewer (capi:element-interface pane)))
    (multiple-value-bind (x y) (capi:current-pointer-position :relative-to pane)
      (when (mpl.show:interactor-zoom (viewer-interactor viewer) x y
                                      (if (eq direction :in)
                                          +zoom-per-notch+
                                          (/ 1.0d0 +zoom-per-notch+)))
        (%redraw viewer)))))

(defun viewer-wheel-up (pane x y gesture-spec)
  (declare (ignore x y gesture-spec))
  (%wheel pane :in))

(defun viewer-wheel-down (pane x y gesture-spec)
  (declare (ignore x y gesture-spec))
  (%wheel pane :out))

(defun viewer-toolbar (viewer item)
  (cond
    ((string= item "Home")
     (mpl.show:interactor-reset (viewer-interactor viewer))
     (%redraw viewer))
    ((string= item "Save")
     (multiple-value-bind (path okp)
         (capi:prompt-for-file "Save figure as PNG"
                               :operation :save
                               :filter "*.png")
       (when okp
         (mpl.containers:savefig
          (mpl.show:interactor-figure (viewer-interactor viewer))
          (namestring path)))))))

(defun viewer-destroyed (viewer)
  (mp:with-lock ((viewer-close-lock viewer))
    (setf (viewer-closed-p viewer) t)
    (mp:condition-variable-broadcast (viewer-close-flag viewer))))

;;; ============================================================
;;; The :capi adapter
;;; ============================================================

(defclass capi-show-adapter () ())

(defmethod mpl.show:show-figure ((adapter capi-show-adapter) figure &key block)
  (let ((viewer (make-instance 'figure-viewer
                               :interactor (mpl.show:make-interactor figure))))
    (capi:display viewer)
    (when block
      (mp:with-lock ((viewer-close-lock viewer))
        (loop until (viewer-closed-p viewer)
              do (mp:condition-variable-wait (viewer-close-flag viewer)
                                             (viewer-close-lock viewer)))))
    viewer))

(defvar *capi-adapter* (make-instance 'capi-show-adapter))

(mpl.show:register-show-adapter :capi (lambda () *capi-adapter*)
                                :priority 30)

) ; #+lispworks
