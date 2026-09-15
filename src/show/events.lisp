;;;; events.lisp — one event protocol for every display backend.
;;;;
;;;; Backends (web, SDL2, ...) translate their native input into plist
;;;; events and hand them to INTERACTOR-HANDLE-EVENT; all interaction
;;;; semantics — pan vs rotate, picking, the keyboard map, the clipboard —
;;;; live here, so every backend behaves the same and the browser client
;;;; stays a dumb terminal.
;;;;
;;;; Event plist: (:type TYPE :x px :y py :delta-y n :w n :h n :key "c"
;;;; :ctrl bool :shift bool :button n). TYPE is one of :wheel :mousedown
;;;; :mousemove :mouseup :click :dblclick :keydown :resize :home :save.
;;;; Pixels have the top-left origin. The result tells the backend what
;;;; to send: :frame (re-render), :coords (cursor readout changed), or NIL.

(in-package #:cl-matplotlib.show)

(defparameter *key-bindings*
  '(("h" nil nil :home)
    ("c" nil nil :toggle-cursor-mode)
    ("Escape" nil nil :clear)
    ("c" t nil :copy)
    ("x" t nil :cut)
    ("v" t nil :paste)
    ("Delete" nil nil :delete)
    ("Backspace" nil nil :delete)
    ("z" t nil :undo)
    ("z" t t :redo)
    ("Z" t t :redo)
    ("y" t nil :redo))
  "Keyboard map: (key ctrl shift action). KEY is the browser KeyboardEvent.key
name; SDL2 maps its scancodes onto the same names.")

(defun %key-action (key ctrl shift)
  (fourth (find-if (lambda (b)
                     (and (string= (first b) key)
                          (eq (not (null (second b))) (not (null ctrl)))
                          (eq (not (null (third b))) (not (null shift)))))
                   *key-bindings*)))

(defun %wheel-factor (delta-y)
  "Map a browser wheel deltaY (≈ ±100 per notch, positive = away/down)
to a cursor-anchored zoom factor: one notch toward the user = 1.1x in."
  (expt 1.1d0 (/ (- (float (or delta-y 0) 1.0d0)) 100.0d0)))

(defun %click (it x y)
  "A click: a legend entry toggles its series; in cursor mode a nearby
vertex is pinned; otherwise the trace under the cursor is selected (or
the selection cleared)."
  (let ((handle (interactor-legend-hit it x y)))
    (cond (handle
           (interactor-toggle-visible it handle)
           :frame)
          ((eq (interactor-mode it) :cursor)
           (multiple-value-bind (artist index) (interactor-nearest-point it x y)
             (when artist
               (interactor-pin-point it artist index)
               :frame)))
          (t
           (let ((picked (interactor-pick it x y)))
             (interactor-select it picked)
             :frame)))))

(defun %keydown (it key ctrl shift x y)
  (case (%key-action key ctrl shift)
    (:home (interactor-reset it) :frame)
    (:toggle-cursor-mode
     (setf (interactor-mode it) (if (eq (interactor-mode it) :cursor) :pan :cursor))
     :coords)
    (:clear
     (interactor-clear-selection it)
     (interactor-clear-pins it)
     :frame)
    (:copy (interactor-copy it) nil)
    (:cut (when (interactor-cut it) :frame))
    (:paste
     (let ((ax (and x y (interactor-hit-axes it x y))))
       (when (interactor-paste it ax) :frame)))
    (:delete (when (interactor-delete it) :frame))
    (:undo (when (interactor-undo it) :frame))
    (:redo (when (interactor-redo it) :frame))
    (t nil)))

(defun interactor-handle-event (it event)
  "Apply EVENT (a plist, see the file header) to IT. Returns :frame,
:coords or NIL."
  (let ((type (getf event :type))
        (x (getf event :x))
        (y (getf event :y)))
    (case type
      (:wheel
       (when (interactor-zoom it x y (%wheel-factor (getf event :delta-y)))
         :frame))
      (:mousedown
       (interactor-pan-start it x y :shift (getf event :shift))
       nil)
      (:mousemove
       (if (interactor-pan-move it x y)
           :frame
           :coords))
      (:mouseup
       (interactor-pan-end it)
       nil)
      (:click (%click it x y))
      ((:dblclick :home)
       (interactor-reset it)
       :frame)
      (:keydown
       (%keydown it (getf event :key) (getf event :ctrl) (getf event :shift) x y))
      (:resize
       (let ((w (getf event :w)) (h (getf event :h)))
         (when (and w h (> w 10) (> h 10))
           (interactor-resize it (round w) (round h))
           :frame)))
      (t nil))))
