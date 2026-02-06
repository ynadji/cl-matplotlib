;;;; text-path.lisp — Text-to-path conversion
;;;; Ported from matplotlib's textpath.py
;;;; Uses zpb-ttf for glyph outline extraction.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Glyph contour → Path conversion
;;; ============================================================

(defun glyph-contour-to-vertices-and-codes (contour font-loader scale x-offset y-offset)
  "Convert a zpb-ttf contour to vertices and codes lists.
CONTOUR is a zpb-ttf contour object.
SCALE converts font units to target units.
X-OFFSET, Y-OFFSET shift the glyph to its position."
  (declare (ignore font-loader))
  (let ((points (zpb-ttf:explicit-contour-points contour))
        (vertices '())
        (codes '())
        (first-point t))
    (when (null points)
      (return-from glyph-contour-to-vertices-and-codes (values nil nil)))
    (loop for point across points
          for px = (+ x-offset (* (float (zpb-ttf:x point) 1.0d0) scale))
          for py = (+ y-offset (* (float (zpb-ttf:y point) 1.0d0) scale))
          do (cond
               (first-point
                (push (list px py) vertices)
                (push cl-matplotlib.primitives:+moveto+ codes)
                (setf first-point nil))
               ((zpb-ttf:on-curve-p point)
                (push (list px py) vertices)
                (push cl-matplotlib.primitives:+lineto+ codes))
               (t
                ;; Off-curve point: part of quadratic Bézier (CURVE3)
                (push (list px py) vertices)
                (push cl-matplotlib.primitives:+curve3+ codes))))
    ;; Close the contour
    (when vertices
      (let ((first-v (car (last vertices))))
        (push (list (first first-v) (second first-v)) vertices)
        (push cl-matplotlib.primitives:+closepoly+ codes)))
    (values (nreverse vertices) (nreverse codes))))

(defun glyph-to-path (glyph font-loader scale x-offset y-offset)
  "Convert a zpb-ttf glyph to a single mpl-path.
Returns an mpl-path with all contours combined."
  (let ((all-vertices '())
        (all-codes '()))
    (zpb-ttf:do-contours (contour glyph)
      (multiple-value-bind (verts codes)
          (glyph-contour-to-vertices-and-codes contour font-loader scale x-offset y-offset)
        (when verts
          (setf all-vertices (nconc all-vertices verts))
          (setf all-codes (nconc all-codes codes)))))
    (if all-vertices
        (let* ((n (length all-vertices))
               (vert-array (make-array (list n 2) :element-type 'double-float))
               (code-array (make-array n :element-type '(unsigned-byte 8))))
          (loop for v in all-vertices
                for c in all-codes
                for i from 0
                do (setf (aref vert-array i 0) (float (first v) 1.0d0)
                         (aref vert-array i 1) (float (second v) 1.0d0)
                         (aref code-array i) c))
          (cl-matplotlib.primitives:make-path :vertices vert-array :codes code-array))
        ;; Empty glyph (e.g., space)
        nil)))

;;; ============================================================
;;; Text-to-path — main entry point
;;; ============================================================

(defun text-to-path (text font-loader size &optional (x 0.0d0) (y 0.0d0))
  "Convert TEXT string to a list of Path objects.
FONT-LOADER is a zpb-ttf font-loader.
SIZE is the font size in points.
X, Y is the starting position.
Returns a list of mpl-path objects (one per glyph that has outlines)."
  (let* ((units-per-em (zpb-ttf:units/em font-loader))
         (scale (/ (float size 1.0d0) (float units-per-em 1.0d0)))
         (x-pos (float x 1.0d0))
         (y-pos (float y 1.0d0))
         (paths '())
         (prev-glyph nil))
    (loop for char across text
          for glyph = (zpb-ttf:find-glyph (char-code char) font-loader)
          do (when glyph
               ;; Apply kerning
               (when prev-glyph
                 (let ((kern (zpb-ttf:kerning-offset prev-glyph glyph font-loader)))
                   (when kern
                     (incf x-pos (* (float kern 1.0d0) scale)))))
               ;; Convert glyph to path
               (let ((path (glyph-to-path glyph font-loader scale x-pos y-pos)))
                 (when path
                   (push path paths)))
               ;; Advance position
               (incf x-pos (* (float (zpb-ttf:advance-width glyph) 1.0d0) scale))
               (setf prev-glyph glyph)))
    (nreverse paths)))

(defun text-to-compound-path (text font-loader size &optional (x 0.0d0) (y 0.0d0))
  "Convert TEXT to a single compound Path.
Like text-to-path but returns one merged path."
  (let ((paths (text-to-path text font-loader size x y)))
    (if paths
        (cl-matplotlib.primitives:path-make-compound-path paths)
        (cl-matplotlib.primitives:make-path :vertices '()))))

;;; ============================================================
;;; Multi-line text layout
;;; ============================================================

(defun layout-multiline-text (text font-loader size
                               &key (x 0.0d0) (y 0.0d0)
                                    (halign :left) (valign :baseline)
                                    (linespacing 1.2d0)
                                    (rotation 0.0d0))
  "Layout multi-line text (split on newlines).
Returns a list of (paths x-offset y-offset) for each line.

HALIGN: :left, :center, :right
VALIGN: :top, :center, :bottom, :baseline
ROTATION: degrees (currently stored but not applied to paths)
LINESPACING: multiplier for line height."
  (declare (ignore rotation)) ; rotation applied by caller as transform
  (let* ((lines (split-string-by-newlines text))
         (units-per-em (zpb-ttf:units/em font-loader))
         (scale (/ (float size 1.0d0) (float units-per-em 1.0d0)))
         (ascender (* (float (zpb-ttf:ascender font-loader) 1.0d0) scale))
         (descender (* (float (zpb-ttf:descender font-loader) 1.0d0) scale))
         (line-height (* (- ascender descender) (float linespacing 1.0d0)))
         (num-lines (length lines))
         ;; Compute line widths for alignment
         (line-widths (mapcar (lambda (line)
                                (cl-matplotlib.primitives:bbox-width
                                 (get-text-extents line font-loader size)))
                              lines))
         (max-width (if line-widths (apply #'max line-widths) 0.0d0))
         ;; Vertical offset based on valign
         (total-height (* line-height num-lines))
         (y-start (ecase valign
                    (:top (- y ascender))
                    (:center (+ y (/ total-height 2.0d0) (- ascender)))
                    (:bottom (+ y total-height (- ascender)))
                    (:baseline y)))
         (results '()))
    (loop for line in lines
          for width in line-widths
          for i from 0
          for line-y = (- y-start (* i line-height))
          for line-x = (+ x (ecase halign
                              (:left 0.0d0)
                              (:center (/ (- max-width width) 2.0d0))
                              (:right (- max-width width))))
          do (let ((paths (text-to-path line font-loader size line-x line-y)))
               (push (list paths line-x line-y) results)))
    (nreverse results)))

(defun split-string-by-newlines (string)
  "Split STRING by newlines into a list of lines."
  (let ((lines '())
        (start 0))
    (loop for i from 0 below (length string)
          when (char= (char string i) #\Newline)
          do (push (subseq string start i) lines)
             (setf start (1+ i)))
    (push (subseq string start) lines)
    (nreverse lines)))

;;; ============================================================
;;; Get text width/height/descent (for renderer use)
;;; ============================================================

(defun get-text-width-height-descent (text font-loader size)
  "Return (values width height descent) for TEXT at SIZE points.
Width and height are in points. Descent is positive (distance below baseline)."
  (let* ((extents (get-text-extents text font-loader size))
         (width (cl-matplotlib.primitives:bbox-width extents))
         (height (cl-matplotlib.primitives:bbox-height extents))
         (descent (abs (min 0.0d0 (cl-matplotlib.primitives:bbox-y0 extents)))))
    (values width height descent)))
