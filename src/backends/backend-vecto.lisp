;;;; backend-vecto.lisp — Vecto-based PNG backend for cl-matplotlib
;;;; Implements the RendererBase protocol using Vecto (cl-vectors + cl-aa + zpng).
;;;; 
;;;; Usage:
;;;;   (let ((canvas (make-instance 'canvas-vecto :width 640 :height 480 :dpi 100)))
;;;;     (draw-path (get-renderer canvas) path gc)
;;;;     (print-png canvas "/tmp/test.png"))

(in-package #:cl-matplotlib.backends)

;;; ============================================================
;;; Font path configuration
;;; ============================================================

(defparameter *default-font-path*
  "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf"
  "Default font path for text rendering.")

;;; ============================================================
;;; renderer-vecto — Vecto-based rasterizer
;;; ============================================================

(defclass renderer-vecto (renderer-base)
  ((canvas-state :initform nil
                 :accessor renderer-canvas-state
                 :documentation "The Vecto graphics state when active (during with-canvas).")
   (font-cache :initform (make-hash-table :test 'equal)
               :accessor renderer-font-cache
               :documentation "Cache of loaded font objects keyed by path.")
   (active-p :initform nil
             :accessor renderer-active-p
             :type boolean
             :documentation "Whether the renderer is inside a with-canvas block."))
  (:documentation "Renderer implementation using Vecto for PNG output.
Uses cl-vectors for path rasterization, cl-aa for anti-aliasing,
and zpng for PNG output."))

;;; ============================================================
;;; Color helpers
;;; ============================================================

(defun %resolve-color (color-spec)
  "Resolve a color specification to (r g b a) list of floats 0.0-1.0.
COLOR-SPEC can be:
  - A list of 3-4 floats (RGBA)
  - A string (looked up via to-rgba)
  - NIL (returns NIL)"
  (when (null color-spec) (return-from %resolve-color nil))
  (cond
    ((and (listp color-spec) (>= (length color-spec) 3))
     (let ((r (float (nth 0 color-spec) 1.0))
           (g (float (nth 1 color-spec) 1.0))
           (b (float (nth 2 color-spec) 1.0))
           (a (if (>= (length color-spec) 4) (float (nth 3 color-spec) 1.0) 1.0)))
       (list r g b a)))
    ((stringp color-spec)
      (let ((rgba (mpl.colors:to-rgba color-spec)))
        (if (vectorp rgba)
            (list (float (elt rgba 0) 1.0)
                  (float (elt rgba 1) 1.0)
                  (float (elt rgba 2) 1.0)
                  (float (elt rgba 3) 1.0))
            (multiple-value-list rgba))))
    (t (list 0.0 0.0 0.0 1.0))))

(defun %gc-edge-color (gc)
  "Get the edge (stroke) color from a graphics context as (r g b a) or NIL."
  (let ((fg (mpl.rendering:gc-foreground gc)))
    (when fg (%resolve-color fg))))

(defun %gc-face-color (gc &optional rgbface)
  "Get the face (fill) color. Prefers RGBFACE if given, else gc-background."
  (cond
    (rgbface (%resolve-color rgbface))
    (t (let ((bg (mpl.rendering:gc-background gc)))
         (when bg (%resolve-color bg))))))

;;; ============================================================
;;; Graphics context → Vecto state mapping
;;; ============================================================

(defun %apply-gc-to-vecto (gc)
  "Apply a graphics-context's properties to the current Vecto state.
Must be called within a vecto:with-canvas or vecto:with-graphics-state."
  ;; Line width: convert from points. We apply DPI conversion elsewhere if needed.
  (let ((lw (mpl.rendering:gc-linewidth gc)))
    (when lw (vecto:set-line-width (float lw 1.0))))
  ;; Line cap
  (let ((cap (mpl.rendering:gc-capstyle gc)))
    (when cap
      (vecto:set-line-cap
       (case cap
         (:butt :butt)
         (:round :round)
         (:projecting :square)
         (:square :square)
         (otherwise :butt)))))
  ;; Line join
  (let ((join (mpl.rendering:gc-joinstyle gc)))
    (when join
      (vecto:set-line-join
       (case join
         (:miter :miter)
         (:round :round)
         (:bevel :bevel)
         (otherwise :miter)))))
  ;; Dash pattern
  (let ((dashes (mpl.rendering:gc-dashes gc))
        (linestyle (mpl.rendering:gc-linestyle gc)))
    (cond
      ;; Explicit dash list
      ((and dashes (listp dashes) (not (null dashes)))
       (let ((pattern (make-array (length dashes)
                                  :element-type 'single-float
                                  :initial-contents (mapcar (lambda (d) (float d 1.0)) dashes))))
         (vecto:set-dash-pattern pattern 0)))
      ;; Named line style
      ((and linestyle (not (eq linestyle :solid)))
       (case linestyle
         (:dashed (vecto:set-dash-pattern #(6.0 4.0) 0))
         (:dashdot (vecto:set-dash-pattern #(6.0 3.0 2.0 3.0) 0))
         (:dotted (vecto:set-dash-pattern #(2.0 4.0) 0))
         (otherwise (vecto:set-dash-pattern #() 0))))
      ;; Solid line
      (t (vecto:set-dash-pattern #() 0))))
  ;; Clip rectangle
  (let ((clip-rect (mpl.rendering:gc-clip-rectangle gc)))
    (when clip-rect
      ;; clip-rect is a bbox struct
      (let ((x0 (mpl.primitives:bbox-x0 clip-rect))
            (y0 (mpl.primitives:bbox-y0 clip-rect))
            (x1 (mpl.primitives:bbox-x1 clip-rect))
            (y1 (mpl.primitives:bbox-y1 clip-rect)))
        (vecto:rectangle (float x0 1.0) (float y0 1.0)
                         (float (- x1 x0) 1.0)
                         (float (- y1 y0) 1.0))
        (vecto:clip-path)
        (vecto:end-path-no-op)))))

;;; ============================================================
;;; Path rendering: map mpl-path codes to Vecto operations
;;; ============================================================

(defun %trace-path-to-vecto (path transform)
  "Trace an mpl-path into the current Vecto path.
TRANSFORM can be an affine-2d or NIL for identity."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0))
         (i 0))
    (when (zerop n) (return-from %trace-path-to-vecto nil))
    ;; If no codes, synthesize MOVETO + LINETOs
    (unless codes
      (setf codes (make-array n :element-type '(unsigned-byte 8)))
      (setf (aref codes 0) mpl.primitives:+moveto+)
      (loop for j from 1 below n do
        (setf (aref codes j) mpl.primitives:+lineto+)))
    (flet ((xf (x y)
             "Apply transform and return (values tx ty)."
             (if transform
                 (let ((result (mpl.primitives:transform-point
                                transform (list (float x 1.0d0) (float y 1.0d0)))))
                   (values (aref result 0) (aref result 1)))
                 (values (float x 1.0d0) (float y 1.0d0)))))
      (loop while (< i n) do
        (let ((code (aref codes i)))
          (cond
            ;; MOVETO
            ((= code mpl.primitives:+moveto+)
             (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
               (vecto:move-to (float tx 1.0) (float ty 1.0)))
             (incf i))
            ;; LINETO
            ((= code mpl.primitives:+lineto+)
             (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
               (vecto:line-to (float tx 1.0) (float ty 1.0)))
             (incf i))
            ;; CURVE3 (quadratic Bézier): 2 vertices (control + endpoint)
            ((= code mpl.primitives:+curve3+)
             (when (< (1+ i) n)
               (multiple-value-bind (cx cy) (xf (aref verts i 0) (aref verts i 1))
                 (multiple-value-bind (ex ey) (xf (aref verts (1+ i) 0) (aref verts (1+ i) 1))
                   (vecto:quadratic-to (float cx 1.0) (float cy 1.0)
                                       (float ex 1.0) (float ey 1.0)))))
             (incf i 2))
            ;; CURVE4 (cubic Bézier): 3 vertices (2 control + endpoint)
            ((= code mpl.primitives:+curve4+)
             (when (< (+ i 2) n)
               (multiple-value-bind (c1x c1y) (xf (aref verts i 0) (aref verts i 1))
                 (multiple-value-bind (c2x c2y) (xf (aref verts (1+ i) 0) (aref verts (1+ i) 1))
                   (multiple-value-bind (ex ey) (xf (aref verts (+ i 2) 0) (aref verts (+ i 2) 1))
                     (vecto:curve-to (float c1x 1.0) (float c1y 1.0)
                                     (float c2x 1.0) (float c2y 1.0)
                                     (float ex 1.0) (float ey 1.0))))))
             (incf i 3))
            ;; CLOSEPOLY
            ((= code mpl.primitives:+closepoly+)
             (vecto:close-subpath)
             (incf i))
            ;; STOP
            ((= code mpl.primitives:+stop+)
             (return))
            ;; Unknown
            (t (incf i))))))))

;;; ============================================================
;;; draw-path — Core rendering method
;;; ============================================================

(defmethod draw-path ((renderer renderer-vecto) gc path transform &optional rgbface)
  "Draw a path using Vecto. Handles fill, stroke, or fill+stroke.
Must be called within an active canvas context (see canvas-vecto)."
  (let ((edge-color (%gc-edge-color gc))
        (face-color (%gc-face-color gc rgbface))
        (alpha (mpl.rendering:gc-alpha gc)))
    (vecto:with-graphics-state
      ;; Apply graphics context state
      (%apply-gc-to-vecto gc)
      ;; Fill path if we have a face color
      (when face-color
        (let ((r (first face-color))
              (g (second face-color))
              (b (third face-color))
              (a (* (fourth face-color) (float alpha 1.0))))
          (vecto:set-rgba-fill (float r 1.0) (float g 1.0) (float b 1.0) (float a 1.0)))
        (%trace-path-to-vecto path transform)
        (if edge-color
            ;; Fill and stroke: need to trace path twice (Vecto consumes path on fill)
            (progn
              (vecto:fill-path)
              ;; Re-trace for stroke
              (let ((r (first edge-color))
                    (g (second edge-color))
                    (b (third edge-color))
                    (a (* (fourth edge-color) (float alpha 1.0))))
                (vecto:set-rgba-stroke (float r 1.0) (float g 1.0) (float b 1.0) (float a 1.0)))
              (%trace-path-to-vecto path transform)
              (vecto:stroke))
            ;; Fill only
            (vecto:fill-path)))
      ;; Stroke only (no fill)
      (when (and (not face-color) edge-color)
        (let ((r (first edge-color))
              (g (second edge-color))
              (b (third edge-color))
              (a (* (fourth edge-color) (float alpha 1.0))))
          (vecto:set-rgba-stroke (float r 1.0) (float g 1.0) (float b 1.0) (float a 1.0)))
        (%trace-path-to-vecto path transform)
        (vecto:stroke)))))

;;; ============================================================
;;; Bridge: renderer-draw-path from artist protocol → draw-path
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-path ((renderer renderer-vecto) gc path transform
                                             &key fill stroke)
  "Bridge from artist draw protocol to backend draw-path.
FILL can be T (use gc-background), a color spec, or nil.
STROKE can be T (use gc-foreground) or nil."
  (let ((rgbface (cond
                   ((and fill (not (eq fill t)))
                    ;; Fill is an explicit color spec
                    (%resolve-color fill))
                   ((eq fill t)
                    ;; Use gc-background or gc-foreground as fill color
                    (or (%gc-face-color gc nil)
                        (%gc-edge-color gc)))
                   (t nil))))
    ;; If stroke-only, ensure gc has a foreground but no background
    ;; If fill+stroke, pass rgbface to draw-path
    (draw-path renderer gc path transform rgbface)))

;;; ============================================================
;;; Bridge: renderer-draw-text from artist protocol → draw-text
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-text ((renderer renderer-vecto) gc x y text
                                             &key angle)
  "Bridge from artist draw text protocol to backend draw-text."
  (draw-text renderer gc (float x 1.0d0) (float y 1.0d0) text nil (or angle 0.0)))

;;; ============================================================
;;; draw-image — Blit RGBA image into canvas
;;; ============================================================

(defun %blit-image-to-canvas (image-data img-w img-h dest-x dest-y)
  "Blit an RGBA image into the current Vecto canvas at (DEST-X, DEST-Y).
IMAGE-DATA is a flat (simple-array (unsigned-byte 8) (*)) in RGBA row-major order.
Alpha-over compositing is performed."
  (let* ((state vecto::*graphics-state*)
         (canvas-data (zpng:image-data (vecto::image state)))
         (canvas-w (vecto::width state))
         (canvas-h (vecto::height state)))
    (declare (type (simple-array (unsigned-byte 8) (*)) image-data canvas-data)
             (type fixnum img-w img-h canvas-w canvas-h dest-x dest-y))
    (loop for sy fixnum from 0 below img-h
          for dy fixnum = (+ dest-y sy)
          when (and (>= dy 0) (< dy canvas-h))
            do (loop for sx fixnum from 0 below img-w
                     for dx fixnum = (+ dest-x sx)
                     when (and (>= dx 0) (< dx canvas-w))
                       do (let* ((si (* 4 (+ sx (* sy img-w))))
                                 (di (* 4 (+ dx (* dy canvas-w))))
                                 (sr (aref image-data (+ si 0)))
                                 (sg (aref image-data (+ si 1)))
                                 (sb (aref image-data (+ si 2)))
                                 (sa (aref image-data (+ si 3)))
                                 (dr (aref canvas-data (+ di 0)))
                                 (dg (aref canvas-data (+ di 1)))
                                 (db (aref canvas-data (+ di 2)))
                                 (da (aref canvas-data (+ di 3))))
                            ;; Alpha-over compositing
                            (let* ((a (/ (float sa 1.0) 255.0))
                                   (inv-a (- 1.0 a)))
                              (setf (aref canvas-data (+ di 0))
                                    (min 255 (round (+ (* sr a) (* dr inv-a)))))
                              (setf (aref canvas-data (+ di 1))
                                    (min 255 (round (+ (* sg a) (* dg inv-a)))))
                              (setf (aref canvas-data (+ di 2))
                                    (min 255 (round (+ (* sb a) (* db inv-a)))))
                              (setf (aref canvas-data (+ di 3))
                                    (min 255 (round (+ sa (* da inv-a)))))))))))

(defmethod draw-image ((renderer renderer-vecto) gc x y im)
  "Draw an RGBA image IM at position (X, Y).
IM should be a plist with :data (flat RGBA bytes), :width, :height."
  (declare (ignore gc))
  (let ((data (getf im :data))
        (w (getf im :width))
        (h (getf im :height)))
    (when (and data w h)
      (%blit-image-to-canvas data w h (round x) (round y)))))

;;; ============================================================
;;; Bridge: renderer-draw-image from artist protocol → draw-image
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-image ((renderer renderer-vecto) gc x y image)
  "Bridge from artist draw-image protocol to backend draw-image."
  (draw-image renderer gc x y image))

;;; ============================================================
;;; draw-text — Render text using zpb-ttf via Vecto
;;; ============================================================

(defun %get-font (renderer font-path)
  "Get or cache a Vecto font object."
  (let ((cache (renderer-font-cache renderer)))
    (or (gethash font-path cache)
        (setf (gethash font-path cache)
              (vecto:get-font font-path)))))

(defmethod draw-text ((renderer renderer-vecto) gc x y s prop angle &optional ismath)
  "Draw text string S at position (X, Y) using Vecto's text rendering.
PROP is a font path string or NIL (uses default font).
ANGLE is rotation in degrees (currently only 0 supported by Vecto)."
  (declare (ignore ismath))
  (vecto:with-graphics-state
    (let* ((font-path (or (and (stringp prop) prop) *default-font-path*))
           (font (%get-font renderer font-path))
           (fontsize (or (and gc (mpl.rendering:gc-linewidth gc)) 12.0))
           (edge-color (%gc-edge-color gc))
           (alpha (if gc (mpl.rendering:gc-alpha gc) 1.0)))
      (vecto:set-font font (float fontsize 1.0))
      ;; Set text fill color
      (if edge-color
          (vecto:set-rgba-fill (float (first edge-color) 1.0)
                               (float (second edge-color) 1.0)
                               (float (third edge-color) 1.0)
                               (float (* (fourth edge-color) alpha) 1.0))
          (vecto:set-rgba-fill 0.0 0.0 0.0 (float alpha 1.0)))
      ;; Vecto doesn't support rotation natively — for angle=0, just draw
      ;; For non-zero angles, we'd need to transform coordinates
      (when (and (numberp angle) (/= angle 0))
        ;; TODO: Apply rotation transform for text
        nil)
      (vecto:draw-string (float x 1.0) (float y 1.0) s))))

;;; ============================================================
;;; draw-markers — Optimized repeated path drawing
;;; ============================================================

(defmethod draw-markers ((renderer renderer-vecto) gc marker-path marker-trans
                         path trans &optional rgbface)
  "Draw a marker at each vertex of PATH.
Optimized: applies gc once, then draws marker at each position."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0)))
    (when (zerop n) (return-from draw-markers nil))
    ;; Apply graphics state once for all markers
    (vecto:with-graphics-state
      (%apply-gc-to-vecto gc)
      (dotimes (i n)
        (let ((code (if codes (aref codes i)
                        (if (zerop i) mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
          ;; Only draw at MOVETO and LINETO vertices (not control points)
          (when (or (= code mpl.primitives:+moveto+)
                    (= code mpl.primitives:+lineto+))
            (let ((x (aref verts i 0))
                  (y (aref verts i 1)))
              ;; Transform the position
              (multiple-value-bind (tx ty)
                  (if trans
                      (let ((result (mpl.primitives:transform-point
                                     trans (list x y))))
                        (values (aref result 0) (aref result 1)))
                      (values x y))
                ;; Create a translation to this position and compose with marker transform
                (let ((pos-transform (mpl.primitives:make-affine-2d :translate (list tx ty))))
                  (let ((full-transform (if marker-trans
                                            (mpl.primitives:compose marker-trans pos-transform)
                                            pos-transform)))
                    (draw-path renderer gc marker-path full-transform rgbface)))))))))))

;;; ============================================================
;;; draw-path-collection — Optimized batch path drawing
;;; ============================================================

(defmethod draw-path-collection ((renderer renderer-vecto) gc paths all-transforms
                                 offsets offset-trans facecolors edgecolors
                                 linewidths linestyles antialiaseds)
  "Draw a collection of paths efficiently.
PATHS — list of mpl-paths.
ALL-TRANSFORMS — list of per-item transforms (or nil).
OFFSETS — list of (x y) offset positions.
OFFSET-TRANS — transform applied to each offset.
FACECOLORS, EDGECOLORS — lists of (r g b a) color specs.
LINEWIDTHS, LINESTYLES, ANTIALIASEDS — per-item drawing properties."
  (let* ((n-offsets (if offsets (length offsets) 0))
         (n-paths (if paths (length paths) 0))
         (n-items (max n-offsets n-paths 0))
         (alpha (mpl.rendering:gc-alpha gc)))
    (when (zerop n-items)
      (return-from draw-path-collection))
    ;; Draw each item
    (dotimes (i n-items)
      (let* ((path-idx (if (zerop n-paths) 0 (mod i n-paths)))
             (path (when (plusp n-paths) (elt paths path-idx)))
             (item-transform (when all-transforms
                               (elt all-transforms (mod i (length all-transforms)))))
             (offset (when (plusp n-offsets) (elt offsets (mod i n-offsets))))
             (face-color (when facecolors
                           (elt facecolors (mod i (length facecolors)))))
             (edge-color (when edgecolors
                           (elt edgecolors (mod i (length edgecolors)))))
             (linewidth (if linewidths
                            (elt linewidths (mod i (length linewidths)))
                            1.0))
             (antialiased (if antialiaseds
                              (elt antialiaseds (mod i (length antialiaseds)))
                              t)))
        (when path
          ;; Compute final transform
          (let ((final-transform nil))
            ;; Per-item transform
            (when item-transform
              (setf final-transform item-transform))
            ;; Offset translation
            (when offset
              (let* ((ox (float (first offset) 1.0d0))
                     (oy (float (second offset) 1.0d0))
                     (transformed-offset
                       (if offset-trans
                           (mpl.primitives:transform-point
                            offset-trans (list ox oy))
                           (vector ox oy)))
                     (tx (aref transformed-offset 0))
                     (ty (aref transformed-offset 1))
                     (offset-tr (mpl.primitives:make-affine-2d
                                 :translate (list tx ty))))
                (if final-transform
                    (setf final-transform
                          (mpl.primitives:compose final-transform offset-tr))
                    (setf final-transform offset-tr))))
            ;; Set GC and draw
            (vecto:with-graphics-state
              (vecto:set-line-width (float linewidth 1.0))
              (when (not antialiased)
                ;; Vecto doesn't have AA toggle, but we track the intent
                nil)
              ;; Fill
              (when face-color
                (let ((r (first face-color))
                      (g (second face-color))
                      (b (third face-color))
                      (a (* (fourth face-color) (float alpha 1.0))))
                  (vecto:set-rgba-fill (float r 1.0) (float g 1.0) (float b 1.0)
                                       (float a 1.0)))
                (%trace-path-to-vecto path final-transform)
                (if edge-color
                    (progn
                      (vecto:fill-path)
                      ;; Re-trace for stroke
                      (let ((r (first edge-color))
                            (g (second edge-color))
                            (b (third edge-color))
                            (a (* (fourth edge-color) (float alpha 1.0))))
                        (vecto:set-rgba-stroke (float r 1.0) (float g 1.0)
                                               (float b 1.0) (float a 1.0)))
                      (%trace-path-to-vecto path final-transform)
                      (vecto:stroke))
                    (vecto:fill-path)))
              ;; Stroke only
              (when (and (not face-color) edge-color)
                (let ((r (first edge-color))
                      (g (second edge-color))
                      (b (third edge-color))
                      (a (* (fourth edge-color) (float alpha 1.0))))
                  (vecto:set-rgba-stroke (float r 1.0) (float g 1.0)
                                         (float b 1.0) (float a 1.0)))
                (%trace-path-to-vecto path final-transform)
                (vecto:stroke)))))))))

;;; ============================================================
;;; draw-gouraud-triangles — Stub implementation
;;; ============================================================

(defmethod draw-gouraud-triangles ((renderer renderer-vecto) gc triangles-array colors-array transform)
  "Draw Gouraud-shaded triangles. Currently a simplified flat-color fallback."
  (declare (ignore gc transform))
  ;; Simplified: draw each triangle as a solid-color filled polygon
  ;; using the average of its three vertex colors
  (when (and triangles-array colors-array)
    (let ((n (array-dimension triangles-array 0)))
      (dotimes (tri n)
        ;; Average the colors of the 3 vertices
        (let ((r 0.0) (g 0.0) (b 0.0) (a 0.0))
          (dotimes (v 3)
            (incf r (aref colors-array tri v 0))
            (incf g (aref colors-array tri v 1))
            (incf b (aref colors-array tri v 2))
            (incf a (aref colors-array tri v 3)))
          (setf r (/ r 3.0) g (/ g 3.0) b (/ b 3.0) a (/ a 3.0))
          (vecto:with-graphics-state
            (vecto:set-rgba-fill (float r 1.0) (float g 1.0)
                                 (float b 1.0) (float a 1.0))
            ;; Trace the triangle path
            (vecto:move-to (float (aref triangles-array tri 0 0) 1.0)
                           (float (aref triangles-array tri 0 1) 1.0))
            (vecto:line-to (float (aref triangles-array tri 1 0) 1.0)
                           (float (aref triangles-array tri 1 1) 1.0))
            (vecto:line-to (float (aref triangles-array tri 2 0) 1.0)
                           (float (aref triangles-array tri 2 1) 1.0))
            (vecto:close-subpath)
            (vecto:fill-path)))))))

;;; ============================================================
;;; renderer-clear
;;; ============================================================

(defmethod renderer-clear ((renderer renderer-vecto))
  "Clear the canvas to white background."
  (vecto:set-rgb-fill 1.0 1.0 1.0)
  (vecto:rectangle 0 0 (renderer-width renderer) (renderer-height renderer))
  (vecto:fill-path))

;;; ============================================================
;;; get-canvas-width-height
;;; ============================================================

(defmethod get-canvas-width-height ((renderer renderer-vecto))
  (values (renderer-width renderer) (renderer-height renderer)))

;;; ============================================================
;;; canvas-vecto — Canvas implementation for Vecto PNG output
;;; ============================================================

(defclass canvas-vecto (canvas-base)
  ((render-fn :initform nil
              :accessor canvas-render-fn
              :documentation "Optional render function called during draw."))
  (:documentation "Canvas that renders to PNG via Vecto.
Usage:
  (let ((canvas (make-instance 'canvas-vecto :width 640 :height 480 :dpi 100)))
    (draw-path (get-renderer canvas) path gc)
    (print-png canvas \"/tmp/test.png\"))"))

;;; ============================================================
;;; get-renderer
;;; ============================================================

(defmethod get-renderer ((canvas canvas-vecto))
  "Return or create the renderer for this canvas."
  (or (canvas-renderer canvas)
      (setf (canvas-renderer canvas)
            (make-instance 'renderer-vecto
                           :width (canvas-width canvas)
                           :height (canvas-height canvas)
                           :dpi (canvas-dpi canvas)))))

;;; ============================================================
;;; canvas-draw  
;;; ============================================================

(defmethod canvas-draw ((canvas canvas-vecto))
  "Clear canvas and invoke the figure's draw method if present."
  (let ((renderer (get-renderer canvas)))
    (renderer-clear renderer)
    ;; If there's a figure, call figure.draw(renderer)
    (when (canvas-figure canvas)
      (mpl.rendering:draw (canvas-figure canvas) renderer))))

;;; ============================================================
;;; print-png — Main output method
;;; ============================================================

(defvar *current-canvas* nil
  "The currently active canvas-vecto during rendering. 
Used to allow draw-path etc. to find the Vecto context.")

(defmethod print-png ((canvas canvas-vecto) filename)
  "Render figure to a PNG file using Vecto.
This method establishes the Vecto canvas context, executes all queued
drawing operations, and saves the result to FILENAME."
  (let ((w (canvas-width canvas))
        (h (canvas-height canvas))
        (renderer (get-renderer canvas)))
    (vecto:with-canvas (:width w :height h)
      ;; Set the renderer as active
      (setf (renderer-active-p renderer) t)
      ;; White background
      (vecto:set-rgb-fill 1.0 1.0 1.0)
      (vecto:rectangle 0 0 w h)
      (vecto:fill-path)
      ;; Execute any render function (for direct API usage)
      (when (canvas-render-fn canvas)
        (funcall (canvas-render-fn canvas) renderer))
      ;; If there's a figure, draw it
      (when (canvas-figure canvas)
        (mpl.rendering:draw (canvas-figure canvas) renderer))
      ;; Save
      (vecto:save-png filename)
      (setf (renderer-active-p renderer) nil)))
  filename)

;;; ============================================================
;;; Convenience: render-to-png — functional interface
;;; ============================================================

(defun render-to-png (filename &key (width 640) (height 480) (dpi 100) draw-fn)
  "Convenience function: create a canvas, call DRAW-FN with the renderer, save PNG.
Example:
  (render-to-png \"/tmp/test.png\"
    :width 400 :height 300
    :draw-fn (lambda (renderer)
               (let ((path (mpl.primitives:make-path ...))
                     (gc (make-graphics-context :edgecolor \"red\")))
                 (draw-path renderer gc path nil))))"
  (let ((canvas (make-instance 'canvas-vecto :width width :height height :dpi dpi)))
    (setf (canvas-render-fn canvas) draw-fn)
    (print-png canvas filename)))

;;; ============================================================
;;; Deferred drawing support
;;; ============================================================
;;; For the acceptance test scenarios, we need draw-path to work
;;; *inside* the print-png with-canvas. We use a recording approach:
;;; draw calls are recorded and replayed inside the Vecto context.

(defstruct draw-call
  "A recorded draw operation."
  (type :path :type keyword)  ; :path, :image, :text, :markers, :clear
  (args nil :type list))

(defclass canvas-vecto-deferred (canvas-vecto)
  ((draw-calls :initform nil
               :accessor canvas-draw-calls
               :documentation "List of recorded draw calls to replay."))
  (:documentation "Canvas that records draw calls for deferred execution within Vecto context."))

(defun %make-deferred-renderer (canvas)
  "Create a special renderer that records draw calls."
  (let ((renderer (get-renderer canvas)))
    renderer))

(defmethod print-png ((canvas canvas-vecto-deferred) filename)
  "Replay recorded draw calls inside Vecto context and save to PNG."
  (let ((w (canvas-width canvas))
        (h (canvas-height canvas))
        (renderer (get-renderer canvas)))
    (vecto:with-canvas (:width w :height h)
      (setf (renderer-active-p renderer) t)
      ;; White background
      (vecto:set-rgb-fill 1.0 1.0 1.0)
      (vecto:rectangle 0 0 w h)
      (vecto:fill-path)
      ;; Replay recorded draw calls
      (dolist (call (reverse (canvas-draw-calls canvas)))
        (case (draw-call-type call)
          (:path (apply #'draw-path renderer (draw-call-args call)))
          (:image (apply #'draw-image renderer (draw-call-args call)))
          (:text (apply #'draw-text renderer (draw-call-args call)))
          (:clear (renderer-clear renderer))))
      ;; Also execute render-fn if present
      (when (canvas-render-fn canvas)
        (funcall (canvas-render-fn canvas) renderer))
      ;; Save
      (vecto:save-png filename)
      (setf (renderer-active-p renderer) nil)))
  filename)

(defun canvas-record-draw-path (canvas gc path transform &optional rgbface)
  "Record a draw-path call on a deferred canvas."
  (push (make-draw-call :type :path :args (list gc path transform rgbface))
        (canvas-draw-calls canvas)))
