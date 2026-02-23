;;;; quiver.lisp — Quiver (vector field) plot
;;;; Ported from matplotlib's axes/_axes.py quiver
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; quiver — vector field plot
;;; ============================================================

(defun %quiver-parse-args (args)
  "Parse positional args for quiver.
Returns (values x-list y-list u-list v-list).

Call signatures:
  (u v)       — U, V as 2D arrays (list of lists) or 1D lists; X, Y from indices.
  (x y u v)   — explicit X, Y positions."
  (let ((positional (loop for a in args
                          until (keywordp a)
                          collect a)))
    (cond
      ;; 4 positional: (x y u v)
      ((= (length positional) 4)
       (let ((x (first positional))
             (y (second positional))
             (u (third positional))
             (v (fourth positional)))
         ;; Flatten x, y if needed (could be 1D lists)
         (let ((x-flat (if (and (listp x) (listp (first x)))
                           (apply #'append x)
                           (mapcar (lambda (v) (float v 1.0d0))
                                   (if (listp x) x (coerce x 'list)))))
               (y-flat (if (and (listp y) (listp (first y)))
                           (apply #'append y)
                           (mapcar (lambda (v) (float v 1.0d0))
                                   (if (listp y) y (coerce y 'list)))))
               (u-flat (if (and (listp u) (listp (first u)))
                           (apply #'append u)
                           (mapcar (lambda (v) (float v 1.0d0))
                                   (if (listp u) u (coerce u 'list)))))
               (v-flat (if (and (listp v) (listp (first v)))
                           (apply #'append v)
                           (mapcar (lambda (v) (float v 1.0d0))
                                   (if (listp v) v (coerce v 'list))))))
           ;; If x/y are shorter than u/v (1D positions for 2D grid), expand via meshgrid
           (if (and (< (length x-flat) (length u-flat))
                    (< (length y-flat) (length u-flat)))
               ;; Meshgrid expansion: x is column coords, y is row coords
               (let* ((nx (length x-flat))
                      (ny (length y-flat))
                      (x-grid nil)
                      (y-grid nil))
                 (dotimes (j ny)
                   (dotimes (i nx)
                     (push (float (elt x-flat i) 1.0d0) x-grid)
                     (push (float (elt y-flat j) 1.0d0) y-grid)))
                 (values (nreverse x-grid) (nreverse y-grid) u-flat v-flat))
               (values (mapcar (lambda (v) (float v 1.0d0)) x-flat)
                       (mapcar (lambda (v) (float v 1.0d0)) y-flat)
                       (mapcar (lambda (v) (float v 1.0d0)) u-flat)
                       (mapcar (lambda (v) (float v 1.0d0)) v-flat))))))
      ;; 2 positional: (u v) — generate X, Y from indices
      ((= (length positional) 2)
       (let* ((u (first positional))
              (v (second positional))
              (is-2d (and (listp u) (listp (first u)))))
         (if is-2d
             ;; 2D arrays: rows are Y, cols are X
             (let* ((nrows (length u))
                    (ncols (length (first u)))
                    (x-list nil)
                    (y-list nil)
                    (u-flat nil)
                    (v-flat nil))
               (dotimes (j nrows)
                 (let ((u-row (elt u j))
                       (v-row (elt v j)))
                   (dotimes (i ncols)
                     (push (float i 1.0d0) x-list)
                     (push (float j 1.0d0) y-list)
                     (push (float (elt u-row i) 1.0d0) u-flat)
                     (push (float (elt v-row i) 1.0d0) v-flat))))
               (values (nreverse x-list) (nreverse y-list)
                       (nreverse u-flat) (nreverse v-flat)))
             ;; 1D lists: X from indices
             (let* ((n (length u))
                    (x-list (loop for i from 0 below n
                                  collect (float i 1.0d0)))
                    (u-flat (mapcar (lambda (v) (float v 1.0d0))
                                   (if (listp u) u (coerce u 'list))))
                    (v-flat (mapcar (lambda (v) (float v 1.0d0))
                                   (if (listp v) v (coerce v 'list)))))
               (values x-list
                       (loop for i from 0 below n collect 0.0d0)
                       u-flat v-flat)))))
      (t
       (error "quiver requires 2 or 4 positional arguments (u v) or (x y u v), got ~D"
              (length positional))))))

(defun quiver (ax &rest args &key (scale nil) (width nil) (color "C0")
                                   (alpha nil) (pivot :tail)
                                   &allow-other-keys)
  "Draw a quiver (vector field) plot.

AX — an axes-base instance.

Call signatures:
  (quiver ax u v)           — U, V as 2D arrays, positions from indices
  (quiver ax x y u v)       — explicit X, Y positions

U, V — 2D arrays (list of lists) or 1D lists of vector components.
X, Y — 1D or 2D arrays of positions (optional).
SCALE — arrow scale factor (nil = auto).
WIDTH — shaft width in data units (nil = auto).
COLOR — arrow color (default \"C0\").
ALPHA — transparency (nil = opaque).
PIVOT — :TAIL (default), :MIDDLE, or :TIP.

Returns the quiver-collection."
  ;; Strip keyword args for positional parsing
  (let ((positional-args (loop for rest on args
                               for a = (first rest)
                               until (keywordp a)
                               collect a)))
    (multiple-value-bind (x-list y-list u-list v-list)
        (%quiver-parse-args positional-args)
      (let ((qc (make-instance 'mpl.rendering:quiver-collection
                                :verts nil
                                :x-data x-list
                                :y-data y-list
                                :u-data u-list
                                :v-data v-list
                                :scale scale
                                :width width
                                :pivot pivot
                                :facecolors (list color)
                                :edgecolors (list color)
                                :linewidths '(0.0)
                                :axes-ref ax
                                :zorder 2)))
        (when alpha
          (setf (mpl.rendering:artist-alpha qc) (float alpha 1.0d0)))
        ;; Set transform to axes data transform
        (setf (mpl.rendering:artist-transform qc)
              (axes-base-trans-data ax))
        ;; Add to axes as an artist
        (axes-add-artist ax qc)
        ;; Update data limits
        (axes-update-datalim ax x-list y-list)
        (axes-autoscale-view ax)
        qc))))
