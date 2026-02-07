;;;; mathtext.lisp — Public interface for mathtext rendering
;;;; Provides mathtext-to-path and mathtext-parser functions.
;;;; Ported from matplotlib's mathtext.py

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; MathTextParser — main public class
;;; ============================================================

(defclass mathtext-parser ()
  ((font-loader-cache :initform (make-hash-table :test 'equal)
                      :accessor mtp-font-loader-cache
                      :documentation "Cache of font-loaders by path."))
  (:documentation "Parser for TeX math expressions.
Converts math strings to positioned glyphs for rendering."))

(defun make-mathtext-parser ()
  "Create a new MathTextParser."
  (make-instance 'mathtext-parser))

(defvar *mathtext-parser* nil
  "Global mathtext parser instance (lazily created).")

(defun ensure-mathtext-parser ()
  "Ensure the global mathtext parser exists."
  (unless *mathtext-parser*
    (setf *mathtext-parser* (make-mathtext-parser)))
  *mathtext-parser*)

;;; ============================================================
;;; mathtext-to-path — Convert math expression to glyph paths
;;; ============================================================

(defun mathtext-to-path (text font-loader fontsize &key (x 0.0d0) (y 0.0d0))
  "Convert a math TEXT string to a list of positioned glyph paths.
TEXT may be wrapped in dollar signs ($...$) for math mode.
FONT-LOADER is a zpb-ttf font-loader.
FONTSIZE is the size in points.
X, Y is the starting position.

Returns (values paths width height depth) where:
- PATHS is a list of mpl-path objects (one per glyph)
- WIDTH, HEIGHT, DEPTH are the overall dimensions."
  (let* ((fontsize (float fontsize 1.0d0))
         (x (float x 1.0d0))
         (y (float y 1.0d0))
         ;; Parse the math expression into a box tree
         (box (mt-parse-math-string text font-loader fontsize))
         ;; Ship the box tree to get positioned glyphs and rects
         (output (mt-ship box :ox x :oy y))
         ;; Convert positioned glyphs to mpl-path objects
         (glyphs (gethash :glyphs output))
         (rects (gethash :rects output))
         (width (gethash :width output))
         (height (gethash :height output))
         (depth (gethash :depth output))
         (all-paths nil))
    ;; Convert each positioned glyph to a path
    (dolist (glyph-info glyphs)
      (let* ((gx (getf (cdr glyph-info) :x))
             (gy (getf (cdr glyph-info) :y))
             (ch (getf (cdr glyph-info) :char))
             (fl (getf (cdr glyph-info) :font-loader))
             (fs (getf (cdr glyph-info) :fontsize))
             (char-code (if (characterp ch)
                            (char-code ch)
                            (if (and (stringp ch) (= (length ch) 1))
                                (char-code (char ch 0))
                                nil))))
        (when (and char-code fl)
          (let ((path (glyph-to-path
                       (zpb-ttf:find-glyph char-code fl)
                       fl
                       (/ fs (float (zpb-ttf:units/em fl) 1.0d0))
                       gx
                       ;; Flip Y: mathtext uses y-up, glyph-to-path also y-up
                       gy)))
            (when path
              (push path all-paths))))))
    ;; Convert rectangles (fraction bars, sqrt bars) to paths
    (dolist (rect-info rects)
      (let* ((rx (getf (cdr rect-info) :x))
             (ry (getf (cdr rect-info) :y))
             (rw (getf (cdr rect-info) :width))
             (rh (getf (cdr rect-info) :height)))
        (when (and rx ry rw rh (> rw 0.0d0) (> rh 0.0d0))
          (let* ((n 5)
                 (verts (make-array (list n 2) :element-type 'double-float))
                 (codes (make-array n :element-type '(unsigned-byte 8))))
            ;; Rectangle path: moveto, 3 lineto, closepoly
            (setf (aref verts 0 0) (float rx 1.0d0)
                  (aref verts 0 1) (float ry 1.0d0)
                  (aref verts 1 0) (float (+ rx rw) 1.0d0)
                  (aref verts 1 1) (float ry 1.0d0)
                  (aref verts 2 0) (float (+ rx rw) 1.0d0)
                  (aref verts 2 1) (float (+ ry rh) 1.0d0)
                  (aref verts 3 0) (float rx 1.0d0)
                  (aref verts 3 1) (float (+ ry rh) 1.0d0)
                  (aref verts 4 0) (float rx 1.0d0)
                  (aref verts 4 1) (float ry 1.0d0))
            (setf (aref codes 0) cl-matplotlib.primitives:+moveto+
                  (aref codes 1) cl-matplotlib.primitives:+lineto+
                  (aref codes 2) cl-matplotlib.primitives:+lineto+
                  (aref codes 3) cl-matplotlib.primitives:+lineto+
                  (aref codes 4) cl-matplotlib.primitives:+closepoly+)
            (push (cl-matplotlib.primitives:make-path :vertices verts :codes codes)
                  all-paths)))))
    (values (nreverse all-paths) width height depth)))

;;; ============================================================
;;; mathtext-get-dimensions — Get dimensions without rendering
;;; ============================================================

(defun mathtext-get-dimensions (text font-loader fontsize)
  "Get the dimensions of a math expression without generating paths.
Returns (values width height depth)."
  (let* ((fontsize (float fontsize 1.0d0))
         (box (mt-parse-math-string text font-loader fontsize)))
    (values (mt-box-width box) (mt-box-height box) (mt-box-depth box))))

;;; ============================================================
;;; mathtext-p — Check if a string contains math
;;; ============================================================

(defun mathtext-p (text)
  "Return T if TEXT contains TeX math (delimited by dollar signs)."
  (and (stringp text)
       (>= (length text) 2)
       (let ((first-dollar (position #\$ text)))
         (and first-dollar
              (position #\$ text :start (1+ first-dollar))))))

;;; ============================================================
;;; mathtext-to-compound-path — Single combined path
;;; ============================================================

(defun mathtext-to-compound-path (text font-loader fontsize &key (x 0.0d0) (y 0.0d0))
  "Convert math TEXT to a single compound path.
Like mathtext-to-path but merges all paths into one."
  (multiple-value-bind (paths width height depth)
      (mathtext-to-path text font-loader fontsize :x x :y y)
    (values (if paths
                (cl-matplotlib.primitives:path-make-compound-path paths)
                (cl-matplotlib.primitives:make-path :vertices '()))
            width height depth)))
