;;;; hatch.lisp — Hatch pattern generation
;;;; Ported from matplotlib's hatch.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Hatch pattern types
;;; ============================================================
;;; Each hatch type computes the number of vertices it needs, then
;;; fills in a portion of a shared vertex/code array.
;;; Patterns tile in a unit square [0,1]×[0,1].

(defparameter *valid-hatch-patterns* '(#\/ #\\ #\| #\- #\+ #\x #\X #\o #\O #\. #\*)
  "Valid hatch pattern characters.")

(defun %count-char (string char)
  "Count occurrences of CHAR in STRING."
  (loop for c across string when (char= c char) count 1))

;;; ============================================================
;;; Horizontal hatch — '-' and '+'
;;; ============================================================

(defun %horizontal-hatch-vertices (hatch density)
  "Generate horizontal hatch line vertices.
Returns (values vertices codes n-vertices)."
  (let ((num-lines (* (+ (%count-char hatch #\-) (%count-char hatch #\+))
                      density)))
    (when (zerop num-lines)
      (return-from %horizontal-hatch-vertices (values nil nil 0)))
    (let* ((n (* num-lines 2))
           (vertices (make-array (list n 2) :element-type 'double-float :initial-element 0.0d0))
           (codes (make-array n :element-type '(unsigned-byte 8)))
           (stepsize (/ 1.0d0 num-lines)))
      (dotimes (i num-lines)
        (let ((y (+ (* i stepsize) (* stepsize 0.5d0)))
              (vi (* i 2)))
          ;; MOVETO at (0, y)
          (setf (aref vertices vi 0) 0.0d0
                (aref vertices vi 1) y
                (aref codes vi) mpl.primitives:+moveto+)
          ;; LINETO at (1, y)
          (setf (aref vertices (1+ vi) 0) 1.0d0
                (aref vertices (1+ vi) 1) y
                (aref codes (1+ vi)) mpl.primitives:+lineto+)))
      (values vertices codes n))))

;;; ============================================================
;;; Vertical hatch — '|' and '+'
;;; ============================================================

(defun %vertical-hatch-vertices (hatch density)
  "Generate vertical hatch line vertices."
  (let ((num-lines (* (+ (%count-char hatch #\|) (%count-char hatch #\+))
                      density)))
    (when (zerop num-lines)
      (return-from %vertical-hatch-vertices (values nil nil 0)))
    (let* ((n (* num-lines 2))
           (vertices (make-array (list n 2) :element-type 'double-float :initial-element 0.0d0))
           (codes (make-array n :element-type '(unsigned-byte 8)))
           (stepsize (/ 1.0d0 num-lines)))
      (dotimes (i num-lines)
        (let ((x (+ (* i stepsize) (* stepsize 0.5d0)))
              (vi (* i 2)))
          (setf (aref vertices vi 0) x
                (aref vertices vi 1) 0.0d0
                (aref codes vi) mpl.primitives:+moveto+)
          (setf (aref vertices (1+ vi) 0) x
                (aref vertices (1+ vi) 1) 1.0d0
                (aref codes (1+ vi)) mpl.primitives:+lineto+)))
      (values vertices codes n))))

;;; ============================================================
;;; NorthEast hatch — '/' and 'x'/'X'
;;; ============================================================

(defun %northeast-hatch-vertices (hatch density)
  "Generate northeast diagonal hatch line vertices."
  (let ((num-lines (* (+ (%count-char hatch #\/)
                         (%count-char hatch #\x)
                         (%count-char hatch #\X))
                      density)))
    (when (zerop num-lines)
      (return-from %northeast-hatch-vertices (values nil nil 0)))
    (let* ((nl1 (1+ num-lines))
           (n (* nl1 2))
           (vertices (make-array (list n 2) :element-type 'double-float :initial-element 0.0d0))
           (codes (make-array n :element-type '(unsigned-byte 8))))
      ;; Steps from -0.5 to 0.5
      (dotimes (i nl1)
        (let ((step (+ -0.5d0 (* (/ 1.0d0 num-lines) i)))
              (vi (* i 2)))
          ;; MOVETO at (0+step, 0-step)
          (setf (aref vertices vi 0) (+ 0.0d0 step)
                (aref vertices vi 1) (- 0.0d0 step)
                (aref codes vi) mpl.primitives:+moveto+)
          ;; LINETO at (1+step, 1-step)
          (setf (aref vertices (1+ vi) 0) (+ 1.0d0 step)
                (aref vertices (1+ vi) 1) (- 1.0d0 step)
                (aref codes (1+ vi)) mpl.primitives:+lineto+)))
      (values vertices codes n))))

;;; ============================================================
;;; SouthEast hatch — '\' and 'x'/'X'
;;; ============================================================

(defun %southeast-hatch-vertices (hatch density)
  "Generate southeast diagonal hatch line vertices."
  (let ((num-lines (* (+ (%count-char hatch #\\)
                         (%count-char hatch #\x)
                         (%count-char hatch #\X))
                      density)))
    (when (zerop num-lines)
      (return-from %southeast-hatch-vertices (values nil nil 0)))
    (let* ((nl1 (1+ num-lines))
           (n (* nl1 2))
           (vertices (make-array (list n 2) :element-type 'double-float :initial-element 0.0d0))
           (codes (make-array n :element-type '(unsigned-byte 8))))
      (dotimes (i nl1)
        (let ((step (+ -0.5d0 (* (/ 1.0d0 num-lines) i)))
              (vi (* i 2)))
          ;; MOVETO at (0+step, 1+step)
          (setf (aref vertices vi 0) (+ 0.0d0 step)
                (aref vertices vi 1) (+ 1.0d0 step)
                (aref codes vi) mpl.primitives:+moveto+)
          ;; LINETO at (1+step, 0+step)
          (setf (aref vertices (1+ vi) 0) (+ 1.0d0 step)
                (aref vertices (1+ vi) 1) (+ 0.0d0 step)
                (aref codes (1+ vi)) mpl.primitives:+lineto+)))
      (values vertices codes n))))

;;; ============================================================
;;; Circle shapes — 'o' (small), 'O' (large), '.' (small filled)
;;; ============================================================

(defun %make-circle-vertices (num-segs)
  "Generate vertices for a unit circle approximation with NUM-SEGS segments."
  (let* ((n (1+ num-segs))
         (verts (make-array (list n 2) :element-type 'double-float))
         (codes (make-array n :element-type '(unsigned-byte 8))))
    (dotimes (i n)
      (let ((angle (* 2.0d0 pi (/ (float i 1.0d0) (float num-segs 1.0d0)))))
        (setf (aref verts i 0) (cos angle)
              (aref verts i 1) (sin angle))
        (setf (aref codes i) (if (zerop i) mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
    ;; Last vertex closes the path
    (setf (aref codes (1- n)) mpl.primitives:+closepoly+)
    (values verts codes)))

(defun %circles-hatch-vertices (hatch density size filled-p)
  "Generate circle hatch shape vertices. SIZE is relative to cell spacing."
  (let ((num-rows density))
    (when (zerop num-rows)
      (return-from %circles-hatch-vertices (values nil nil 0)))
    (let* ((offset (/ 1.0d0 num-rows))
           (circle-segs 16) ; segments per circle approximation
           (all-verts nil)
           (all-codes nil)
           (total-n 0))
      ;; Generate grid of circles
      (loop for row from 0 to num-rows do
        (let ((cols (if (evenp row)
                        (loop for c from 0 to num-rows 
                              collect (* c offset))
                        (loop for c from 0 below num-rows
                              collect (+ (* offset 0.5d0) (* c offset)))))
              (row-pos (* row offset)))
          (dolist (col-pos cols)
            (multiple-value-bind (cverts ccodes) (%make-circle-vertices circle-segs)
              ;; Scale and translate
              (let* ((nverts (array-dimension cverts 0))
                     (scaled (make-array (list nverts 2) :element-type 'double-float))
                     (r (* offset size)))
                (dotimes (i nverts)
                  (setf (aref scaled i 0) (+ col-pos (* r (aref cverts i 0)))
                        (aref scaled i 1) (+ row-pos (* r (aref cverts i 1)))))
                (when (not filled-p)
                  ;; For unfilled circles, add inner circle (0.9× scale)
                  (let* ((inner (make-array (list nverts 2) :element-type 'double-float))
                         (r-inner (* r 0.9d0)))
                    (dotimes (i nverts)
                      (setf (aref inner i 0) (+ col-pos (* r-inner (aref cverts i 0)))
                            (aref inner i 1) (+ row-pos (* r-inner (aref cverts i 1)))))
                    ;; Append inner circle reversed
                    (push inner all-verts)
                    (push ccodes all-codes)
                    (incf total-n nverts)))
                (push scaled all-verts)
                (push ccodes all-codes)
                (incf total-n nverts))))))
      ;; Merge all vertices
      (when (zerop total-n)
        (return-from %circles-hatch-vertices (values nil nil 0)))
      (let ((merged-verts (make-array (list total-n 2) :element-type 'double-float))
            (merged-codes (make-array total-n :element-type '(unsigned-byte 8)))
            (cursor 0))
        (dolist (v (nreverse all-verts))
          (let ((nv (array-dimension v 0)))
            (dotimes (i nv)
              (setf (aref merged-verts (+ cursor i) 0) (aref v i 0)
                    (aref merged-verts (+ cursor i) 1) (aref v i 1)))
            (incf cursor nv)))
        (setf cursor 0)
        (dolist (c (nreverse all-codes))
          (let ((nc (length c)))
            (dotimes (i nc)
              (setf (aref merged-codes (+ cursor i)) (aref c i)))
            (incf cursor nc)))
        (values merged-verts merged-codes total-n)))))

;;; ============================================================
;;; Star shapes — '*'
;;; ============================================================

(defun %make-star-vertices ()
  "Generate vertices for a 5-pointed star."
  (let* ((n-points 11)  ; 5 outer + 5 inner + close
         (verts (make-array (list n-points 2) :element-type 'double-float))
         (codes (make-array n-points :element-type '(unsigned-byte 8))))
    (dotimes (i 10)
      (let* ((angle (- (* (/ pi 5.0d0) i) (/ pi 2.0d0)))
             (r (if (evenp i) 1.0d0 0.4d0)))
        (setf (aref verts i 0) (* r (cos angle))
              (aref verts i 1) (* r (sin angle)))
        (setf (aref codes i) (if (zerop i) mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
    ;; Close
    (setf (aref verts 10 0) (aref verts 0 0)
          (aref verts 10 1) (aref verts 0 1)
          (aref codes 10) mpl.primitives:+closepoly+)
    (values verts codes)))

(defun %star-hatch-vertices (hatch density)
  "Generate star hatch shape vertices."
  (let ((num-rows (* (%count-char hatch #\*) density)))
    (when (zerop num-rows)
      (return-from %star-hatch-vertices (values nil nil 0)))
    (let* ((offset (/ 1.0d0 num-rows))
           (all-verts nil)
           (all-codes nil)
           (total-n 0))
      (multiple-value-bind (sverts scodes) (%make-star-vertices)
        (let ((nv (array-dimension sverts 0))
              (size (* offset (/ 1.0d0 3.0d0))))
          (loop for row from 0 to num-rows do
            (let ((cols (if (evenp row)
                            (loop for c from 0 to num-rows
                                  collect (* c offset))
                            (loop for c from 0 below num-rows
                                  collect (+ (* offset 0.5d0) (* c offset)))))
                  (row-pos (* row offset)))
              (dolist (col-pos cols)
                (let ((scaled (make-array (list nv 2) :element-type 'double-float)))
                  (dotimes (i nv)
                    (setf (aref scaled i 0) (+ col-pos (* size (aref sverts i 0)))
                          (aref scaled i 1) (+ row-pos (* size (aref sverts i 1)))))
                  (push scaled all-verts)
                  (push scodes all-codes)
                  (incf total-n nv)))))))
      (when (zerop total-n)
        (return-from %star-hatch-vertices (values nil nil 0)))
      (let ((merged-verts (make-array (list total-n 2) :element-type 'double-float))
            (merged-codes (make-array total-n :element-type '(unsigned-byte 8)))
            (cursor 0))
        (dolist (v (nreverse all-verts))
          (let ((nv (array-dimension v 0)))
            (dotimes (i nv)
              (setf (aref merged-verts (+ cursor i) 0) (aref v i 0)
                    (aref merged-verts (+ cursor i) 1) (aref v i 1)))
            (incf cursor nv)))
        (setf cursor 0)
        (dolist (c (nreverse all-codes))
          (let ((nc (length c)))
            (dotimes (i nc)
              (setf (aref merged-codes (+ cursor i)) (aref c i)))
            (incf cursor nc)))
        (values merged-verts merged-codes total-n)))))

;;; ============================================================
;;; Main hatch path generator
;;; ============================================================

(defun hatch-get-path (hatch-pattern &optional (density 6))
  "Generate an mpl-path for the given HATCH-PATTERN string.
DENSITY is the number of lines/shapes per unit square (default 6).
Patterns: / \\ | - + x o O . *
Density controlled by repetition: // = denser than /
Returns an mpl-path that tiles to fill a unit square."
  (when (or (null hatch-pattern) (string= hatch-pattern ""))
    (return-from hatch-get-path nil))
  (let ((density (max 1 density))
        (all-vertices nil)
        (all-codes nil)
        (total-vertices 0))
    ;; Generate each pattern type
    (flet ((collect-pattern (gen-fn &rest args)
             (multiple-value-bind (verts codes n)
                 (apply gen-fn args)
               (when (and verts (plusp n))
                 (push verts all-vertices)
                 (push codes all-codes)
                 (incf total-vertices n)))))
      ;; Line patterns
      (collect-pattern #'%horizontal-hatch-vertices hatch-pattern density)
      (collect-pattern #'%vertical-hatch-vertices hatch-pattern density)
      (collect-pattern #'%northeast-hatch-vertices hatch-pattern density)
      (collect-pattern #'%southeast-hatch-vertices hatch-pattern density)
      ;; Shape patterns
      (let ((small-count (%count-char hatch-pattern #\o))
            (large-count (%count-char hatch-pattern #\O))
            (dot-count (%count-char hatch-pattern #\.))
            (star-count (%count-char hatch-pattern #\*)))
        (when (plusp small-count)
          (collect-pattern #'%circles-hatch-vertices hatch-pattern
                           (* small-count density) 0.2d0 nil))
        (when (plusp large-count)
          (collect-pattern #'%circles-hatch-vertices hatch-pattern
                           (* large-count density) 0.35d0 nil))
        (when (plusp dot-count)
          (collect-pattern #'%circles-hatch-vertices hatch-pattern
                           (* dot-count density) 0.1d0 t))
        (when (plusp star-count)
          (collect-pattern #'%star-hatch-vertices hatch-pattern density))))
    ;; Merge all patterns into single path
    (when (zerop total-vertices)
      (return-from hatch-get-path nil))
    (let ((merged-verts (make-array (list total-vertices 2)
                                    :element-type 'double-float
                                    :initial-element 0.0d0))
          (merged-codes (make-array total-vertices
                                    :element-type '(unsigned-byte 8)
                                    :initial-element 0))
          (cursor 0))
      (dolist (v (nreverse all-vertices))
        (let ((nv (array-dimension v 0)))
          (dotimes (i nv)
            (setf (aref merged-verts (+ cursor i) 0) (aref v i 0)
                  (aref merged-verts (+ cursor i) 1) (aref v i 1)))
          (incf cursor nv)))
      (setf cursor 0)
      (dolist (c (nreverse all-codes))
        (let ((nc (length c)))
          (dotimes (i nc)
            (setf (aref merged-codes (+ cursor i)) (aref c i)))
          (incf cursor nc)))
      (mpl.primitives:%make-mpl-path
       :vertices merged-verts
       :codes merged-codes))))
