;;;; backend-svg.lisp — SVG backend for cl-matplotlib
;;;; Implements the RendererBase protocol for SVG output.
;;;;
;;;; Usage:
;;;;   (let ((canvas (make-instance 'canvas-svg :width 640 :height 480 :dpi 100)))
;;;;     (setf (canvas-render-fn-svg canvas)
;;;;           (lambda (renderer) (draw-path renderer gc path nil)))
;;;;     (print-svg canvas "/tmp/test.svg"))

(in-package #:cl-matplotlib.backends)

;;; ============================================================
;;; XML helper functions
;;; ============================================================

(defun %svg-xml-escape (s)
  "Escape a string for safe inclusion in XML/SVG content.
Replaces & < > \" with their XML entity equivalents."
  (with-output-to-string (out)
    (loop for ch across s do
      (case ch
        (#\& (write-string "&amp;" out))
        (#\< (write-string "&lt;" out))
        (#\> (write-string "&gt;" out))
        (#\" (write-string "&quot;" out))
        (otherwise (write-char ch out))))))

;;; ============================================================
;;; renderer-svg — SVG string-based renderer
;;; ============================================================

(defclass renderer-svg (renderer-base)
  ((output-stream :initform (make-string-output-stream)
                  :accessor renderer-svg-output-stream
                  :documentation "Accumulates SVG body elements.")
   (defs-stream :initform (make-string-output-stream)
                :accessor renderer-svg-defs-stream
                :documentation "Accumulates <defs> content (clip-paths, symbols).")
   (id-counter :initform 0
               :accessor renderer-svg-id-counter
               :type fixnum
               :documentation "Counter for unique ID generation.")
   (height :initarg :height
           :initform 480
           :accessor renderer-svg-height
           :type fixnum
           :documentation "Canvas height in pixels (needed for Y-flip in text/image).")
   (font-cache :initform (make-hash-table :test 'equal)
               :accessor renderer-svg-font-cache
               :documentation "Cache of zpb-ttf font loaders keyed by path string."))
  (:documentation "Renderer implementation producing SVG markup.
Accumulates SVG elements as strings into output-stream and defs-stream,
which are assembled into a complete SVG document by print-svg."))

;;; ============================================================
;;; Helper functions
;;; ============================================================

(defun %format-float (n)
  "Format a number as a string with 2 decimal places."
  (format nil "~,2F" (coerce n 'double-float)))

(defun %next-id (renderer prefix)
  "Generate a unique ID string for SVG elements.
Returns a string like \"clip-3\" or \"marker-5\"."
  (let ((count (incf (renderer-svg-id-counter renderer))))
    (format nil "~A-~D" prefix count)))

(defun %color-to-svg (color)
  "Convert a color (R G B A) list (values 0.0-1.0) to SVG representation.
Returns two values: a hex color string \"#RRGGBB\" and an opacity float.
If COLOR is NIL, returns (values \"none\" 0.0)."
  (if (null color)
      (values "none" 0.0d0)
      (let ((r (coerce (nth 0 color) 'double-float))
            (g (coerce (nth 1 color) 'double-float))
            (b (coerce (nth 2 color) 'double-float))
            (a (coerce (nth 3 color) 'double-float)))
        (values (format nil "#~2,'0X~2,'0X~2,'0X"
                        (round (* r 255.0d0))
                        (round (* g 255.0d0))
                        (round (* b 255.0d0)))
                a))))

;;; ============================================================
;;; Path tracing: map mpl-path codes to SVG path d-attribute
;;; ============================================================

(defun %trace-path-to-svg (path transform)
  "Trace an mpl-path into an SVG path d-attribute string.
TRANSFORM can be an affine transform or NIL for identity.
Does NOT flip Y coordinates — the global <g> transform handles that."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0))
         (i 0))
    (when (zerop n) (return-from %trace-path-to-svg ""))
    ;; If no codes, synthesize MOVETO + LINETOs
    (unless codes
      (setf codes (make-array n :element-type '(unsigned-byte 8)))
      (setf (aref codes 0) mpl.primitives:+moveto+)
      (loop for j from 1 below n do
        (setf (aref codes j) mpl.primitives:+lineto+)))
    (flet ((xf (x y)
             "Apply transform and return (values tx ty) as double-floats."
             (if transform
                 (let ((result (mpl.primitives:transform-point
                                transform (list (float x 1.0d0) (float y 1.0d0)))))
                   (values (aref result 0) (aref result 1)))
                 (values (float x 1.0d0) (float y 1.0d0)))))
      (with-output-to-string (out)
        (loop while (< i n) do
          (let ((code (aref codes i)))
            (cond
              ;; MOVETO
              ((= code mpl.primitives:+moveto+)
               (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
                 (format out "M ~A ~A " (%format-float tx) (%format-float ty)))
               (incf i))
              ;; LINETO
              ((= code mpl.primitives:+lineto+)
               (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
                 (format out "L ~A ~A " (%format-float tx) (%format-float ty)))
               (incf i))
              ;; CURVE3 (quadratic Bézier: control + endpoint = 2 vertices)
              ((= code mpl.primitives:+curve3+)
               (when (< (1+ i) n)
                 (multiple-value-bind (cx cy) (xf (aref verts i 0) (aref verts i 1))
                   (multiple-value-bind (ex ey) (xf (aref verts (1+ i) 0) (aref verts (1+ i) 1))
                     (format out "Q ~A ~A ~A ~A "
                             (%format-float cx) (%format-float cy)
                             (%format-float ex) (%format-float ey)))))
               (incf i 2))
              ;; CURVE4 (cubic Bézier: 2 control + endpoint = 3 vertices)
              ((= code mpl.primitives:+curve4+)
               (when (< (+ i 2) n)
                 (multiple-value-bind (c1x c1y) (xf (aref verts i 0) (aref verts i 1))
                   (multiple-value-bind (c2x c2y) (xf (aref verts (1+ i) 0) (aref verts (1+ i) 1))
                     (multiple-value-bind (ex ey) (xf (aref verts (+ i 2) 0) (aref verts (+ i 2) 1))
                       (format out "C ~A ~A ~A ~A ~A ~A "
                               (%format-float c1x) (%format-float c1y)
                               (%format-float c2x) (%format-float c2y)
                               (%format-float ex) (%format-float ey))))))
               (incf i 3))
              ;; CLOSEPOLY
              ((= code mpl.primitives:+closepoly+)
               (write-string "Z " out)
               (incf i))
              ;; STOP
              ((= code mpl.primitives:+stop+)
               (return))
              ;; Unknown — skip
              (t (incf i)))))))))

;;; ============================================================
;;; renderer-clear — clear the SVG canvas to white
;;; ============================================================

(defmethod renderer-clear ((renderer renderer-svg))
  "Clear the SVG canvas by emitting a white background rectangle."
  (let ((w (renderer-width renderer))
        (h (renderer-height renderer)))
    (format (renderer-svg-output-stream renderer)
            "<rect width=\"~D\" height=\"~D\" fill=\"white\"/>~%"
            w h)))

;;; ============================================================
;;; Graphics context → SVG attribute mapping
;;; ============================================================

(defun %apply-gc-to-svg-attrs (gc renderer)
  "Map a graphics-context's line properties to SVG attribute name/value strings.
Returns a plist like (:stroke-width \"2.00\" :stroke-linecap \"round\" ...).
RENDERER is accepted for interface symmetry but currently unused."
  (declare (ignore renderer))
  (let ((attrs '()))
    ;; Stroke width
    (let ((lw (mpl.rendering:gc-linewidth gc)))
      (when lw
        (setf (getf attrs :stroke-width) (%format-float lw))))
    ;; Stroke line cap
    (let ((cap (mpl.rendering:gc-capstyle gc)))
      (when cap
        (setf (getf attrs :stroke-linecap)
              (case cap
                (:butt "butt")
                (:round "round")
                (:projecting "square")
                (:square "square")
                (otherwise "butt")))))
    ;; Stroke line join
    (let ((join (mpl.rendering:gc-joinstyle gc)))
      (when join
        (setf (getf attrs :stroke-linejoin)
              (case join
                (:miter "miter")
                (:round "round")
                (:bevel "bevel")
                (otherwise "miter")))))
    ;; Stroke dash array — scale by linewidth like matplotlib
    ;; Base patterns (linewidth-relative):
    ;;   dashed:  (3.7, 1.6)
    ;;   dashdot: (6.4, 1.6, 1.0, 1.6)
    ;;   dotted:  (1.0, 1.65)
    (let ((dashes (mpl.rendering:gc-dashes gc))
          (linestyle (mpl.rendering:gc-linestyle gc))
          (lw (or (and gc (mpl.rendering:gc-linewidth gc)) 1.0d0)))
      (cond
        ;; Explicit dash list
        ((and dashes (listp dashes) (not (null dashes)))
         (setf (getf attrs :stroke-dasharray)
               (format nil "~{~A~^ ~}"
                       (mapcar (lambda (d) (%format-float d)) dashes))))
        ;; Named line style — scale by linewidth
        ((and linestyle (not (eq linestyle :solid)))
         (let ((base-pattern (case linestyle
                               (:dashed '(3.7d0 1.6d0))
                               (:dashdot '(6.4d0 1.6d0 1.0d0 1.6d0))
                               (:dotted '(1.0d0 1.65d0))
                               (otherwise nil))))
           (when base-pattern
             (setf (getf attrs :stroke-dasharray)
                   (format nil "~{~A~^ ~}"
                           (mapcar (lambda (d)
                                     (%format-float (max (* d (coerce lw 'double-float)) 1.0d0)))
                                   base-pattern))))))))
    attrs))

;;; ============================================================
;;; Clip path emission
;;; ============================================================

(defun %emit-clip-path (renderer gc)
  "If GC has a clip-rectangle, emit a <clipPath> into the defs-stream.
Returns the clip ID string (e.g. \"clip-1\") or NIL if no clip rectangle."
  (let ((clip-rect (mpl.rendering:gc-clip-rectangle gc)))
    (when clip-rect
      (let* ((clip-id (%next-id renderer "clip"))
             (x0 (mpl.primitives:bbox-x0 clip-rect))
             (y0 (mpl.primitives:bbox-y0 clip-rect))
             (x1 (mpl.primitives:bbox-x1 clip-rect))
             (y1 (mpl.primitives:bbox-y1 clip-rect))
             (defs (renderer-svg-defs-stream renderer)))
        (format defs "<clipPath id=\"~A\">~%" clip-id)
        (format defs "<rect x=\"~A\" y=\"~A\" width=\"~A\" height=\"~A\"/>~%"
                (%format-float x0) (%format-float y0)
                (%format-float (- x1 x0)) (%format-float (- y1 y0)))
        (format defs "</clipPath>~%")
        clip-id))))

;;; ============================================================
;;; draw-path — Core rendering method
;;; ============================================================

(defmethod draw-path ((renderer renderer-svg) gc path transform &optional rgbface)
  "Draw a path as an SVG <path> element. Handles fill, stroke, or both.
Emits to renderer's output-stream; clip definitions go to defs-stream."
  ;; Early exit for empty paths
  (let ((d (%trace-path-to-svg path transform)))
    (when (string= d "")
      (return-from draw-path nil))
    ;; Resolve colors
    (let* ((face-color (%gc-face-color gc rgbface))
           (edge-color (%gc-edge-color gc))
           (gc-alpha (or (mpl.rendering:gc-alpha gc) 1.0d0)))
      (multiple-value-bind (fill-hex fill-opacity) (%color-to-svg face-color)
        (multiple-value-bind (stroke-hex stroke-opacity) (%color-to-svg edge-color)
          ;; Apply overall gc-alpha to per-color opacities
          (let* ((fill-op (* fill-opacity (coerce gc-alpha 'double-float)))
                 (stroke-op (* stroke-opacity (coerce gc-alpha 'double-float)))
                 ;; Get line style attributes
                 (gc-attrs (%apply-gc-to-svg-attrs gc renderer))
                 ;; Emit clip-path if needed
                 (clip-id (%emit-clip-path renderer gc))
                 (out (renderer-svg-output-stream renderer)))
            ;; Emit <path> element
            (format out "<path d=\"~A\" fill=\"~A\" fill-opacity=\"~A\" stroke=\"~A\" stroke-opacity=\"~A\""
                    d fill-hex (%format-float fill-op)
                    stroke-hex (%format-float stroke-op))
            ;; Stroke width
            (let ((sw (getf gc-attrs :stroke-width)))
              (when sw
                (format out " stroke-width=\"~A\"" sw)))
            ;; Stroke line cap
            (let ((cap (getf gc-attrs :stroke-linecap)))
              (when cap
                (format out " stroke-linecap=\"~A\"" cap)))
            ;; Stroke line join
            (let ((join (getf gc-attrs :stroke-linejoin)))
              (when join
                (format out " stroke-linejoin=\"~A\"" join)))
            ;; Dash array
            (let ((da (getf gc-attrs :stroke-dasharray)))
              (when da
                (format out " stroke-dasharray=\"~A\"" da)))
            ;; Clip path reference
            (when clip-id
              (format out " clip-path=\"url(#~A)\"" clip-id))
             (format out "/>~%")))))))

;;; ============================================================
;;; Bridge: renderer-draw-path from artist protocol → draw-path
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-path ((renderer renderer-svg) gc path transform
                                             &key fill stroke)
  "Bridge from artist draw protocol to backend draw-path.
FILL can be T (use gc-background), a color spec, or nil.
STROKE can be T (use gc-foreground) or nil."
  (declare (ignore stroke))
  (let ((rgbface (cond
                   ((and fill (not (eq fill t)))
                    (%resolve-color fill))
                   ((eq fill t)
                    (or (%gc-face-color gc nil)
                        (%gc-edge-color gc)))
                   (t nil))))
    (draw-path renderer gc path transform rgbface)))

;;; ============================================================
;;; Bridge: renderer-draw-text from artist protocol → draw-text
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-text ((renderer renderer-svg) gc x y text
                                             &key (angle 0) (ha :left) (va :baseline))
  "Bridge from artist draw text protocol to backend draw-text."
  (draw-text renderer gc (float x 1.0d0) (float y 1.0d0) text nil (or angle 0.0d0) nil ha va))

;;; ============================================================
;;; Bridge: renderer-draw-image from artist protocol → draw-image
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-image ((renderer renderer-svg) gc x y image)
  "Bridge from artist draw-image protocol to backend draw-image."
  (draw-image renderer gc x y image))

;;; ============================================================
;;; draw-text — Emit <text> SVG element
;;; ============================================================

(defmethod draw-text ((renderer renderer-svg) gc x y s prop angle &optional ismath ha va)
  "Draw text string S at position (X, Y) as an SVG <text> element.
PROP is unused (font-family is always DejaVu Sans for SVG).
ANGLE is rotation in degrees (counterclockwise).
HA — horizontal alignment (:left, :center, :right) → SVG text-anchor.
VA — vertical alignment (accepted but not used for dominant-baseline)."
  (declare (ignore prop ismath va))
  ;; Guard: nil or empty string → no output
  (when (or (null s) (and (stringp s) (string= s "")))
    (return-from draw-text nil))
  (let* ((font-size (coerce (or (and gc (mpl.rendering:gc-linewidth gc)) 12.0) 'double-float))
         ;; Text color from gc-foreground
         (raw-color (when gc (%resolve-color (mpl.rendering:gc-foreground gc))))
         (gc-alpha (or (and gc (mpl.rendering:gc-alpha gc)) 1.0d0))
         ;; Horizontal alignment → SVG text-anchor
         (text-anchor (case ha
                        (:center "middle")
                        (:right "end")
                        (otherwise "start")))
         ;; Y-flip counter: global <g> has scale(1,-1), so text appears upside-down.
         ;; Fix: place at (x, -y) and add scale(1,-1) to un-flip.
         ;; With rotation angle A (degrees, CCW): emit rotate(-A) in SVG.
         (angle-d (if (numberp angle) (coerce angle 'double-float) 0.0d0))
         (transform-str
           (if (/= angle-d 0.0d0)
               (format nil "translate(~A,~A) rotate(~A) scale(1,-1)"
                       (%format-float x)
                       (%format-float (- (coerce y 'double-float)))
                       (%format-float (- angle-d)))
               (format nil "translate(~A,~A) scale(1,-1)"
                       (%format-float x)
                       (%format-float (- (coerce y 'double-float)))))))
    ;; Emit <text> element
    (let ((out (renderer-svg-output-stream renderer)))
      (multiple-value-bind (fill-hex fill-op)
          (%color-to-svg (when raw-color
                           (list (car raw-color) (cadr raw-color)
                                 (caddr raw-color)
                                 (* (cadddr raw-color) (coerce gc-alpha 'double-float)))))
        (format out "<text font-family=\"DejaVu Sans\" font-size=\"~A\" fill=\"~A\" fill-opacity=\"~A\" text-anchor=\"~A\" transform=\"~A\">~A</text>~%"
                (%format-float font-size)
                fill-hex (%format-float fill-op)
                text-anchor
                transform-str
                (%svg-xml-escape s))))))

;;; ============================================================
;;; Base64 encoding (inline, no cl-base64 dependency)
;;; ============================================================

(defun %octets-to-base64 (octets)
  "Encode a byte vector to a base64 string. No external dependency."
  (let ((alphabet "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
        (len (length octets)))
    (with-output-to-string (out)
      (loop for i from 0 below len by 3 do
        (let* ((b0 (aref octets i))
               (b1 (if (< (+ i 1) len) (aref octets (+ i 1)) 0))
               (b2 (if (< (+ i 2) len) (aref octets (+ i 2)) 0))
               (n (logior (ash b0 16) (ash b1 8) b2)))
          (write-char (char alphabet (logand (ash n -18) 63)) out)
          (write-char (char alphabet (logand (ash n -12) 63)) out)
          (write-char (if (< (+ i 1) len)
                          (char alphabet (logand (ash n -6) 63))
                          #\=)
                      out)
          (write-char (if (< (+ i 2) len)
                          (char alphabet (logand n 63))
                          #\=)
                      out))))))

;;; ============================================================
;;; draw-image — Embed RGBA image as base64 PNG data URI
;;; ============================================================

(defmethod draw-image ((renderer renderer-svg) gc x y im)
  "Draw an RGBA image IM at position (X, Y) as an embedded base64 PNG in SVG.
IM is a plist with :data (flat RGBA bytes), :width, :height.
Uses zpng to encode PNG via temp file, then base64-encodes the result."
  (declare (ignore gc))
  (let ((data (getf im :data))
        (w (getf im :width))
        (h (getf im :height)))
    (when (and data w h)
      (let* ((png (make-instance 'zpng:png
                                 :color-type :truecolor-alpha
                                 :width w :height h))
             (tmp-path (format nil "/tmp/cl-mpl-svg-~A.png" (get-universal-time))))
        ;; Copy RGBA data into zpng image buffer
        (replace (zpng:image-data png) data)
        ;; Write to temp file (zpng only accepts pathname)
        (zpng:write-png png tmp-path)
        ;; Read bytes back
        (let ((bytes (with-open-file (f tmp-path :element-type '(unsigned-byte 8))
                       (let ((buf (make-array (file-length f)
                                              :element-type '(unsigned-byte 8))))
                         (read-sequence buf f)
                         buf))))
          ;; Delete temp file
          (ignore-errors (delete-file tmp-path))
          ;; Base64 encode and emit <image> element
          (let ((b64 (%octets-to-base64 bytes))
                (out (renderer-svg-output-stream renderer)))
            ;; Y-flip counter: global <g> has scale(1,-1), images render upside-down
            ;; Fix: translate(x,-y) scale(1,-1) — same pattern as draw-text
            (format out "<image x=\"0\" y=\"0\" width=\"~D\" height=\"~D\" xlink:href=\"data:image/png;base64,~A\" transform=\"translate(~A,~A) scale(1,-1)\"/>~%"
                    w h b64
                    (%format-float (coerce x 'double-float))
                    (%format-float (- (coerce y 'double-float))))))))))

;;; ============================================================
;;; draw-markers — <symbol> + <use> optimization for repeated markers
;;; ============================================================

(defmethod draw-markers ((renderer renderer-svg) gc marker-path marker-trans
                         path trans &optional rgbface)
  "Draw a marker at each vertex of PATH using SVG <symbol>/<use> optimization.
Emits one <symbol> definition in defs-stream, then one <use> per data point."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0)))
    (when (zerop n) (return-from draw-markers nil))
    ;; Generate marker shape as SVG d-string
    (let* ((marker-d (%trace-path-to-svg marker-path marker-trans))
           (marker-id (%next-id renderer "marker"))
           ;; Resolve colors
           (face-color (%gc-face-color gc rgbface))
           (edge-color (%gc-edge-color gc))
           (gc-alpha (or (mpl.rendering:gc-alpha gc) 1.0d0))
           (gc-attrs (%apply-gc-to-svg-attrs gc renderer))
           (defs (renderer-svg-defs-stream renderer))
           (out (renderer-svg-output-stream renderer)))
      ;; Emit <symbol> with marker path into defs
      (multiple-value-bind (fill-hex fill-op) (%color-to-svg face-color)
        (multiple-value-bind (stroke-hex stroke-op) (%color-to-svg edge-color)
          (let ((fill-opacity (* fill-op (coerce gc-alpha 'double-float)))
                (stroke-opacity (* stroke-op (coerce gc-alpha 'double-float))))
            (format defs "<symbol id=\"~A\" overflow=\"visible\">~%" marker-id)
            (format defs "<path d=\"~A\" fill=\"~A\" fill-opacity=\"~A\" stroke=\"~A\" stroke-opacity=\"~A\""
                    marker-d fill-hex (%format-float fill-opacity)
                    stroke-hex (%format-float stroke-opacity))
            ;; Stroke width
            (let ((sw (getf gc-attrs :stroke-width)))
              (when sw (format defs " stroke-width=\"~A\"" sw)))
            ;; Stroke line cap
            (let ((cap (getf gc-attrs :stroke-linecap)))
              (when cap (format defs " stroke-linecap=\"~A\"" cap)))
            ;; Stroke line join
            (let ((join (getf gc-attrs :stroke-linejoin)))
              (when join (format defs " stroke-linejoin=\"~A\"" join)))
            (format defs "/>~%")
            (format defs "</symbol>~%"))))
      ;; Emit <use> for each data point vertex
      (dotimes (i n)
        (let ((code (if codes (aref codes i)
                       (if (zerop i) mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
          (when (or (= code mpl.primitives:+moveto+)
                    (= code mpl.primitives:+lineto+))
            (let ((x (aref verts i 0))
                  (y (aref verts i 1)))
              (multiple-value-bind (tx ty)
                  (if trans
                      (let ((result (mpl.primitives:transform-point
                                     trans (list (float x 1.0d0) (float y 1.0d0)))))
                        (values (aref result 0) (aref result 1)))
                      (values (float x 1.0d0) (float y 1.0d0)))
                (format out "<use xlink:href=\"#~A\" x=\"~A\" y=\"~A\"/>~%"
                        marker-id
                        (%format-float tx)
                        (%format-float ty))))))))))

;;; ============================================================
;;; draw-path-collection — Batch path drawing
;;; ============================================================

(defmethod draw-path-collection ((renderer renderer-svg) gc paths all-transforms
                                 offsets offset-trans facecolors edgecolors
                                 linewidths linestyles antialiaseds)
  "Draw a collection of paths efficiently in SVG.
Each item gets its own <path> element with per-item colors and linewidth."
  (declare (ignore linestyles antialiaseds))
  (let* ((n-offsets (if offsets (length offsets) 0))
         (n-paths (if paths (length paths) 0))
         (n-items (max n-offsets n-paths 0))
         (alpha (or (mpl.rendering:gc-alpha gc) 1.0d0)))
    (when (zerop n-items)
      (return-from draw-path-collection))
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
                            1.0)))
        (when path
          ;; Build final transform (item-transform + offset)
          (let ((final-transform nil))
            (when item-transform
              (setf final-transform item-transform))
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
            ;; Trace the path
            (let ((d (%trace-path-to-svg path final-transform)))
              (unless (string= d "")
                ;; Resolve per-item colors via %color-to-svg
                (multiple-value-bind (fill-hex fill-op) (%color-to-svg face-color)
                  (multiple-value-bind (stroke-hex stroke-op) (%color-to-svg edge-color)
                    (let ((out (renderer-svg-output-stream renderer)))
                      (format out "<path d=\"~A\" fill=\"~A\" fill-opacity=\"~A\" stroke=\"~A\" stroke-opacity=\"~A\" stroke-width=\"~A\"/>~%"
                              d fill-hex
                              (%format-float (* fill-op (coerce alpha 'double-float)))
                              stroke-hex
                              (%format-float (* stroke-op (coerce alpha 'double-float)))
                              (%format-float (coerce linewidth 'double-float))))))))))))))

;;; ============================================================
;;; draw-gouraud-triangles — Flat-color average fallback
;;; ============================================================

(defmethod draw-gouraud-triangles ((renderer renderer-svg) gc triangles-array colors-array transform)
  "Draw Gouraud-shaded triangles. Simplified flat-color fallback for SVG.
Averages the 3 vertex colors per triangle and fills with that single color."
  (declare (ignore gc))
  (when (and triangles-array colors-array)
    (let ((n (array-dimension triangles-array 0))
          (out (renderer-svg-output-stream renderer)))
      (dotimes (tri n)
        ;; Average the colors of the 3 vertices (RGBA)
        (let ((r 0.0d0) (g 0.0d0) (b 0.0d0) (a 0.0d0))
          (dotimes (v 3)
            (incf r (coerce (aref colors-array tri v 0) 'double-float))
            (incf g (coerce (aref colors-array tri v 1) 'double-float))
            (incf b (coerce (aref colors-array tri v 2) 'double-float))
            (incf a (coerce (aref colors-array tri v 3) 'double-float)))
          (setf r (/ r 3.0d0) g (/ g 3.0d0) b (/ b 3.0d0) a (/ a 3.0d0))
          ;; Build SVG path: M x0 y0 L x1 y1 L x2 y2 Z
          (flet ((xf (x y)
                   (if transform
                       (let ((result (mpl.primitives:transform-point
                                      transform (list (float x 1.0d0) (float y 1.0d0)))))
                         (values (aref result 0) (aref result 1)))
                       (values (float x 1.0d0) (float y 1.0d0)))))
            (multiple-value-bind (x0 y0) (xf (aref triangles-array tri 0 0)
                                              (aref triangles-array tri 0 1))
              (multiple-value-bind (x1 y1) (xf (aref triangles-array tri 1 0)
                                                (aref triangles-array tri 1 1))
                (multiple-value-bind (x2 y2) (xf (aref triangles-array tri 2 0)
                                                  (aref triangles-array tri 2 1))
                  ;; Convert averaged color to hex + opacity
                  (multiple-value-bind (hex-color opacity)
                      (%color-to-svg (list r g b a))
                    (format out "<path d=\"M ~A ~A L ~A ~A L ~A ~A Z\" fill=\"~A\" fill-opacity=\"~A\" stroke=\"none\" stroke-opacity=\"0.00\"/>~%"
                            (%format-float x0) (%format-float y0)
                            (%format-float x1) (%format-float y1)
                            (%format-float x2) (%format-float y2)
                            hex-color (%format-float opacity))))))))))))

;;; ============================================================
;;; canvas-svg — Canvas implementation for SVG output
;;; ============================================================

(defclass canvas-svg (canvas-base)
  ((render-fn :initform nil
              :accessor canvas-render-fn-svg
              :documentation "Optional render function called during print-svg."))
  (:documentation "Canvas that renders to SVG via raw XML emission.
Usage:
  (let ((canvas (make-instance 'canvas-svg :width 640 :height 480 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer) (draw-path renderer gc path nil)))
    (print-svg canvas \"/tmp/test.svg\"))"))

;;; ============================================================
;;; print-svg generic function
;;; ============================================================

(defgeneric print-svg (canvas filename)
  (:documentation "Render figure and save to SVG file at FILENAME."))

;;; ============================================================
;;; get-renderer
;;; ============================================================

(defmethod get-renderer ((canvas canvas-svg))
  "Return or create the renderer for this canvas."
  (or (canvas-renderer canvas)
      (setf (canvas-renderer canvas)
            (make-instance 'renderer-svg
                           :width (canvas-width canvas)
                           :height (canvas-height canvas)
                           :dpi (canvas-dpi canvas)))))

;;; ============================================================
;;; canvas-draw
;;; ============================================================

(defmethod canvas-draw ((canvas canvas-svg))
  "Clear canvas and invoke the figure's draw method if present."
  (let ((renderer (get-renderer canvas)))
    (renderer-clear renderer)
    (when (canvas-figure canvas)
      (mpl.rendering:draw (canvas-figure canvas) renderer))))

;;; ============================================================
;;; print-svg — Main output method
;;; ============================================================

(defmethod print-svg ((canvas canvas-svg) filename)
  "Render figure to an SVG file.
Assembles the SVG document from defs-stream and output-stream."
  (let* ((w (canvas-width canvas))
         (h (canvas-height canvas))
         (renderer (get-renderer canvas)))
    ;; Reset renderer streams for fresh render
    (setf (renderer-svg-output-stream renderer) (make-string-output-stream))
    (setf (renderer-svg-defs-stream renderer) (make-string-output-stream))
    ;; Set height on renderer (needed for Y-flip counter in text/image)
    (setf (renderer-svg-height renderer) h)
    ;; Clear canvas (white background rect)
    (renderer-clear renderer)
    ;; Execute render function (for direct API usage)
    (when (canvas-render-fn-svg canvas)
      (funcall (canvas-render-fn-svg canvas) renderer))
    ;; If there's a figure, draw it
    (when (canvas-figure canvas)
      (mpl.rendering:draw (canvas-figure canvas) renderer))
    ;; Collect accumulated SVG content
    (let ((defs-content (get-output-stream-string (renderer-svg-defs-stream renderer)))
          (body-content (get-output-stream-string (renderer-svg-output-stream renderer))))
      ;; Write complete SVG document to file
      (with-open-file (s filename
                         :direction :output
                         :if-exists :supersede
                         :external-format :utf-8)
        ;; XML declaration
        (format s "<?xml version=\"1.0\" encoding=\"UTF-8\"?>~%")
        ;; SVG root element with namespaces
        (format s "<svg xmlns=\"http://www.w3.org/2000/svg\"~%")
        (format s "     xmlns:xlink=\"http://www.w3.org/1999/xlink\"~%")
        (format s "     width=\"~D\" height=\"~D\" viewBox=\"0 0 ~D ~D\">~%" w h w h)
        ;; Defs section (clip-paths, symbols)
        (format s "<defs>~%")
        (write-string defs-content s)
        (format s "</defs>~%")
        ;; Global Y-flip: SVG is y-down, figure is y-up
        (format s "<g transform=\"translate(0,~D) scale(1,-1)\">~%" h)
        ;; Body content
        (write-string body-content s)
        ;; Close Y-flip group and SVG
        (format s "</g>~%")
        (format s "</svg>~%"))))
  filename)

;;; ============================================================
;;; Convenience: render-to-svg — functional interface
;;; ============================================================

(defun render-to-svg (filename &key (width 640) (height 480) (dpi 100) draw-fn)
  "Convenience function: create a canvas, call DRAW-FN with the renderer, save SVG.
Example:
  (render-to-svg \"/tmp/test.svg\"
    :width 400 :height 300
    :draw-fn (lambda (renderer)
               (let ((path (mpl.primitives:make-path ...))
                     (gc (make-graphics-context :edgecolor \"red\")))
                 (draw-path renderer gc path nil))))"
  (let ((canvas (make-instance 'canvas-svg :width width :height height :dpi dpi)))
    (setf (canvas-render-fn-svg canvas) draw-fn)
    (print-svg canvas filename)))
