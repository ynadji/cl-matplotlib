;;;; backend-pdf.lisp — cl-pdf based PDF backend for cl-matplotlib
;;;; Implements the RendererBase protocol using cl-pdf for PDF output.
;;;;
;;;; Usage:
;;;;   (let ((canvas (make-instance 'canvas-pdf :width 640 :height 480 :dpi 100)))
;;;;     (setf (canvas-render-fn-pdf canvas)
;;;;           (lambda (renderer) (draw-path renderer gc path nil)))
;;;;     (print-pdf canvas "/tmp/test.pdf"))

(in-package #:cl-matplotlib.backends)

;;; ============================================================
;;; cl-pdf compatibility patch
;;; ============================================================
;;; cl-pdf 2.03 (Quicklisp) is missing pdf::extended-ascii-p which is
;;; called during write-document. Define it if absent.

(unless (fboundp 'pdf::extended-ascii-p)
  (defun pdf::extended-ascii-p (char)
    "Return T if CHAR has a code point above 127 (non-ASCII)."
    (> (char-code char) 127)))

;;; ============================================================
;;; renderer-pdf — cl-pdf based PDF renderer
;;; ============================================================

(defclass renderer-pdf (renderer-base)
  ((font-cache :initform (make-hash-table :test 'equal)
               :accessor renderer-pdf-font-cache
               :documentation "Cache of loaded PDF font objects keyed by name."))
  (:documentation "Renderer implementation using cl-pdf for PDF output.
Uses cl-pdf for path rendering, text, and graphics state management."))

;;; ============================================================
;;; Graphics context → cl-pdf state mapping
;;; ============================================================

(defun %pdf-set-dash-pattern (dash-list phase)
  "Write PDF dash pattern with float-safe formatting.
cl-pdf's set-dash-pattern uses ~d (integer format) which outputs invalid PDF
when given Lisp double-floats (e.g. '3.7d0' instead of '3.7').  We bypass it
and write the PDF 'd' operator directly with ~f formatting."
  (format pdf::*page-stream* "[~{~,2f~^ ~}] ~d d~%"
          (mapcar (lambda (x) (float x 1.0)) dash-list)
          phase))

(defun %apply-gc-to-pdf (gc)
  "Apply a graphics-context's properties to the current cl-pdf state.
Must be called within a pdf:with-page context."
  ;; Line width
  (let ((lw (mpl.rendering:gc-linewidth gc)))
    (when lw (pdf:set-line-width (float lw 1.0))))
  ;; Line cap: PDF uses integers: 0=butt, 1=round, 2=projecting-square
  (let ((cap (mpl.rendering:gc-capstyle gc)))
    (when cap
      (pdf:set-line-cap
       (case cap
         (:butt 0)
         (:round 1)
         (:projecting 2)
         (:square 2)
         (otherwise 0)))))
  ;; Line join: PDF uses integers: 0=miter, 1=round, 2=bevel
  (let ((join (mpl.rendering:gc-joinstyle gc)))
    (when join
      (pdf:set-line-join
       (case join
         (:miter 0)
         (:round 1)
         (:bevel 2)
         (otherwise 0)))))
  ;; Dash pattern — scale by linewidth like SVG
  ;; Base patterns (linewidth-relative):
  ;;   dashed:  (3.7, 1.6)
  ;;   dashdot: (6.4, 1.6, 1.0, 1.6)
  ;;   dotted:  (1.0, 1.65)
  (let ((dashes (mpl.rendering:gc-dashes gc))
        (linestyle (mpl.rendering:gc-linestyle gc))
        (lw (or (mpl.rendering:gc-linewidth gc) 1.0)))
    (cond
      ;; Explicit dash list
      ((and dashes (listp dashes) (not (null dashes)))
       (%pdf-set-dash-pattern dashes 0))
      ;; Named line style — scale by linewidth
      ((and linestyle (not (eq linestyle :solid)))
       (let ((mult (max lw 1.0)))
         (case linestyle
           (:dashed (%pdf-set-dash-pattern (list (* 3.7 mult) (* 1.6 mult)) 0))
           (:dashdot (%pdf-set-dash-pattern (list (* 6.4 mult) (* 1.6 mult) (* 1.0 mult) (* 1.6 mult)) 0))
           (:dotted (%pdf-set-dash-pattern (list (* 1.0 mult) (* 1.65 mult)) 0))
           (otherwise (%pdf-set-dash-pattern '() 0)))))
      ;; Solid line
      (t (%pdf-set-dash-pattern '() 0))))
  ;; Clip rectangle
  (let ((clip-rect (mpl.rendering:gc-clip-rectangle gc)))
    (when clip-rect
      (let ((x0 (mpl.primitives:bbox-x0 clip-rect))
            (y0 (mpl.primitives:bbox-y0 clip-rect))
            (x1 (mpl.primitives:bbox-x1 clip-rect))
            (y1 (mpl.primitives:bbox-y1 clip-rect)))
        (pdf:basic-rect (float x0 1.0) (float y0 1.0)
                        (float (- x1 x0) 1.0)
                        (float (- y1 y0) 1.0))
        (pdf:clip-path)
        (pdf:end-path-no-op)))))

;;; ============================================================
;;; Path analysis helpers
;;; ============================================================

(defun %path-axis-aligned-p (path transform)
  "Return T if PATH contains only axis-aligned (horizontal/vertical) LINETO segments
after applying TRANSFORM. Paths with curves (CURVE3/CURVE4) return NIL.
Used to decide whether to snap stroke coordinates to half-pixel centers."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0)))
    (when (zerop n) (return-from %path-axis-aligned-p t))
    ;; If no codes, synthesize MOVETO + LINETOs
    (unless codes
      (setf codes (make-array n :element-type '(unsigned-byte 8)))
      (setf (aref codes 0) mpl.primitives:+moveto+)
      (loop for j from 1 below n do
        (setf (aref codes j) mpl.primitives:+lineto+)))
    (let ((prev-tx 0.0d0)
          (prev-ty 0.0d0)
          (i 0)
          (tolerance 0.5d0))  ; half-pixel tolerance for "axis-aligned"
      (flet ((xf (x y)
               (if transform
                   (let ((result (mpl.primitives:transform-point
                                  transform (list (float x 1.0d0) (float y 1.0d0)))))
                     (values (aref result 0) (aref result 1)))
                   (values (float x 1.0d0) (float y 1.0d0)))))
        (loop while (< i n) do
          (let ((code (aref codes i)))
            (cond
              ((= code mpl.primitives:+moveto+)
               (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
                 (setf prev-tx tx prev-ty ty))
               (incf i))
              ((= code mpl.primitives:+lineto+)
               (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
                 (let ((dx (abs (- tx prev-tx)))
                       (dy (abs (- ty prev-ty))))
                   ;; Must be horizontal (dy < tol) or vertical (dx < tol)
                   (unless (or (< dx tolerance) (< dy tolerance))
                     (return-from %path-axis-aligned-p nil)))
                 (setf prev-tx tx prev-ty ty))
               (incf i))
              ;; Any curve segment → not axis-aligned
              ((or (= code mpl.primitives:+curve3+)
                   (= code mpl.primitives:+curve4+))
               (return-from %path-axis-aligned-p nil))
              ((= code mpl.primitives:+closepoly+)
               (incf i))
              ((= code mpl.primitives:+stop+)
               (return))
              (t (incf i)))))
        t))))

;;; ============================================================
;;; Path rendering: map mpl-path codes to cl-pdf operations
;;; ============================================================

(defun %trace-path-to-pdf (path transform &key snap-to-half-pixels)
  "Trace an mpl-path into the current cl-pdf path.
TRANSFORM can be an affine-2d or NIL for identity."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0))
         (i 0))
    (when (zerop n) (return-from %trace-path-to-pdf nil))
    ;; If no codes, synthesize MOVETO + LINETOs
    (unless codes
      (setf codes (make-array n :element-type '(unsigned-byte 8)))
      (setf (aref codes 0) mpl.primitives:+moveto+)
      (loop for j from 1 below n do
        (setf (aref codes j) mpl.primitives:+lineto+)))
    (flet ((xf (x y)
             "Apply transform and return (values tx ty)."
             (multiple-value-bind (tx ty)
                 (if transform
                     (let ((result (mpl.primitives:transform-point
                                    transform (list (float x 1.0d0) (float y 1.0d0)))))
                       (values (aref result 0) (aref result 1)))
                     (values (float x 1.0d0) (float y 1.0d0)))
               (if snap-to-half-pixels
                   (flet ((snap-half (v)
                            (let ((frac (mod v 1.0d0)))
                              (if (< (abs (- frac 0.5d0)) 0.02d0)
                                  v  ;; Already at half-pixel — preserve
                                  (+ (float (floor (+ v 0.5d0)) 1.0d0) 0.5d0)))))
                     (values (snap-half tx) (snap-half ty)))
                   (values tx ty)))))
      (loop while (< i n) do
        (let ((code (aref codes i)))
          (cond
            ;; MOVETO
            ((= code mpl.primitives:+moveto+)
             (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
               (pdf:move-to (float tx 1.0) (float ty 1.0)))
             (incf i))
            ;; LINETO
            ((= code mpl.primitives:+lineto+)
             (multiple-value-bind (tx ty) (xf (aref verts i 0) (aref verts i 1))
               (pdf:line-to (float tx 1.0) (float ty 1.0)))
             (incf i))
            ;; CURVE3 (quadratic Bézier): 2 vertices (control + endpoint)
            ;; PDF only supports cubic Bézier, so promote quadratic to cubic
            ((= code mpl.primitives:+curve3+)
             (when (< (1+ i) n)
               ;; Get current point (we need it for quadratic→cubic promotion)
               ;; Quadratic: P0 + 2t(P1-P0) + t²(P2-2P1+P0)
               ;; Cubic equivalent: CP1 = P0 + 2/3*(P1-P0), CP2 = P2 + 2/3*(P1-P2)
               (multiple-value-bind (cx cy) (xf (aref verts i 0) (aref verts i 1))
                 (multiple-value-bind (ex ey) (xf (aref verts (1+ i) 0) (aref verts (1+ i) 1))
                   ;; For quadratic→cubic, we need the current point.
                   ;; Approximate: use the control point as both cubic control points
                   ;; More accurate: CP1 = P0 + 2/3*(P1-P0), CP2 = P2 + 2/3*(P1-P2)
                   ;; Since we don't track current point, use bezier3-to which
                   ;; takes (x1 y1 x3 y3) where x1,y1 is first control = current point
                   ;; Actually, let's just use bezier-to with the control point duplicated
                   ;; as a reasonable approximation
                   (let ((fcx (float cx 1.0))
                         (fcy (float cy 1.0))
                         (fex (float ex 1.0))
                         (fey (float ey 1.0)))
                     (pdf:bezier-to fcx fcy fcx fcy fex fey)))))
             (incf i 2))
            ;; CURVE4 (cubic Bézier): 3 vertices (2 control + endpoint)
            ((= code mpl.primitives:+curve4+)
             (when (< (+ i 2) n)
               (multiple-value-bind (c1x c1y) (xf (aref verts i 0) (aref verts i 1))
                 (multiple-value-bind (c2x c2y) (xf (aref verts (1+ i) 0) (aref verts (1+ i) 1))
                   (multiple-value-bind (ex ey) (xf (aref verts (+ i 2) 0) (aref verts (+ i 2) 1))
                     (pdf:bezier-to (float c1x 1.0) (float c1y 1.0)
                                    (float c2x 1.0) (float c2y 1.0)
                                    (float ex 1.0) (float ey 1.0))))))
             (incf i 3))
            ;; CLOSEPOLY
            ((= code mpl.primitives:+closepoly+)
             (pdf:close-path)
             (incf i))
            ;; STOP
            ((= code mpl.primitives:+stop+)
             (return))
            ;; Unknown
            (t (incf i))))))))

;;; ============================================================
;;; draw-path — Core rendering method
;;; ============================================================

(defmethod draw-path ((renderer renderer-pdf) gc path transform &optional rgbface)
  "Draw a path using cl-pdf. Handles fill, stroke, or fill+stroke.
Must be called within an active PDF page context."
  (let ((edge-color (%gc-edge-color gc))
        (face-color (%gc-face-color gc rgbface))
        (alpha (mpl.rendering:gc-alpha gc))
        (linewidth (mpl.rendering:gc-linewidth gc)))
    (pdf:with-saved-state
      ;; Apply graphics context state
      (%apply-gc-to-pdf gc)
      ;; Set alpha transparency if not fully opaque
      (when (and alpha (< alpha 1.0))
        (pdf:set-transparency (float alpha 1.0)))
      ;; Fill + stroke
      (cond
        ;; Fill and stroke
        ((and face-color edge-color (> (or linewidth 1.0) 0))
         (let ((fr (first face-color))
               (fg (second face-color))
               (fb (third face-color))
               (fa (fourth face-color))
               (er (first edge-color))
               (eg (second edge-color))
               (eb (third edge-color))
               (ea (fourth edge-color)))
           ;; Apply face alpha
           (when (and fa (< fa 1.0))
             (pdf:set-fill-transparency (float (* fa (or alpha 1.0)) 1.0)))
           (when (and ea (< ea 1.0))
             (pdf:set-stroke-transparency (float (* ea (or alpha 1.0)) 1.0)))
           (pdf:set-rgb-fill (float fr 1.0) (float fg 1.0) (float fb 1.0))
           (pdf:set-rgb-stroke (float er 1.0) (float eg 1.0) (float eb 1.0))
           (%trace-path-to-pdf path transform)
           (pdf:fill-and-stroke)))
        ;; Fill only
        (face-color
         (let ((r (first face-color))
               (g (second face-color))
               (b (third face-color))
               (a (fourth face-color)))
           (when (and a (< a 1.0))
             (pdf:set-fill-transparency (float (* a (or alpha 1.0)) 1.0)))
           (pdf:set-rgb-fill (float r 1.0) (float g 1.0) (float b 1.0))
           (%trace-path-to-pdf path transform)
           (pdf:fill-path)))
        ;; Stroke only
        ((and edge-color (> (or linewidth 1.0) 0))
         (let ((r (first edge-color))
               (g (second edge-color))
               (b (third edge-color))
               (a (fourth edge-color)))
           (when (and a (< a 1.0))
             (pdf:set-stroke-transparency (float (* a (or alpha 1.0)) 1.0)))
           (pdf:set-rgb-stroke (float r 1.0) (float g 1.0) (float b 1.0))
           (%trace-path-to-pdf path transform
                               :snap-to-half-pixels (%path-axis-aligned-p path transform))
           (pdf:stroke)))
        ;; No color at all — just stroke in black (only if linewidth > 0)
        ((> (or linewidth 1.0) 0)
         (pdf:set-rgb-stroke 0.0 0.0 0.0)
         (%trace-path-to-pdf path transform
                             :snap-to-half-pixels (%path-axis-aligned-p path transform))
         (pdf:stroke))))))

;;; ============================================================
;;; Bridge: renderer-draw-path from artist protocol → draw-path
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-path ((renderer renderer-pdf) gc path transform
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

(defmethod mpl.rendering:renderer-draw-text ((renderer renderer-pdf) gc x y text
                                             &key angle ha va)
  "Bridge from artist draw text protocol to backend draw-text."
  (draw-text renderer gc (float x 1.0d0) (float y 1.0d0) text nil (or angle 0.0) nil ha va))

;;; ============================================================
;;; Bridge: renderer-draw-image from artist protocol → draw-image
;;; ============================================================

(defmethod mpl.rendering:renderer-draw-image ((renderer renderer-pdf) gc x y image)
  "Bridge from artist draw-image protocol to backend draw-image."
  (draw-image renderer gc x y image))

;;; ============================================================
;;; draw-text — Render text using cl-pdf
;;; ============================================================

(defun %get-pdf-font (renderer font-name)
  "Get or cache a cl-pdf font object by name."
  (let ((cache (renderer-pdf-font-cache renderer)))
    (or (gethash font-name cache)
        (setf (gethash font-name cache)
              (pdf:get-font font-name)))))

(defun %resolve-pdf-font-name (prop)
  "Resolve a font property to a PDF base font name.
PROP can be a font-properties object, a string path, or NIL."
  (cond
    ((null prop) "Helvetica")
    ((stringp prop)
     ;; If it's a path to a TTF file, use Helvetica as fallback
     ;; cl-pdf's built-in fonts are the standard 14 PDF fonts
     (cond
       ((search "Bold" prop :test #'char-equal)
        (if (search "Italic" prop :test #'char-equal)
            "Helvetica-BoldOblique"
            "Helvetica-Bold"))
       ((or (search "Italic" prop :test #'char-equal)
            (search "Oblique" prop :test #'char-equal))
        "Helvetica-Oblique")
       ((or (search "Mono" prop :test #'char-equal)
            (search "Courier" prop :test #'char-equal))
        "Courier")
       ((or (search "Serif" prop :test #'char-equal)
            (search "Times" prop :test #'char-equal))
        "Times-Roman")
       (t "Helvetica")))
    (t "Helvetica")))

(defmethod draw-text ((renderer renderer-pdf) gc x y s prop angle &optional ismath ha va)
  "Draw text string S at position (X, Y) using cl-pdf's text rendering.
PROP is a font path string or NIL (uses Helvetica).
ANGLE is rotation in degrees.
HA is horizontal alignment (:left, :center, :right). Default :left.
VA is vertical alignment (:baseline, :bottom, :center, :top). Default :baseline."
  (declare (ignore ismath))
  (when (or (null s) (string= s ""))
    (return-from draw-text nil))
  (let ((ha (or ha :left))
        (va (or va :baseline)))
    (pdf:with-saved-state
      (let* ((font-name (%resolve-pdf-font-name prop))
             (font (%get-pdf-font renderer font-name))
             (fontsize (or (and gc (mpl.rendering:gc-linewidth gc)) 12.0))
             (edge-color (%gc-edge-color gc))
             (alpha (if gc (mpl.rendering:gc-alpha gc) 1.0)))
        ;; Set text color
        (if edge-color
            (progn
              (pdf:set-rgb-fill (float (first edge-color) 1.0)
                                (float (second edge-color) 1.0)
                                (float (third edge-color) 1.0))
              (when (and (fourth edge-color) (< (* (fourth edge-color) alpha) 1.0))
                (pdf:set-fill-transparency (float (* (fourth edge-color) alpha) 1.0))))
            (pdf:set-rgb-fill 0.0 0.0 0.0))
        ;; Compute alignment offsets using cl-pdf font metrics
        (let* ((text-w (pdf::text-width s font (float fontsize 1.0)))
               (ascender (* (pdf::ascender (pdf:font-metrics font)) (float fontsize 1.0)))
               (descender (pdf:get-font-descender font (float fontsize 1.0)))
               (x-offset (ecase ha
                           (:left 0.0)
                           (:center (- (/ text-w 2.0)))
                           (:right (- text-w))))
               (y-offset (ecase va
                           (:baseline 0.0)
                           (:bottom (- descender))
                           (:top (- ascender))
                           (:center (- (/ (+ ascender descender) 2.0))))))
          ;; Handle rotation
          (when (and (numberp angle) (/= angle 0))
            (pdf:translate (float x 1.0) (float y 1.0))
            (pdf:rotate (float angle 1.0)))
          ;; Draw text
          (pdf:in-text-mode
            (pdf:set-font font (float fontsize 1.0))
            (if (and (numberp angle) (/= angle 0))
                (pdf:move-text (float x-offset 1.0) (float y-offset 1.0))
                (pdf:move-text (float (+ x x-offset) 1.0) (float (+ y y-offset) 1.0)))
            (pdf:draw-text s)))))))

;;; ============================================================
;;; draw-image — Embed image into PDF
;;; ============================================================

(defmethod draw-image ((renderer renderer-pdf) gc x y im)
  "Draw an RGBA image IM at position (X, Y) in the PDF.
IM should be a plist with :data (flat RGBA bytes), :width, :height.
Uses zpng to encode a PNG via temp file, then cl-pdf's make-image/draw-image API."
  (declare (ignore gc))
  (let ((data (getf im :data))
        (w (getf im :width))
        (h (getf im :height)))
    (when (and data w h)
      (let* ((png (make-instance 'zpng:png
                                 :color-type :truecolor-alpha
                                 :width w :height h))
             (tmp-path (format nil "/tmp/cl-mpl-pdf-~A-~A.png"
                               (get-universal-time)
                               (random 100000))))
        ;; Copy RGBA data into zpng image buffer
        (replace (zpng:image-data png) data)
        ;; Write to temp file (zpng only accepts pathname)
        (zpng:write-png png tmp-path)
        ;; Load into cl-pdf, register with page, and draw; clean up temp file
        (unwind-protect
            (let ((pdf-image (pdf:make-image tmp-path)))
              ;; Register image XObject with current page (required by cl-pdf)
              (pdf:add-images-to-page pdf-image)
              (pdf:with-saved-state
                (pdf:draw-image pdf-image
                                (float x 1.0) (float y 1.0)
                                (float w 1.0) (float h 1.0)
                                0)))
          (ignore-errors (delete-file tmp-path)))))))

;;; ============================================================
;;; draw-markers — Repeated path drawing
;;; ============================================================

(defmethod draw-markers ((renderer renderer-pdf) gc marker-path marker-trans
                         path trans &optional rgbface)
  "Draw a marker at each vertex of PATH."
  (let* ((verts (mpl.primitives:mpl-path-vertices path))
         (codes (mpl.primitives:mpl-path-codes path))
         (n (array-dimension verts 0)))
    (when (zerop n) (return-from draw-markers nil))
    (pdf:with-saved-state
      (%apply-gc-to-pdf gc)
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
                                     trans (list x y))))
                        (values (aref result 0) (aref result 1)))
                      (values x y))
                (let ((pos-transform (mpl.primitives:make-affine-2d :translate (list tx ty))))
                  (let ((full-transform (if marker-trans
                                            (mpl.primitives:compose marker-trans pos-transform)
                                            pos-transform)))
                    (draw-path renderer gc marker-path full-transform rgbface)))))))))))

;;; ============================================================
;;; draw-path-collection — Batch path drawing
;;; ============================================================

(defmethod draw-path-collection ((renderer renderer-pdf) gc paths all-transforms
                                 offsets offset-trans facecolors edgecolors
                                 linewidths linestyles antialiaseds)
  "Draw a collection of paths efficiently in PDF."
  (declare (ignore linestyles antialiaseds))
  (let* ((n-offsets (if offsets (length offsets) 0))
         (n-paths (if paths (length paths) 0))
         (n-items (max n-offsets n-paths 0))
         (alpha (mpl.rendering:gc-alpha gc)))
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
            (pdf:with-saved-state
              (pdf:set-line-width (float linewidth 1.0))
              (cond
                ;; Fill and stroke
                ((and face-color edge-color)
                 (pdf:set-rgb-fill (float (first face-color) 1.0)
                                   (float (second face-color) 1.0)
                                   (float (third face-color) 1.0))
                 (when (and (fourth face-color) (< (* (fourth face-color) (float alpha 1.0)) 1.0))
                   (pdf:set-fill-transparency (float (* (fourth face-color) alpha) 1.0)))
                 (pdf:set-rgb-stroke (float (first edge-color) 1.0)
                                     (float (second edge-color) 1.0)
                                     (float (third edge-color) 1.0))
                 (%trace-path-to-pdf path final-transform)
                 (pdf:fill-and-stroke))
                ;; Fill only
                (face-color
                 (pdf:set-rgb-fill (float (first face-color) 1.0)
                                   (float (second face-color) 1.0)
                                   (float (third face-color) 1.0))
                 (%trace-path-to-pdf path final-transform)
                 (pdf:fill-path))
                ;; Stroke only
                (edge-color
                 (pdf:set-rgb-stroke (float (first edge-color) 1.0)
                                     (float (second edge-color) 1.0)
                                     (float (third edge-color) 1.0))
                 (%trace-path-to-pdf path final-transform)
                 (pdf:stroke))))))))))

;;; ============================================================
;;; draw-gouraud-triangles — Simplified flat-color fallback
;;; ============================================================

(defmethod draw-gouraud-triangles ((renderer renderer-pdf) gc triangles-array colors-array transform)
  "Draw Gouraud-shaded triangles. Simplified flat-color fallback for PDF."
  (declare (ignore gc))
  (when (and triangles-array colors-array)
    (let ((n (array-dimension triangles-array 0)))
      (dotimes (tri n)
        ;; Average the colors of the 3 vertices
        (let ((r 0.0) (g 0.0) (b 0.0))
          (dotimes (v 3)
            (incf r (aref colors-array tri v 0))
            (incf g (aref colors-array tri v 1))
            (incf b (aref colors-array tri v 2)))
          (setf r (/ r 3.0) g (/ g 3.0) b (/ b 3.0))
          (pdf:with-saved-state
            (pdf:set-rgb-fill (float r 1.0) (float g 1.0) (float b 1.0))
            ;; Transform and trace the triangle
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
                    (pdf:move-to (float x0 1.0) (float y0 1.0))
                    (pdf:line-to (float x1 1.0) (float y1 1.0))
                    (pdf:line-to (float x2 1.0) (float y2 1.0))
                    (pdf:close-path)
                    (pdf:fill-path)))))))))))

;;; ============================================================
;;; renderer-clear
;;; ============================================================

(defmethod renderer-clear ((renderer renderer-pdf))
  "Clear the PDF page to white background."
  (pdf:set-rgb-fill 1.0 1.0 1.0)
  (pdf:basic-rect 0 0 (renderer-width renderer) (renderer-height renderer))
  (pdf:fill-path))

;;; ============================================================
;;; get-canvas-width-height
;;; ============================================================

(defmethod get-canvas-width-height ((renderer renderer-pdf))
  (values (renderer-width renderer) (renderer-height renderer)))

;;; ============================================================
;;; canvas-pdf — Canvas implementation for cl-pdf PDF output
;;; ============================================================

(defclass canvas-pdf (canvas-base)
  ((render-fn :initform nil
              :accessor canvas-render-fn-pdf
              :documentation "Optional render function called during draw."))
  (:documentation "Canvas that renders to PDF via cl-pdf.
Usage:
  (let ((canvas (make-instance 'canvas-pdf :width 640 :height 480 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer) (draw-path renderer gc path nil)))
    (print-pdf canvas \"/tmp/test.pdf\"))"))

;;; ============================================================
;;; print-pdf generic function
;;; ============================================================

(defgeneric print-pdf (canvas filename)
  (:documentation "Render figure and save to PDF file at FILENAME."))

;;; ============================================================
;;; get-renderer
;;; ============================================================

(defmethod get-renderer ((canvas canvas-pdf))
  "Return or create the renderer for this canvas."
  (or (canvas-renderer canvas)
      (setf (canvas-renderer canvas)
            (make-instance 'renderer-pdf
                           :width (canvas-width canvas)
                           :height (canvas-height canvas)
                           :dpi (canvas-dpi canvas)))))

;;; ============================================================
;;; canvas-draw
;;; ============================================================

(defmethod canvas-draw ((canvas canvas-pdf))
  "Clear canvas and invoke the figure's draw method if present."
  (let ((renderer (get-renderer canvas)))
    (renderer-clear renderer)
    (when (canvas-figure canvas)
      (mpl.rendering:draw (canvas-figure canvas) renderer))))

;;; ============================================================
;;; print-pdf — Main output method
;;; ============================================================

(defmethod print-pdf ((canvas canvas-pdf) filename)
  "Render figure to a PDF file using cl-pdf.
This method establishes the cl-pdf document/page context, executes all
drawing operations, and saves the result to FILENAME."
  (let* ((w (canvas-width canvas))
         (h (canvas-height canvas))
         (renderer (get-renderer canvas))
         (page-bounds (vector 0 0 w h)))
    (pdf:with-document ()
      (pdf:with-page (:bounds page-bounds)
        ;; White background
        (pdf:set-rgb-fill 1.0 1.0 1.0)
        (pdf:basic-rect 0 0 w h)
        (pdf:fill-path)
        ;; Execute render function (for direct API usage)
        (when (canvas-render-fn-pdf canvas)
          (funcall (canvas-render-fn-pdf canvas) renderer))
        ;; If there's a figure, draw it
        (when (canvas-figure canvas)
          (mpl.rendering:draw (canvas-figure canvas) renderer)))
      ;; Save
      (pdf:write-document filename)))
  filename)

;;; ============================================================
;;; Convenience: render-to-pdf — functional interface
;;; ============================================================

(defun render-to-pdf (filename &key (width 640) (height 480) (dpi 100) draw-fn)
  "Convenience function: create a canvas, call DRAW-FN with the renderer, save PDF.
Example:
  (render-to-pdf \"/tmp/test.pdf\"
    :width 400 :height 300
    :draw-fn (lambda (renderer)
               (let ((path (mpl.primitives:make-path ...))
                     (gc (make-graphics-context :edgecolor \"red\")))
                 (draw-path renderer gc path nil))))"
  (let ((canvas (make-instance 'canvas-pdf :width width :height height :dpi dpi)))
    (setf (canvas-render-fn-pdf canvas) draw-fn)
    (print-pdf canvas filename)))
