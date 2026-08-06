;;;; components.lisp — grammar component classes, folding, and stack/++

(in-package #:ggplot)

;;; ============================================================
;;; Component base classes
;;; ============================================================

(defclass geom () ()
  (:documentation "Base class for geometric objects."))

(defclass stat () ()
  (:documentation "Base class for statistical transformations."))

(defclass ggposition () ()
  (:documentation "Base class for position adjustments."))

(defclass scale ()
  ((aesthetics :initarg :aesthetics :reader scale-aesthetics
               :documentation "List of aesthetic keywords this scale governs.")
   (name    :initarg :name    :initform nil :accessor scale-name)
   (breaks  :initarg :breaks  :initform :auto :accessor scale-user-breaks)
   (labels  :initarg :labels  :initform :auto :accessor scale-user-labels)
   (limits  :initarg :limits  :initform nil :accessor scale-user-limits)
   (expand  :initarg :expand  :initform nil :accessor scale-user-expand)
   (guide   :initarg :guide   :initform :auto :accessor scale-guide))
  (:documentation "Base class for scales."))

(defclass coord () ()
  (:documentation "Base class for coordinate systems."))

(defclass facet () ()
  (:documentation "Base class for faceting specifications."))

(defclass ggtheme ()
  ((elements :initarg :elements
             :initform (make-hash-table :test #'eq)
             :reader theme-elements))
  (:documentation "A theme: a table of element name -> element value.
Partial themes merge; complete themes replace unset elements with defaults."))

(defclass labs-spec ()
  ((alist :initarg :alist :initform '() :reader labs-alist)))

(defclass layer ()
  ((geom     :initarg :geom     :reader layer-geom)
   (stat     :initarg :stat     :reader layer-stat)
   (position :initarg :position :reader layer-position)
   (mapping  :initarg :mapping  :initform nil :reader layer-mapping)
   (data     :initarg :data     :initform nil :reader layer-data)
   (params   :initarg :params   :initform '() :reader layer-params
             :documentation "Plist of fixed (unmapped) aesthetics and options.")
   (show-legend :initarg :show-legend :initform :auto :reader layer-show-legend)
   (inherit-aes :initarg :inherit-aes :initform t :reader layer-inherit-aes))
  (:documentation "One layer: geom + stat + position + layer-specific data/mapping."))

;;; ============================================================
;;; The plot object
;;; ============================================================

(defclass ggplot ()
  ((data    :initarg :data    :initform nil :reader plot-data)
   (mapping :initarg :mapping :initform nil :reader plot-mapping)
   (layers  :initarg :layers  :initform '() :reader plot-layers)
   (scales  :initarg :scales  :initform '() :reader plot-scales)
   (coord   :initarg :coord   :initform nil :reader plot-coord)
   (facet   :initarg :facet   :initform nil :reader plot-facet)
   (theme   :initarg :theme   :initform nil :reader plot-theme)
   (labs    :initarg :labs    :initform '() :reader plot-labs))
  (:documentation "A declarative plot specification. Immutable: ggadd and
stack/++ return new plots."))

(defmethod print-object ((p ggplot) stream)
  (print-unreadable-object (p stream :type t)
    (format stream "~D layer~:P~@[ facet~*~]~@[ theme~*~]"
            (length (plot-layers p)) (plot-facet p) (plot-theme p))))

(defun copy-ggplot (plot &rest overrides)
  "Shallow copy of PLOT with slot OVERRIDES (initarg-style plist)."
  (apply #'make-instance 'ggplot
         (append overrides
                 (list :data (plot-data plot)
                       :mapping (plot-mapping plot)
                       :layers (plot-layers plot)
                       :scales (plot-scales plot)
                       :coord (plot-coord plot)
                       :facet (plot-facet plot)
                       :theme (plot-theme plot)
                       :labs (plot-labs plot)))))

;;; ============================================================
;;; Folding — ggadd
;;; ============================================================

(defgeneric ggadd (plot component)
  (:documentation "Return a NEW ggplot with COMPONENT folded into PLOT.
Never mutates PLOT. This is what stack/++ reduce over; specialize it to
teach gg about new component types."))

(defmethod ggadd ((plot ggplot) (component layer))
  (copy-ggplot plot :layers (append (plot-layers plot) (list component))))

(defmethod ggadd ((plot ggplot) (component scale))
  (let ((existing (remove-if-not
                   (lambda (s)
                     (intersection (scale-aesthetics s)
                                   (scale-aesthetics component)))
                   (plot-scales plot))))
    (when existing
      (warn "Scale for ~{~(~A~)~^, ~} is already present; replacing it."
            (scale-aesthetics component)))
    (copy-ggplot plot :scales (append (set-difference (plot-scales plot) existing)
                                      (list component)))))

(defmethod ggadd ((plot ggplot) (component coord))
  (copy-ggplot plot :coord component))

(defmethod ggadd ((plot ggplot) (component facet))
  (copy-ggplot plot :facet component))

(defmethod ggadd ((plot ggplot) (component ggtheme))
  (copy-ggplot plot :theme (merge-themes (plot-theme plot) component)))

(defmethod ggadd ((plot ggplot) (component labs-spec))
  (copy-ggplot plot :labs (append (labs-alist component)
                                  (remove-if (lambda (e)
                                               (assoc (car e) (labs-alist component)))
                                             (plot-labs plot)))))

(defmethod ggadd ((plot ggplot) (component list))
  ;; Lets helper functions return several components at once (e.g. lims)
  (reduce #'ggadd component :initial-value plot))

(defmethod ggadd ((plot ggplot) (component null))
  ;; NIL components are no-ops, enabling conditional layers:
  ;;   (stack p (when interactive-p (geom-point)))
  plot)

;;; ============================================================
;;; stack / ++ — the layer-addition operator
;;; ============================================================

(defmacro stack (plot &body components)
  "Fold grammar COMPONENTS onto PLOT, returning a new plot.
gg's analogue of ggplot2's `+`:

  (stack (ggplot data (aes :x :wt :y :mpg))
    (geom-point)
    (labs :title \"MPG vs Weight\"))

A macro (not a function) so COMPONENTS sit at body indentation and every
layer aligns."
  `(reduce #'ggadd (list ,@components) :initial-value ,plot))
