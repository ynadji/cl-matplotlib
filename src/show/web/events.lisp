;;;; events.lisp — client event handling, kept pure so the FiveAM suite
;;;; covers it without a running server. The websocket layer (server.lisp)
;;;; only does: parse-event → queue → coalesce-events → apply-event.

(in-package #:cl-matplotlib.show.web)

(defun parse-event (json-string)
  "Parse a client event JSON string into the core event plist
(:type keyword :x n :y n :delta-y n :w n :h n :key string :ctrl bool
:shift bool :button n); absent fields are NIL."
  (let ((h (yason:parse json-string)))
    (list :type (let ((tp (gethash "type" h)))
                  (and tp (intern (string-upcase tp) :keyword)))
          :x (gethash "x" h)
          :y (gethash "y" h)
          :delta-y (gethash "deltaY" h)
          :w (gethash "w" h)
          :h (gethash "h" h)
          :key (gethash "key" h)
          :ctrl (eq (gethash "ctrl" h) t)
          :shift (eq (gethash "shift" h) t)
          :button (gethash "button" h)
          :fig (gethash "fig" h))))

(defun %event-type (event) (getf event :type))

(defun coalesce-events (events)
  "Collapse an event burst: consecutive mousemoves keep only the latest,
consecutive wheels merge into one with their deltas summed (at the
latest cursor position). Other events pass through in order."
  (let ((out '()))
    (dolist (ev events (nreverse out))
      (let ((prev (first out))
            (type (%event-type ev)))
        (cond
          ((and prev
                (eq type :mousemove)
                (eq (%event-type prev) :mousemove))
           (setf (first out) ev))
          ((and prev
                (eq type :wheel)
                (eq (%event-type prev) :wheel))
           (setf (first out)
                 (list :type :wheel
                       :x (getf ev :x) :y (getf ev :y)
                       :delta-y (+ (or (getf prev :delta-y) 0)
                                   (or (getf ev :delta-y) 0)))))
          (t (push ev out)))))))

(defun apply-event (interactor event)
  "Apply a parsed client EVENT to INTERACTOR through the shared
dispatcher (mpl.show:interactor-handle-event). Returns :frame, :coords
or NIL — what the connection should send next."
  (mpl.show:interactor-handle-event interactor event))

(defun coords-json (interactor x-px y-px &key fig)
  "The coords text message for the cursor at the pixel: the data
coordinates over a 2D axes, the nearest data vertex (label, index) when
one is within reach, the interaction mode; outside every axes it is
bare (client clears the readout). FIG names the window it is about."
  (let ((info (when (and x-px y-px)     ; a key event may carry no pointer
                (mpl.show:interactor-cursor-info interactor x-px y-px))))
    (with-output-to-string (s)
      (yason:encode-plist
       (append (list "type" "coords"
                     "mode" (string-downcase (symbol-name (mpl.show:interactor-mode interactor))))
               (when fig (list "fig" fig))
               (when (getf info :x)
                 (list "x" (float (getf info :x) 1.0d0)
                       "y" (float (getf info :y) 1.0d0)))
               (when (getf info :label)
                 (append (list "label" (getf info :label)
                               "index" (getf info :index)
                               "px" (float (getf info :px) 1.0d0)
                               "py" (float (getf info :py) 1.0d0))
                         (when (getf info :z) (list "pz" (float (getf info :z) 1.0d0))))))
       s))))

(defun windows-json ()
  "The tab-list message: every window's id and title, and the active id."
  (let ((active (mpl.show:wm-active-window)))
    (with-output-to-string (s)
      (yason:with-output (s)
        (yason:with-object ()
          (yason:encode-object-element "type" "windows")
          (yason:encode-object-element "active" (if active (mpl.show:figure-window-id active) :null))
          (yason:with-object-element ("items")
            (yason:with-array ()
              (dolist (w (mpl.show:wm-windows))
                (yason:with-object ()
                  (yason:encode-object-element "id" (mpl.show:figure-window-id w))
                  (yason:encode-object-element "title" (mpl.show:figure-window-title w)))))))))))

(defun frame-message (id png)
  "A binary frame for window ID: 4-byte big-endian id, then the PNG octets."
  (let ((out (make-array (+ 4 (length png)) :element-type '(unsigned-byte 8))))
    (setf (aref out 0) (ldb (byte 8 24) id)
          (aref out 1) (ldb (byte 8 16) id)
          (aref out 2) (ldb (byte 8 8) id)
          (aref out 3) (ldb (byte 8 0) id))
    (replace out png :start1 4)
    out))
