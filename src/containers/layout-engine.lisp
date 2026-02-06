;;;; layout-engine.lisp — Layout engines for figure layout management
;;;; Ported from matplotlib's layout_engine.py
;;;; Implements PlaceHolderLayoutEngine and TightLayoutEngine.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Layout engine protocol
;;; ============================================================

(defgeneric layout-engine-execute (engine figure)
  (:documentation "Execute layout on FIGURE. Called at draw time."))

(defgeneric layout-engine-set (engine &rest params &key &allow-other-keys)
  (:documentation "Set parameters on the layout engine."))

(defgeneric layout-engine-get (engine)
  (:documentation "Return a plist copy of the engine's parameters."))

;;; ============================================================
;;; Layout engine base class
;;; ============================================================

(defclass layout-engine ()
  ((adjust-compatible-p :initarg :adjust-compatible
                        :initform nil
                        :accessor layout-engine-adjust-compatible-p
                        :type boolean
                        :documentation "Whether this engine is compatible with subplots_adjust.")
   (colorbar-gridspec-p :initarg :colorbar-gridspec
                        :initform nil
                        :accessor layout-engine-colorbar-gridspec-p
                        :type boolean
                        :documentation "Whether colorbars use gridspec method.")
   (params :initform nil
           :accessor layout-engine-params
           :documentation "Plist of layout parameters."))
  (:documentation "Base class for layout engines. Subclasses must implement execute."))

(defmethod layout-engine-execute ((engine layout-engine) figure)
  (declare (ignore figure))
  (error "layout-engine-execute not implemented for ~A" (type-of engine)))

(defmethod layout-engine-set ((engine layout-engine) &rest params &key &allow-other-keys)
  (declare (ignore params))
  (error "layout-engine-set not implemented for ~A" (type-of engine)))

(defmethod layout-engine-get ((engine layout-engine))
  (copy-list (layout-engine-params engine)))

;;; ============================================================
;;; PlaceHolderLayoutEngine — no-op layout
;;; ============================================================

(defclass placeholder-layout-engine (layout-engine)
  ()
  (:documentation "A no-op layout engine that acts as a placeholder.
Used when a layout engine is removed to prevent incompatible engines from being set later."))

(defun make-placeholder-layout-engine (&key (adjust-compatible t) (colorbar-gridspec t))
  "Create a PlaceHolderLayoutEngine that mirrors the behavior of a removed engine."
  (make-instance 'placeholder-layout-engine
                 :adjust-compatible adjust-compatible
                 :colorbar-gridspec colorbar-gridspec))

(defmethod layout-engine-execute ((engine placeholder-layout-engine) figure)
  "Do nothing — placeholder engine."
  (declare (ignore figure))
  (values))

(defmethod layout-engine-set ((engine placeholder-layout-engine) &rest params &key &allow-other-keys)
  "PlaceHolderLayoutEngine ignores set calls."
  (declare (ignore params))
  (values))

;;; ============================================================
;;; TightLayoutEngine — auto-spacing computation
;;; ============================================================

(defclass tight-layout-engine (layout-engine)
  ()
  (:default-initargs :adjust-compatible t :colorbar-gridspec t)
  (:documentation "Implements tight_layout geometry management.
Adjusts subplot parameters so that axis labels, tick labels, and titles
don't overlap. See matplotlib's tight_layout_guide for details."))

(defun make-tight-layout-engine (&key (pad 1.08) h-pad w-pad (rect '(0 0 1 1)))
  "Create a TightLayoutEngine with the given padding parameters.

PAD — padding between figure edge and subplots (fraction of font size).
H-PAD — vertical padding between adjacent subplots (defaults to PAD).
W-PAD — horizontal padding between adjacent subplots (defaults to PAD).
RECT — (left bottom right top) normalized figure coords for subplots area."
  (let ((engine (make-instance 'tight-layout-engine)))
    (setf (layout-engine-params engine)
          (list :pad pad :h-pad h-pad :w-pad w-pad :rect rect))
    engine))

(defmethod layout-engine-execute ((engine tight-layout-engine) figure)
  "Execute tight layout on FIGURE.
Computes subplot parameters that avoid overlapping labels.
For now, this is a simplified implementation that applies default margins
since we don't yet have full Axes with tick labels."
  (declare (ignore figure))
  ;; Simplified: in a full implementation this would call
  ;; get-tight-layout-figure to compute optimal margins based on
  ;; axis labels, tick labels, and titles. For now, the figure's
  ;; existing subplot params are kept as-is since we don't have
  ;; full Axes yet.
  (values))

(defmethod layout-engine-set ((engine tight-layout-engine) &rest params
                              &key pad h-pad w-pad rect &allow-other-keys)
  "Set tight layout padding parameters."
  (declare (ignore params))
  (let ((current (layout-engine-params engine)))
    (when pad (setf (getf current :pad) pad))
    (when h-pad (setf (getf current :h-pad) h-pad))
    (when w-pad (setf (getf current :w-pad) w-pad))
    (when rect (setf (getf current :rect) rect))
    (setf (layout-engine-params engine) current)))
