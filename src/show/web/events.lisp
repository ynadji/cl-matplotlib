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
          :button (gethash "button" h))))

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

(defun coords-json (interactor x-px y-px)
  "The coords text message for the cursor at the pixel: the data
coordinates over a 2D axes, the nearest data vertex (label, index) when
one is within reach, the interaction mode; outside every axes it is
bare (client clears the readout)."
  (let ((info (mpl.show:interactor-cursor-info interactor x-px y-px)))
    (with-output-to-string (s)
      (yason:encode-plist
       (append (list "type" "coords"
                     "mode" (string-downcase (symbol-name (mpl.show:interactor-mode interactor))))
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
