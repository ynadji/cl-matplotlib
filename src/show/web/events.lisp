;;;; events.lisp — client event handling, kept pure so the FiveAM suite
;;;; covers it without a running server. The websocket layer (server.lisp)
;;;; only does: parse-event → queue → coalesce-events → apply-event.

(in-package #:cl-matplotlib.show.web)

(defun parse-event (json-string)
  "Parse a client event JSON string into a plist
(:type string :x n :y n :delta-y n :w n :h n); absent fields are NIL."
  (let ((h (yason:parse json-string)))
    (list :type (gethash "type" h)
          :x (gethash "x" h)
          :y (gethash "y" h)
          :delta-y (gethash "deltaY" h)
          :w (gethash "w" h)
          :h (gethash "h" h))))

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
                (string= type "mousemove")
                (string= (%event-type prev) "mousemove"))
           (setf (first out) ev))
          ((and prev
                (string= type "wheel")
                (string= (%event-type prev) "wheel"))
           (setf (first out)
                 (list :type "wheel"
                       :x (getf ev :x) :y (getf ev :y)
                       :delta-y (+ (or (getf prev :delta-y) 0)
                                   (or (getf ev :delta-y) 0)))))
          (t (push ev out)))))))

(defun %wheel-zoom-factor (delta-y)
  "Map a browser wheel deltaY (≈ ±100 per notch, positive = away/down)
to a cursor-anchored zoom factor: one notch toward the user = 1.1x in."
  (expt 1.1d0 (/ (- (float delta-y 1.0d0)) 100.0d0)))

(defun apply-event (interactor event)
  "Apply a parsed client EVENT to INTERACTOR.
Returns what the connection should send next:
  :frame  — state changed, push a new PNG frame
  :coords — cursor moved without dragging, push a coords update
  NIL     — nothing to send."
  (let ((type (%event-type event))
        (x (getf event :x))
        (y (getf event :y)))
    (cond
      ((string= type "wheel")
       (when (mpl.show:interactor-zoom
              interactor x y (%wheel-zoom-factor (or (getf event :delta-y) 0)))
         :frame))
      ((string= type "mousedown")
       (mpl.show:interactor-pan-start interactor x y)
       nil)
      ((string= type "mousemove")
       (if (mpl.show:interactor-pan-move interactor x y)
           :frame
           :coords))
      ((string= type "mouseup")
       (mpl.show:interactor-pan-end interactor)
       nil)
      ((string= type "home")
       (mpl.show:interactor-reset interactor)
       :frame)
      ((string= type "resize")
       (let ((w (getf event :w)) (h (getf event :h)))
         (when (and w h (> w 10) (> h 10))
           (mpl.show:interactor-resize interactor (round w) (round h))
           :frame)))
      (t nil))))

(defun coords-json (interactor x-px y-px)
  "The coords text message for the cursor at the pixel: over an axes it
carries the data coordinates, outside it is bare (client clears the
readout)."
  (multiple-value-bind (x y)
      (mpl.show:interactor-cursor-coords interactor x-px y-px)
    (with-output-to-string (s)
      (if x
          (yason:encode-plist
           (list "type" "coords"
                 "x" (float x 1.0d0)
                 "y" (float y 1.0d0))
           s)
          (yason:encode-plist (list "type" "coords") s)))))
