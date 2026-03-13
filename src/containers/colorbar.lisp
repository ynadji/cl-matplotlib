;;;; colorbar.lisp — Colorbar class for displaying color scales
;;;; Ported from matplotlib's colorbar.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Colorbar class
;;; ============================================================

(defclass mpl-colorbar (mpl.rendering:artist)
  ((colorbar-mappable :initarg :mappable
                      :initform nil
                      :accessor colorbar-mappable
                      :documentation "ScalarMappable that provides the norm + cmap.")
   (colorbar-cax :initarg :cax
                 :initform nil
                 :accessor colorbar-cax
                 :documentation "Axes to draw the colorbar into.")
   (colorbar-ax :initarg :ax
                :initform nil
                :accessor colorbar-ax
                :documentation "Parent axes that the colorbar belongs to.")
   (colorbar-orientation :initarg :orientation
                         :initform :vertical
                         :accessor colorbar-orientation
                         :documentation "Orientation: :vertical or :horizontal.")
   (colorbar-label :initarg :label
                   :initform ""
                   :accessor colorbar-label
                   :type string
                   :documentation "Colorbar label text.")
   (colorbar-ticks :initarg :ticks
                   :initform nil
                   :accessor colorbar-ticks
                   :documentation "List of tick locations, or nil for auto.")
   (colorbar-format :initarg :format
                    :initform nil
                    :accessor colorbar-format
                    :documentation "Tick label format string or formatter.")
   (colorbar-n-levels :initarg :n-levels
                      :initform 256
                      :accessor colorbar-n-levels
                      :type fixnum
                      :documentation "Number of color levels to render.")
   (colorbar-extend :initarg :extend
                    :initform :neither
                    :accessor colorbar-extend
                    :documentation "Extension arrows: :neither, :min, :max, :both."))
  (:default-initargs :zorder 4)
  (:documentation "A colorbar showing the color scale for a ScalarMappable.
Ported from matplotlib.colorbar.Colorbar."))

(defmethod initialize-instance :after ((cb mpl-colorbar) &key ax mappable)
  "Initialize colorbar: create colorbar axes if needed, compute ticks."
  (when ax
    (setf (colorbar-ax cb) ax)
    (setf (mpl.rendering:artist-figure cb) (axes-base-figure ax)))
  ;; Create colorbar axes if not provided
  (when (and ax (null (colorbar-cax cb)))
    (setf (colorbar-cax cb) (%make-colorbar-axes ax (colorbar-orientation cb))))
  ;; Auto-generate ticks if not provided
  (when (and mappable (null (colorbar-ticks cb)))
    (setf (colorbar-ticks cb)
          (%colorbar-auto-ticks cb))))

;;; ============================================================
;;; Colorbar axes creation
;;; ============================================================

(defun %make-colorbar-axes (parent-ax orientation)
  "Create a new axes for the colorbar next to PARENT-AX.
Returns the new axes-base."
  (let* ((fig (axes-base-figure parent-ax))
         (parent-pos (axes-base-position parent-ax))
         (p-left (first parent-pos))
         (p-bottom (second parent-pos))
         (p-width (third parent-pos))
         (p-height (fourth parent-pos)))
    (when fig
      ;; Shrink parent axes and create colorbar axes alongside
      (let* ((shrink-frac 0.15d0)  ; fraction of width/height for colorbar (match matplotlib fraction=0.15)
             (pad 0.05d0))          ; gap between axes and colorbar (match matplotlib pad=0.05)
        (if (eq orientation :vertical)
            ;; Vertical: colorbar to the right of parent
            (let* ((cb-width (* p-width shrink-frac))
                   (new-parent-width (- p-width cb-width (* p-width pad)))
                   (cb-left (+ p-left new-parent-width (* p-width pad)))
                   (position (list cb-left p-bottom cb-width p-height)))
              ;; Shrink parent
              (setf (third (axes-base-position parent-ax)) new-parent-width)
              ;; Recompute transAxes so title centers on the shrunk axes, not the original
              (%setup-transforms parent-ax)
              ;; Create colorbar axes
              (let ((cax (make-instance 'axes-base
                                        :figure fig
                                        :position position
                                        :facecolor "white"
                                        :frameon nil
                                        :zorder 0)))
                ;; Make colorbar axes invisible — colorbar draws its own content
                ;; (gradient, border, ticks). The axes is only used for bbox.
                (setf (mpl.rendering:artist-visible cax) nil)
                (setf (axes-base-spines cax) nil)
                (setf (figure-axes fig) (nconc (figure-axes fig) (list cax)))
                (setf (mpl.rendering:artist-figure cax) fig)
                cax))
            ;; Horizontal: colorbar below parent
            (let* ((cb-height (* p-height shrink-frac))
                   (new-parent-height (- p-height cb-height (* p-height pad)))
                   (cb-bottom p-bottom)
                   (new-parent-bottom (+ p-bottom cb-height (* p-height pad)))
                   (position (list p-left cb-bottom p-width cb-height)))
              ;; Shrink and reposition parent
              (setf (second (axes-base-position parent-ax)) new-parent-bottom
                    (fourth (axes-base-position parent-ax)) new-parent-height)
              ;; Recompute transAxes so title centers on the shrunk axes, not the original
              (%setup-transforms parent-ax)
              ;; Create colorbar axes
              (let ((cax (make-instance 'axes-base
                                        :figure fig
                                        :position position
                                        :facecolor "white"
                                        :frameon nil
                                        :zorder 0)))
                ;; Make colorbar axes invisible — colorbar draws its own content
                (setf (mpl.rendering:artist-visible cax) nil)
                (setf (axes-base-spines cax) nil)
                (setf (figure-axes fig) (nconc (figure-axes fig) (list cax)))
                (setf (mpl.rendering:artist-figure cax) fig)
                cax)))))))

;;; ============================================================
;;; Colorbar tick computation
;;; ============================================================

(defun %colorbar-auto-ticks (cb)
  "Compute automatic tick positions for the colorbar.
Uses MaxNLocator algorithm to generate 'nice' tick values at round numbers,
matching matplotlib's colorbar tick generation."
  (let* ((mappable (colorbar-mappable cb))
         (norm (when mappable (mpl.primitives:sm-norm mappable)))
         (vmin (when norm (mpl.primitives:norm-vmin norm)))
         (vmax (when norm (mpl.primitives:norm-vmax norm))))
    (if (and vmin vmax)
        ;; Use MaxNLocator for nice tick values (matches matplotlib)
        (let* ((loc (make-instance 'max-n-locator
                                    :nbins 10
                                    :steps '(1.0d0 2.0d0 2.5d0 5.0d0 10.0d0)))
               (all-ticks (locator-tick-values loc
                                               (float vmin 1.0d0)
                                               (float vmax 1.0d0))))
          ;; Filter to only ticks within [vmin, vmax]
          (remove-if (lambda (t-val)
                       (or (< t-val vmin) (> t-val vmax)))
                     all-ticks))
        ;; Default ticks from 0 to 1
        (list 0.0d0 0.25d0 0.5d0 0.75d0 1.0d0))))

(defun %colorbar-format-tick (value &optional format-string)
  "Format a tick value as a string, matching matplotlib's ScalarFormatter."
  (if format-string
      (format nil format-string value)
      ;; Default: use scalar formatter-like output (strip trailing zeros)
      (let* ((abs-val (abs value))
             (raw (cond
                    ((< abs-val 1d-10) "0.0")
                    ((and (>= abs-val 0.01d0) (<= abs-val 10000.0d0))
                     (format nil "~,1F" value))
                    (t (format nil "~,2E" value)))))
        ;; Strip trailing zeros after decimal point, but keep at least one
        (if (find #\. raw)
            (let ((trimmed (string-right-trim "0" raw)))
              (if (char= (char trimmed (1- (length trimmed))) #\.)
                  (concatenate 'string trimmed "0")
                  trimmed))
            raw))))

;;; ============================================================
;;; Colorbar draw method
;;; ============================================================

(defmethod mpl.rendering:draw ((cb mpl-colorbar) renderer)
  "Draw the colorbar: color gradient and tick marks/labels."
  (unless (mpl.rendering:artist-visible cb)
    (return-from mpl.rendering:draw))
  (let* ((cax (colorbar-cax cb))
         (mappable (colorbar-mappable cb))
         (orientation (colorbar-orientation cb)))
    (when (and cax mappable (typep renderer 'mpl.backends:renderer-base))
      ;; Draw color gradient
      (%colorbar-draw-gradient cb renderer)
      ;; Draw ticks and labels
      (%colorbar-draw-ticks cb renderer)
      ;; Draw border
      (%colorbar-draw-border cb renderer)
      ;; Draw label
      (when (plusp (length (colorbar-label cb)))
        (%colorbar-draw-label cb renderer))))
  (setf (mpl.rendering:artist-stale cb) nil))

(defun %colorbar-draw-gradient (cb renderer)
  "Draw the color gradient for the colorbar."
  (let* ((cax (colorbar-cax cb))
         (mappable (colorbar-mappable cb))
         (orientation (colorbar-orientation cb)))
    (multiple-value-bind (dx dy dw dh) (%compute-display-bbox cax)
      ;; Use pixel-level resolution to avoid anti-aliasing artifacts between strips
      (let ((n-levels (max (colorbar-n-levels cb) (ceiling (if (eq orientation :vertical) dh dw)))))
        (if (eq orientation :vertical)
            ;; Vertical: draw horizontal strips from bottom to top
            ;; Constrain width to aspect ratio 20:1 (matching matplotlib default)
            (let* ((strip-width (min dw (/ dh 20.0d0)))
                   (strip-height (/ dh (float n-levels 1.0d0))))
              (dotimes (i n-levels)
                (let* ((frac (/ (float i 1.0d0) (float (1- n-levels) 1.0d0)))
                       (rgba (mpl.primitives:colormap-call
                              (mpl.primitives:sm-cmap mappable) frac))
                       (color-list (list (aref rgba 0) (aref rgba 1)
                                         (aref rgba 2) (aref rgba 3)))
                       (strip-y (+ dy (* i strip-height)))
                       (path (mpl.primitives:path-unit-rectangle))
                       (transform (mpl.primitives:make-affine-2d
                                   :scale (list strip-width strip-height)
                                   :translate (list dx strip-y)))
                       (gc (mpl.backends:make-graphics-context
                            :facecolor color-list
                            :edgecolor nil
                            :linewidth 0.0)))
                  (mpl.backends:draw-path renderer gc path transform color-list))))
            ;; Horizontal: draw vertical strips from left to right
            (let ((strip-width (/ dw (float n-levels 1.0d0))))
              (dotimes (i n-levels)
                (let* ((frac (/ (float i 1.0d0) (float (1- n-levels) 1.0d0)))
                       (rgba (mpl.primitives:colormap-call
                              (mpl.primitives:sm-cmap mappable) frac))
                       (color-list (list (aref rgba 0) (aref rgba 1)
                                         (aref rgba 2) (aref rgba 3)))
                       (strip-x (+ dx (* i strip-width)))
                       (path (mpl.primitives:path-unit-rectangle))
                       (transform (mpl.primitives:make-affine-2d
                                   :scale (list strip-width dh)
                                   :translate (list strip-x dy)))
                       (gc (mpl.backends:make-graphics-context
                            :facecolor color-list
                            :edgecolor nil
                            :linewidth 0.0)))
                  (mpl.backends:draw-path renderer gc path transform color-list)))))))))

(defun %colorbar-draw-ticks (cb renderer)
  "Draw tick marks and labels for the colorbar."
  (let* ((cax (colorbar-cax cb))
         (ticks (colorbar-ticks cb))
         (mappable (colorbar-mappable cb))
         (norm (when mappable (mpl.primitives:sm-norm mappable)))
         (orientation (colorbar-orientation cb))
         (tick-size 5.0d0)
         (tick-pad 3.0d0)
         (fontsize 8.0d0)
         ;; Compute format string from tick spacing (like matplotlib ScalarFormatter)
         (auto-fmt (when (>= (length ticks) 2)
                    (let* ((step (abs (- (second ticks) (first ticks))))
                           ;; Find minimum decimals to represent step exactly
                           (ndec (loop for d from 0 to 10
                                       when (< (abs (- (* step (expt 10.0d0 d))
                                                        (round (* step (expt 10.0d0 d)))))
                                                  1d-6)
                                       return d
                                       finally (return 1))))
                      (format nil "~~,~dF" (max 1 ndec))))))
    (when (and cax ticks norm)
      (multiple-value-bind (dx dy dw dh) (%compute-display-bbox cax)
        (dolist (tick-val ticks)
          (let ((frac (mpl.primitives:normalize-call norm (float tick-val 1.0d0)))
                (label (%colorbar-format-tick tick-val (or (colorbar-format cb) auto-fmt))))
            ;; Clamp fraction to valid range
            (setf frac (max 0.0d0 (min 1.0d0 frac)))
            (if (eq orientation :vertical)
                ;; Vertical: ticks on the right side
                (let* ((strip-width (min dw (/ dh 20.0d0)))
                       (tick-y (+ dy (* frac dh)))
                       (tick-x0 (+ dx strip-width))
                       (tick-x1 (+ tick-x0 tick-size))
                       ;; Draw tick mark
                       (verts (make-array '(2 2) :element-type 'double-float))
                       (_ (progn
                            (setf (aref verts 0 0) tick-x0
                                  (aref verts 0 1) tick-y
                                  (aref verts 1 0) tick-x1
                                  (aref verts 1 1) tick-y)))
                       (path (mpl.primitives:make-path :vertices verts))
                       (gc (mpl.backends:make-graphics-context
                            :facecolor nil
                            :edgecolor (list 0.0d0 0.0d0 0.0d0 1.0d0)
                            :linewidth 0.8)))
                  (declare (ignore _))
                  (mpl.backends:draw-path renderer gc path
                                          (mpl.primitives:make-identity-transform) nil)
                  ;; Draw tick label
                  (let ((label-gc (mpl.backends:make-graphics-context
                                   :facecolor nil
                                   :edgecolor (list 0.0d0 0.0d0 0.0d0 1.0d0)
                                   :linewidth fontsize)))
                    (mpl.backends:draw-text renderer label-gc
                                            (+ tick-x1 tick-pad) tick-y
                                            label nil 0.0)))
                ;; Horizontal: ticks on the bottom
                (let* ((tick-x (+ dx (* frac dw)))
                       (tick-y0 dy)
                       (tick-y1 (- tick-y0 tick-size))
                       (verts (make-array '(2 2) :element-type 'double-float))
                       (_ (progn
                            (setf (aref verts 0 0) tick-x
                                  (aref verts 0 1) tick-y0
                                  (aref verts 1 0) tick-x
                                  (aref verts 1 1) tick-y1)))
                       (path (mpl.primitives:make-path :vertices verts))
                       (gc (mpl.backends:make-graphics-context
                            :facecolor nil
                            :edgecolor (list 0.0d0 0.0d0 0.0d0 1.0d0)
                            :linewidth 0.8)))
                  (declare (ignore _))
                  (mpl.backends:draw-path renderer gc path
                                          (mpl.primitives:make-identity-transform) nil)
                  (let ((label-gc (mpl.backends:make-graphics-context
                                   :facecolor nil
                                   :edgecolor (list 0.0d0 0.0d0 0.0d0 1.0d0)
                                   :linewidth fontsize)))
                    (mpl.backends:draw-text renderer label-gc
                                            tick-x (- tick-y1 tick-pad)
                                            label nil 0.0))))))))))

(defun %colorbar-draw-border (cb renderer)
  "Draw the colorbar border."
  (let ((cax (colorbar-cax cb)))
    (when cax
      (multiple-value-bind (dx dy dw dh) (%compute-display-bbox cax)
        ;; Use same aspect-constrained width as gradient
        (let* ((strip-width (min dw (/ dh 20.0d0)))
               (path (mpl.primitives:path-unit-rectangle))
               (transform (mpl.primitives:make-affine-2d
                           :scale (list strip-width dh)
                           :translate (list dx dy)))
               (gc (mpl.backends:make-graphics-context
                    :facecolor nil
                    :edgecolor (list 0.0d0 0.0d0 0.0d0 1.0d0)
                    :linewidth 0.8)))
          (mpl.backends:draw-path renderer gc path transform nil))))))

(defun %colorbar-draw-label (cb renderer)
  "Draw the colorbar label."
  (let* ((cax (colorbar-cax cb))
         (orientation (colorbar-orientation cb))
         (label (colorbar-label cb)))
    (when (and cax (plusp (length label)))
      (multiple-value-bind (dx dy dw dh) (%compute-display-bbox cax)
        (let* ((gc (mpl.backends:make-graphics-context
                    :facecolor nil
                    :edgecolor (list 0.0d0 0.0d0 0.0d0 1.0d0)
                    :linewidth 10.0)))
          (if (eq orientation :vertical)
              ;; Label to the right of ticks, centered vertically
              (mpl.backends:draw-text renderer gc
                                      (+ dx dw 40.0d0) (+ dy (/ dh 2.0d0))
                                      label nil 0.0)
              ;; Label below ticks, centered horizontally
              (mpl.backends:draw-text renderer gc
                                      (+ dx (/ dw 2.0d0)) (- dy 25.0d0)
                                      label nil 0.0)))))))

;;; ============================================================
;;; Convenience function: make-colorbar
;;; ============================================================

(defun make-colorbar (ax mappable &key (orientation :vertical) (label "")
                                       ticks format (n-levels 256))
  "Create a colorbar for MAPPABLE and add it to the figure of AX.

AX — the parent axes.
MAPPABLE — a scalar-mappable providing norm + colormap.
ORIENTATION — :vertical (default) or :horizontal.
LABEL — colorbar label text.
TICKS — list of tick locations, or nil for auto.
FORMAT — tick label format string.
N-LEVELS — number of color levels (default 256).

Returns the created mpl-colorbar."
  (let ((cb (make-instance 'mpl-colorbar
                           :ax ax
                           :mappable mappable
                           :orientation orientation
                           :label label
                           :ticks ticks
                           :format format
                           :n-levels n-levels
                           :zorder 4)))
    ;; Add colorbar to figure artists for drawing
    (let ((fig (axes-base-figure ax)))
      (when fig
        (push cb (figure-artists fig))
        (setf (mpl.rendering:artist-figure cb) fig)))
    cb))
