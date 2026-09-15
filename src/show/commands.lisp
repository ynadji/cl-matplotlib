;;;; commands.lisp — the trace clipboard and undoable edits.
;;;;
;;;; A trace is a backend-independent copy of a line: its data and style,
;;;; detached from any axes, so it can be pasted into another axes or
;;;; another figure. Every edit (paste, delete, visibility toggle) is a
;;;; command with do/undo closures pushed on the interactor's history;
;;;; undo pops it, redo replays it.

(in-package #:cl-matplotlib.show)

;;; ============================================================
;;; Traces
;;; ============================================================

(defstruct (plot-trace (:conc-name trace-))
  "A copy of a line's data and style. (Named plot-trace: TRACE is a
standard CL symbol.)"
  (kind :line-2d)          ; :line-2d or :line-3d
  xdata ydata zdata
  label color linewidth linestyle marker markersize markerfacecolor markeredgecolor
  alpha zorder)

(defvar *trace-clipboard* nil
  "The last copied traces (a list), shared by every interactor and
figure so a trace can be pasted across windows.")

(defun trace-from-artist (artist)
  "A trace copying ARTIST (a line-2d or line-3d), or NIL for other artists."
  (when (typep artist 'mpl.rendering:line-2d)
    (let ((3d (typep artist 'mpl.rendering:line-3d)))
      (make-plot-trace
       :kind (if 3d :line-3d :line-2d)
       :xdata (coerce (if 3d (mpl.rendering:line-3d-xs artist) (mpl.rendering:line-2d-xdata artist)) 'list)
       :ydata (coerce (if 3d (mpl.rendering:line-3d-ys artist) (mpl.rendering:line-2d-ydata artist)) 'list)
       :zdata (when 3d (coerce (mpl.rendering:line-3d-zs artist) 'list))
       :label (mpl.rendering:artist-label artist)
       :color (mpl.rendering:line-2d-color artist)
       :linewidth (mpl.rendering:line-2d-linewidth artist)
       :linestyle (mpl.rendering:line-2d-linestyle artist)
       :marker (mpl.rendering:line-2d-marker artist)
       :markersize (mpl.rendering:line-2d-markersize artist)
       :markerfacecolor (mpl.rendering:line-2d-markerfacecolor artist)
       :markeredgecolor (mpl.rendering:line-2d-markeredgecolor artist)
       :alpha (mpl.rendering:artist-alpha artist)
       :zorder (mpl.rendering:artist-zorder artist)))))

(defun %style-initargs (trace)
  (append (list :color (trace-color trace)
                :linewidth (trace-linewidth trace)
                :linestyle (trace-linestyle trace)
                :marker (trace-marker trace)
                :label (or (trace-label trace) "")
                :zorder (trace-zorder trace))
          (when (trace-markersize trace) (list :markersize (trace-markersize trace)))
          (when (trace-markerfacecolor trace) (list :markerfacecolor (trace-markerfacecolor trace)))
          (when (trace-markeredgecolor trace) (list :markeredgecolor (trace-markeredgecolor trace)))
          (when (trace-alpha trace) (list :alpha (trace-alpha trace)))))

(defun trace-instantiate (trace axes)
  "Create a new line from TRACE on AXES (a 3D trace on a 2D axes drops
its z, a 2D trace on a 3D axes gets z = 0), add it and autoscale.
Returns the new artist."
  (let* ((3d-axes (typep axes 'mpl.containers:axes-3d))
         (line (if 3d-axes
                   (apply #'mpl.rendering:make-line-3d
                          (trace-xdata trace) (trace-ydata trace)
                          (or (trace-zdata trace) (make-list (length (trace-xdata trace)) :initial-element 0.0d0))
                          (%style-initargs trace))
                   (apply #'make-instance 'mpl.rendering:line-2d
                          :xdata (trace-xdata trace) :ydata (trace-ydata trace)
                          (%style-initargs trace)))))
    (setf (mpl.rendering:artist-transform line) (mpl.containers:axes-base-trans-data axes))
    (mpl.containers:axes-add-line axes line)
    (if 3d-axes
        (mpl.containers:axes-3d-auto-scale-xyz axes (trace-xdata trace) (trace-ydata trace)
                                               (or (trace-zdata trace) '(0.0d0)))
        (progn
          (mpl.containers:axes-update-datalim axes (trace-xdata trace) (trace-ydata trace))
          (mpl.containers:axes-autoscale-view axes)))
    line))

;;; ============================================================
;;; Commands and history
;;; ============================================================

(defstruct command
  "An undoable edit: DO-FN performs it (also used for redo), UNDO-FN reverts it."
  label do-fn undo-fn)

(defun %run-command (it command)
  "Perform COMMAND and record it; clears the redo stack."
  (funcall (command-do-fn command))
  (push command (%interactor-history it))
  (setf (%interactor-redo it) nil)
  (setf (mpl.rendering:artist-stale (interactor-figure it)) t)
  command)

(defun interactor-can-undo-p (it) (not (null (%interactor-history it))))
(defun interactor-can-redo-p (it) (not (null (%interactor-redo it))))

(defun interactor-undo (it)
  "Undo the most recent edit. Returns its label, or NIL when nothing to undo."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((command (pop (%interactor-history it))))
      (when command
        (funcall (command-undo-fn command))
        (push command (%interactor-redo it))
        (command-label command)))))

(defun interactor-redo (it)
  "Redo the most recently undone edit. Returns its label, or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((command (pop (%interactor-redo it))))
      (when command
        (funcall (command-do-fn command))
        (push command (%interactor-history it))
        (command-label command)))))

;;; ============================================================
;;; Copy / cut / paste / delete / toggle
;;; ============================================================

(defun %artist-axes (artist)
  (mpl.rendering:artist-axes artist))

(defun %remove-artist-command (it artist label)
  "A command removing ARTIST from its axes; undo puts it back."
  (let* ((axes (%artist-axes artist))
         (lines-before (copy-list (mpl.containers:axes-base-lines axes)))
         (artists-before (copy-list (mpl.containers:axes-base-artists axes))))
    (make-command
     :label label
     :do-fn (lambda ()
              (mpl.containers:axes-remove-artist axes artist)
              (when (eq (interactor-selection it) artist)
                (setf (interactor-selection it) nil))
              (setf (interactor-pins it)
                    (remove artist (interactor-pins it) :key #'first)))
     :undo-fn (lambda ()
                ;; restore the original list order so drawing order is kept
                (setf (mpl.containers:axes-base-lines axes) (copy-list lines-before)
                      (mpl.containers:axes-base-artists axes) (copy-list artists-before))
                (setf (mpl.rendering:artist-stale axes) t)))))

(defun interactor-copy (it)
  "Copy the selected trace to *trace-clipboard*. Returns the trace, or NIL."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((trace (trace-from-artist (interactor-selection it))))
      (when trace (setf *trace-clipboard* (list trace)))
      trace)))

(defun interactor-delete (it)
  "Delete the selected trace (undoable). Returns T when something was deleted."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((sel (interactor-selection it)))
      (when (and sel (%artist-axes sel))
        (%run-command it (%remove-artist-command it sel "delete trace"))
        t))))

(defun interactor-cut (it)
  "Copy the selected trace to the clipboard, then delete it (undoable)."
  (and (interactor-copy it) (interactor-delete it)))

(defun interactor-paste (it &optional axes)
  "Paste the clipboard's traces into AXES (default: the figure's first
axes) as new lines (undoable). Returns the new artists."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((axes (or axes (first (mpl.containers:figure-axes (interactor-figure it)))))
          (traces *trace-clipboard*)
          (created nil))
      (when (and axes traces)
        (%run-command
         it
         (make-command
          :label "paste trace"
          :do-fn (lambda ()
                   (setf created (mapcar (lambda (tr) (trace-instantiate tr axes)) traces))
                   (setf (interactor-selection it) (first created)))
          :undo-fn (lambda ()
                     (dolist (a created) (mpl.containers:axes-remove-artist axes a))
                     (when (member (interactor-selection it) created)
                       (setf (interactor-selection it) nil)))))
        created))))

(defun interactor-toggle-visible (it artist)
  "Toggle ARTIST's visibility (undoable) — what clicking its legend entry does."
  (bt:with-lock-held ((%interactor-lock it))
    (let ((was (mpl.rendering:artist-visible artist)))
      (%run-command
       it
       (make-command
        :label (if was "hide trace" "show trace")
        :do-fn (lambda () (setf (mpl.rendering:artist-visible artist) (not was)))
        :undo-fn (lambda () (setf (mpl.rendering:artist-visible artist) was))))
      (not was))))
