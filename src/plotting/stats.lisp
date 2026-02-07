;;;; stats.lisp — Statistical plot types (boxplot)
;;;; Ported from matplotlib's axes/_axes.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Statistical utilities
;;; ============================================================

(defun %percentile (sorted-data p)
  "Compute the P-th percentile (0-100) of SORTED-DATA (already sorted list).
Uses linear interpolation."
  (let* ((n (length sorted-data))
         (k (/ (* p (1- n)) 100.0d0))
         (f (floor k))
         (c (ceiling k)))
    (if (= f c)
        (float (elt sorted-data f) 1.0d0)
        (let ((d (- k f)))
          (+ (* (- 1.0d0 d) (float (elt sorted-data f) 1.0d0))
             (* d (float (elt sorted-data c) 1.0d0)))))))

(defun %quartiles (data)
  "Compute Q1, median, Q3 from a list of numbers.
Returns (values q1 median q3)."
  (let ((sorted (sort (mapcar (lambda (x) (float x 1.0d0)) (coerce data 'list)) #'<)))
    (values (%percentile sorted 25)
            (%percentile sorted 50)
            (%percentile sorted 75))))

(defun %whisker-range (data q1 q3 &key (whis 1.5))
  "Compute whisker endpoints using IQR method.
Returns (values whisker-low whisker-high)."
  (let* ((iqr (- q3 q1))
         (low-fence (- q1 (* whis iqr)))
         (high-fence (+ q3 (* whis iqr)))
         (sorted (sort (mapcar (lambda (x) (float x 1.0d0)) (coerce data 'list)) #'<))
         ;; Whisker-low = smallest value >= low-fence
         (wlo (or (find-if (lambda (x) (>= x low-fence)) sorted)
                  (first sorted)))
         ;; Whisker-high = largest value <= high-fence
         (whi (or (find-if (lambda (x) (<= x high-fence)) (reverse sorted))
                  (car (last sorted)))))
    (values wlo whi)))

(defun %find-outliers (data whisker-low whisker-high)
  "Find data points outside the whisker range."
  (remove-if (lambda (x)
               (let ((v (float x 1.0d0)))
                 (and (>= v whisker-low) (<= v whisker-high))))
             (coerce data 'list)))

;;; ============================================================
;;; boxplot — simplified box-and-whisker plot
;;; ============================================================

(defun boxplot (ax data &key (labels nil) (vert t) (widths 0.5)
                              (positions nil) (color nil) (linewidth 1.0)
                              (zorder 2))
  "Draw a simplified box-and-whisker plot.

AX — an axes-base instance.
DATA — a list of datasets (each a sequence of numbers), or a single dataset.
LABELS — list of labels for each box.
VERT — if T, vertical boxes (default). If nil, horizontal.
WIDTHS — box width (number or list).
POSITIONS — x-positions for boxes (default 1, 2, 3, ...).
COLOR — box color.
LINEWIDTH — line width for box edges.
ZORDER — drawing order.

Returns a plist with :boxes :medians :whiskers :caps :fliers."
  (declare (ignore labels))
  (let* ((effective-color (or color "C0"))
         ;; Normalize data to list of datasets
         (datasets (if (and (listp data) (listp (first data)))
                       data
                       (list data)))
         (n-boxes (length datasets))
         (pos (or positions (loop for i from 1 to n-boxes collect (float i 1.0d0))))
         (all-boxes nil)
         (all-medians nil)
         (all-whiskers nil)
         (all-caps nil)
         (all-fliers nil))
    (loop for i from 0 below n-boxes
          for dataset in datasets
          for position = (float (elt pos i) 1.0d0)
          for w = (if (numberp widths) (float widths 1.0d0)
                      (float (elt widths i) 1.0d0))
          for half-w = (* w 0.5d0)
          do (multiple-value-bind (q1 median q3)
                 (%quartiles dataset)
               (multiple-value-bind (wlo whi)
                   (%whisker-range dataset q1 q3)
                 (let ((outliers (%find-outliers dataset wlo whi)))
                   (if vert
                       ;; Vertical box
                       (let* (;; Box: rectangle from Q1 to Q3
                              (box-rect (make-instance 'mpl.rendering:rectangle
                                                       :x0 (- position half-w)
                                                       :y0 q1
                                                       :width w
                                                       :height (- q3 q1)
                                                       :facecolor "white"
                                                       :edgecolor effective-color
                                                       :linewidth linewidth
                                                       :zorder zorder))
                              ;; Median line
                              (med-line (make-instance 'mpl.rendering:line-2d
                                                       :xdata (list (- position half-w) (+ position half-w))
                                                       :ydata (list median median)
                                                       :color effective-color
                                                       :linewidth (* linewidth 1.5)
                                                       :linestyle :solid
                                                       :zorder (1+ zorder)))
                              ;; Lower whisker
                              (wlo-line (make-instance 'mpl.rendering:line-2d
                                                       :xdata (list position position)
                                                       :ydata (list wlo q1)
                                                       :color effective-color
                                                       :linewidth linewidth
                                                       :linestyle :dashed
                                                       :zorder zorder))
                              ;; Upper whisker
                              (whi-line (make-instance 'mpl.rendering:line-2d
                                                       :xdata (list position position)
                                                       :ydata (list q3 whi)
                                                       :color effective-color
                                                       :linewidth linewidth
                                                       :linestyle :dashed
                                                       :zorder zorder))
                              ;; Caps
                              (cap-lo (make-instance 'mpl.rendering:line-2d
                                                     :xdata (list (- position half-w) (+ position half-w))
                                                     :ydata (list wlo wlo)
                                                     :color effective-color
                                                     :linewidth linewidth
                                                     :linestyle :solid
                                                     :zorder zorder))
                              (cap-hi (make-instance 'mpl.rendering:line-2d
                                                     :xdata (list (- position half-w) (+ position half-w))
                                                     :ydata (list whi whi)
                                                     :color effective-color
                                                     :linewidth linewidth
                                                     :linestyle :solid
                                                     :zorder zorder)))
                         ;; Add all artists
                         (setf (mpl.rendering:artist-transform box-rect) (axes-base-trans-data ax))
                         (axes-add-patch ax box-rect)
                         (dolist (line (list med-line wlo-line whi-line cap-lo cap-hi))
                           (setf (mpl.rendering:artist-transform line) (axes-base-trans-data ax))
                           (axes-add-line ax line))
                         ;; Fliers (outlier markers)
                         (when outliers
                           (let ((flier-line (make-instance 'mpl.rendering:line-2d
                                                            :xdata (make-list (length outliers) :initial-element position)
                                                            :ydata (mapcar (lambda (x) (float x 1.0d0)) outliers)
                                                            :color effective-color
                                                            :linewidth 0
                                                            :linestyle :solid
                                                            :marker :circle
                                                            :zorder (1+ zorder))))
                             (setf (mpl.rendering:artist-transform flier-line) (axes-base-trans-data ax))
                             (axes-add-line ax flier-line)
                             (push flier-line all-fliers)))
                         (push box-rect all-boxes)
                         (push med-line all-medians)
                         (push wlo-line all-whiskers)
                         (push whi-line all-whiskers)
                         (push cap-lo all-caps)
                         (push cap-hi all-caps))
                       ;; Horizontal box (swap x/y)
                       (let* ((box-rect (make-instance 'mpl.rendering:rectangle
                                                       :x0 q1
                                                       :y0 (- position half-w)
                                                       :width (- q3 q1)
                                                       :height w
                                                       :facecolor "white"
                                                       :edgecolor effective-color
                                                       :linewidth linewidth
                                                       :zorder zorder))
                              (med-line (make-instance 'mpl.rendering:line-2d
                                                       :xdata (list median median)
                                                       :ydata (list (- position half-w) (+ position half-w))
                                                       :color effective-color
                                                       :linewidth (* linewidth 1.5)
                                                       :linestyle :solid
                                                       :zorder (1+ zorder)))
                              (wlo-line (make-instance 'mpl.rendering:line-2d
                                                       :xdata (list wlo q1)
                                                       :ydata (list position position)
                                                       :color effective-color
                                                       :linewidth linewidth
                                                       :linestyle :dashed
                                                       :zorder zorder))
                              (whi-line (make-instance 'mpl.rendering:line-2d
                                                       :xdata (list q3 whi)
                                                       :ydata (list position position)
                                                       :color effective-color
                                                       :linewidth linewidth
                                                       :linestyle :dashed
                                                       :zorder zorder))
                              (cap-lo (make-instance 'mpl.rendering:line-2d
                                                     :xdata (list wlo wlo)
                                                     :ydata (list (- position half-w) (+ position half-w))
                                                     :color effective-color
                                                     :linewidth linewidth
                                                     :linestyle :solid
                                                     :zorder zorder))
                              (cap-hi (make-instance 'mpl.rendering:line-2d
                                                     :xdata (list whi whi)
                                                     :ydata (list (- position half-w) (+ position half-w))
                                                     :color effective-color
                                                     :linewidth linewidth
                                                     :linestyle :solid
                                                     :zorder zorder)))
                         (setf (mpl.rendering:artist-transform box-rect) (axes-base-trans-data ax))
                         (axes-add-patch ax box-rect)
                         (dolist (line (list med-line wlo-line whi-line cap-lo cap-hi))
                           (setf (mpl.rendering:artist-transform line) (axes-base-trans-data ax))
                           (axes-add-line ax line))
                         (when outliers
                           (let ((flier-line (make-instance 'mpl.rendering:line-2d
                                                            :xdata (mapcar (lambda (x) (float x 1.0d0)) outliers)
                                                            :ydata (make-list (length outliers) :initial-element position)
                                                            :color effective-color
                                                            :linewidth 0
                                                            :linestyle :solid
                                                            :marker :circle
                                                            :zorder (1+ zorder))))
                             (setf (mpl.rendering:artist-transform flier-line) (axes-base-trans-data ax))
                             (axes-add-line ax flier-line)
                             (push flier-line all-fliers)))
                         (push box-rect all-boxes)
                         (push med-line all-medians)
                         (push wlo-line all-whiskers)
                         (push whi-line all-whiskers)
                         (push cap-lo all-caps)
                         (push cap-hi all-caps)))))))
    ;; Update data limits
    (let* ((all-data (apply #'append (mapcar (lambda (d) (coerce d 'list)) datasets)))
           (data-min (reduce #'min (mapcar (lambda (x) (float x 1.0d0)) all-data)))
           (data-max (reduce #'max (mapcar (lambda (x) (float x 1.0d0)) all-data)))
           (pos-min (reduce #'min pos))
           (pos-max (reduce #'max pos))
           (margin (* 0.05d0 (- data-max data-min))))
      (if vert
          (axes-update-datalim ax
                               (list (- pos-min 1.0d0) (+ pos-max 1.0d0))
                               (list (- data-min margin) (+ data-max margin)))
          (axes-update-datalim ax
                               (list (- data-min margin) (+ data-max margin))
                               (list (- pos-min 1.0d0) (+ pos-max 1.0d0)))))
    (axes-autoscale-view ax)
    (list :boxes (nreverse all-boxes)
          :medians (nreverse all-medians)
          :whiskers (nreverse all-whiskers)
          :caps (nreverse all-caps)
          :fliers (nreverse all-fliers))))
