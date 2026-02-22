;;;; violin.lisp — Violin plot with Gaussian KDE
;;;; Ported from matplotlib's axes/_axes.py violinplot
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Gaussian Kernel Density Estimation
;;; ============================================================

(defun gaussian-kde (dataset eval-points)
  "Compute Gaussian kernel density estimate.

DATASET — list of double-float values (the samples).
EVAL-POINTS — list of double-float values (where to evaluate density).

Returns a list of density values (one per eval-point).
Uses Scott's rule for bandwidth: h = n^(-1/5) * sigma."
  (let ((n (length dataset)))
    ;; Edge case: empty dataset
    (when (zerop n)
      (return-from gaussian-kde
        (make-list (length eval-points) :initial-element 0.0d0)))
    (let* ((data (mapcar (lambda (x) (float x 1.0d0)) dataset))
           ;; Compute mean
           (mean (/ (reduce #'+ data) (float n 1.0d0)))
           ;; Compute standard deviation
           (variance (/ (reduce #'+ (mapcar (lambda (x)
                                              (let ((d (- x mean)))
                                                (* d d)))
                                            data))
                        (float n 1.0d0)))
           (sigma (sqrt variance))
           ;; Scott's rule bandwidth: h = n^(-1/5) * sigma
           ;; Clamp minimum bandwidth to 1.0d-3 for identical-value datasets
           (h (max 1.0d-3 (* (expt (float n 1.0d0) -0.2d0) sigma)))
           ;; Precompute constants
           (inv-n-h (/ 1.0d0 (* (float n 1.0d0) h)))
           (inv-sqrt-2pi (/ 1.0d0 (sqrt (* 2.0d0 pi)))))
      ;; Evaluate density at each point
      (mapcar (lambda (x)
                (let ((xf (float x 1.0d0))
                      (sum 0.0d0))
                  (dolist (xi data)
                    (let* ((u (/ (- xf xi) h))
                           (kernel (* inv-sqrt-2pi (exp (* -0.5d0 u u)))))
                      (incf sum kernel)))
                  (* inv-n-h sum)))
              eval-points))))

;;; ============================================================
;;; violinplot — violin plot
;;; ============================================================

(defun violinplot (ax datasets &key (positions nil) (widths 0.5)
                                    (vert t) (showmedians t) (showextrema t))
  "Draw a violin plot.

AX — an axes-base instance.
DATASETS — a list of datasets (each a list of numbers).
POSITIONS — x-positions for violins (default 1, 2, 3, ...).
WIDTHS — violin width (number or list, default 0.5).
VERT — if T, vertical violins (default). If NIL, horizontal.
SHOWMEDIANS — if T, draw a line at the median (default T).
SHOWEXTREMA — if T, draw lines at min and max (default T).

Returns NIL."
  ;; Normalize datasets — ensure list of lists
  (let* ((dsets (if (and (listp datasets) (listp (first datasets)))
                    datasets
                    (list datasets)))
         (n-violins (length dsets))
         (pos (or positions (loop for i from 1 to n-violins
                                  collect (float i 1.0d0)))))
    (loop for idx from 0 below n-violins
          for dataset in dsets
          for position = (float (elt pos idx) 1.0d0)
          for w = (if (numberp widths) (float widths 1.0d0)
                      (float (elt widths idx) 1.0d0))
          for half-w = (* w 0.5d0)
          do (let ((data-list (mapcar (lambda (x) (float x 1.0d0))
                                     (coerce dataset 'list))))
               (when (and data-list (> (length data-list) 0))
                 (let* ((sorted (sort (copy-list data-list) #'<))
                        (data-min (first sorted))
                        (data-max (car (last sorted)))
                        (data-range (- data-max data-min))
                        ;; 5% padding on each side
                        (pad (* 0.05d0 (max data-range 1.0d-6)))
                        (eval-min (- data-min pad))
                        (eval-max (+ data-max pad))
                        ;; 100 eval points
                        (n-eval 100)
                        (eval-step (/ (- eval-max eval-min)
                                      (float (1- n-eval) 1.0d0)))
                        (eval-points (loop for i from 0 below n-eval
                                           collect (+ eval-min
                                                      (* (float i 1.0d0) eval-step))))
                        ;; Compute KDE
                        (kde-values (gaussian-kde data-list eval-points))
                        ;; Normalize KDE so max = 1.0
                        (kde-max (reduce #'max kde-values))
                        (kde-normalized (if (> kde-max 0.0d0)
                                            (mapcar (lambda (v) (/ v kde-max))
                                                    kde-values)
                                            kde-values))
                        ;; Scale by half-width
                        (kde-scaled (mapcar (lambda (v) (* v half-w))
                                            kde-normalized))
                        ;; Build symmetric polygon vertices
                        ;; Forward: (pos + kde, eval-point) for each point
                        ;; Backward: (pos - kde, eval-point) reversed
                        (total-verts (* 2 n-eval))
                        (verts (make-array (list total-verts 2)
                                           :element-type 'double-float)))
                   ;; Fill vertices
                   (if vert
                       ;; Vertical: x = position ± kde, y = eval-point
                       (progn
                         ;; Forward pass: right side (pos + kde)
                         (dotimes (i n-eval)
                           (setf (aref verts i 0)
                                 (+ position (elt kde-scaled i))
                                 (aref verts i 1)
                                 (elt eval-points i)))
                         ;; Backward pass: left side (pos - kde), reversed
                         (dotimes (i n-eval)
                           (let ((j (- n-eval 1 i)))
                             (setf (aref verts (+ n-eval i) 0)
                                   (- position (elt kde-scaled j))
                                   (aref verts (+ n-eval i) 1)
                                   (elt eval-points j)))))
                       ;; Horizontal: x = eval-point, y = position ± kde
                       (progn
                         ;; Forward pass: top side (pos + kde)
                         (dotimes (i n-eval)
                           (setf (aref verts i 0)
                                 (elt eval-points i)
                                 (aref verts i 1)
                                 (+ position (elt kde-scaled i))))
                         ;; Backward pass: bottom side (pos - kde), reversed
                         (dotimes (i n-eval)
                           (let ((j (- n-eval 1 i)))
                             (setf (aref verts (+ n-eval i) 0)
                                   (elt eval-points j)
                                   (aref verts (+ n-eval i) 1)
                                   (- position (elt kde-scaled j)))))))
                   ;; Create polygon patch
                   (let ((poly (make-instance 'mpl.rendering:polygon
                                              :xy verts
                                              :closed t
                                              :facecolor "C0"
                                              :edgecolor "black"
                                              :linewidth 1.0
                                              :zorder 2)))
                     (setf (mpl.rendering:artist-alpha poly) 0.7d0)
                     (setf (mpl.rendering:artist-transform poly)
                           (axes-base-trans-data ax))
                     (axes-add-patch ax poly))
                   ;; Median line
                   (when showmedians
                     (let* ((median (%percentile sorted 50))
                            (med-line
                              (if vert
                                  (make-instance 'mpl.rendering:line-2d
                                                 :xdata (list (- position half-w)
                                                              (+ position half-w))
                                                 :ydata (list median median)
                                                 :color "white"
                                                 :linewidth 2.0
                                                 :linestyle :solid
                                                 :zorder 3)
                                  (make-instance 'mpl.rendering:line-2d
                                                 :xdata (list median median)
                                                 :ydata (list (- position half-w)
                                                              (+ position half-w))
                                                 :color "white"
                                                 :linewidth 2.0
                                                 :linestyle :solid
                                                 :zorder 3))))
                       (setf (mpl.rendering:artist-transform med-line)
                             (axes-base-trans-data ax))
                       (axes-add-line ax med-line)))
                   ;; Extrema lines
                   (when showextrema
                     (let ((ext-hw (* half-w 0.5d0)))
                       ;; Min line
                       (let ((min-line
                               (if vert
                                   (make-instance 'mpl.rendering:line-2d
                                                  :xdata (list (- position ext-hw)
                                                               (+ position ext-hw))
                                                  :ydata (list data-min data-min)
                                                  :color "black"
                                                  :linewidth 1.0
                                                  :linestyle :solid
                                                  :zorder 3)
                                   (make-instance 'mpl.rendering:line-2d
                                                  :xdata (list data-min data-min)
                                                  :ydata (list (- position ext-hw)
                                                               (+ position ext-hw))
                                                  :color "black"
                                                  :linewidth 1.0
                                                  :linestyle :solid
                                                  :zorder 3))))
                         (setf (mpl.rendering:artist-transform min-line)
                               (axes-base-trans-data ax))
                         (axes-add-line ax min-line))
                       ;; Max line
                       (let ((max-line
                               (if vert
                                   (make-instance 'mpl.rendering:line-2d
                                                  :xdata (list (- position ext-hw)
                                                               (+ position ext-hw))
                                                  :ydata (list data-max data-max)
                                                  :color "black"
                                                  :linewidth 1.0
                                                  :linestyle :solid
                                                  :zorder 3)
                                   (make-instance 'mpl.rendering:line-2d
                                                  :xdata (list data-max data-max)
                                                  :ydata (list (- position ext-hw)
                                                               (+ position ext-hw))
                                                  :color "black"
                                                  :linewidth 1.0
                                                  :linestyle :solid
                                                  :zorder 3))))
                         (setf (mpl.rendering:artist-transform max-line)
                               (axes-base-trans-data ax))
                         (axes-add-line ax max-line))))))))
    ;; Update data limits
    (let* ((all-data (apply #'append
                            (mapcar (lambda (d)
                                      (mapcar (lambda (x) (float x 1.0d0))
                                              (coerce d 'list)))
                                    dsets)))
           (data-min (reduce #'min all-data))
           (data-max (reduce #'max all-data))
           (pos-min (reduce #'min pos))
           (pos-max (reduce #'max pos)))
      (if vert
          (axes-update-datalim ax
                               (list (- pos-min 0.5d0) (+ pos-max 0.5d0))
                               (list data-min data-max))
          (axes-update-datalim ax
                               (list data-min data-max)
                               (list (- pos-min 0.5d0) (+ pos-max 0.5d0))))
      ;; Set position-axis limits like boxplot
      (if vert
          (axes-set-xlim ax :min (- pos-min 0.5d0) :max (+ pos-max 0.5d0))
          (axes-set-ylim ax :min (- pos-min 0.5d0) :max (+ pos-max 0.5d0))))
    (setf (mpl.containers::axes-base-sticky-y-min ax) t)
    (axes-autoscale-view ax)
    ;; Set fixed tick locations on the position axis
    (let ((pos-axis (if vert (axes-base-xaxis ax) (axes-base-yaxis ax)))
          (pos-labels (loop for p in pos
                            collect (%scalar-format-value (float p 1.0d0)))))
      (axis-set-major-locator pos-axis
                               (make-instance 'fixed-locator
                                              :locs (mapcar (lambda (p)
                                                              (float p 1.0d0))
                                                            pos)))
      (axis-set-major-formatter pos-axis
                                 (make-instance 'fixed-formatter :seq pos-labels)))
    nil))
