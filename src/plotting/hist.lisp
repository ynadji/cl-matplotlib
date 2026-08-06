;;;; hist.lisp — Histogram plotting
;;;; Ported from matplotlib's axes/_axes.py Axes.hist
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Histogram binning utilities
;;; ============================================================

(defun %compute-bin-edges (data n-bins range)
  "Compute N-BINS+1 evenly spaced bin edges for DATA.
RANGE is (min max) or nil for auto-detection.
Returns a list of bin edges."
  (let* ((data-list (coerce data 'list))
         (dmin (if range (first range) (reduce #'min data-list)))
         (dmax (if range (second range) (reduce #'max data-list))))
    ;; Handle edge case: all values identical
    (when (= dmin dmax)
      (setf dmin (- dmin 0.5d0)
            dmax (+ dmax 0.5d0)))
    (let* ((dmin (float dmin 1.0d0))
           (dmax (float dmax 1.0d0))
           (step (/ (- dmax dmin) n-bins)))
      (loop for i from 0 to n-bins
            collect (+ dmin (* i step))))))

(defun %histogram-counts (data bin-edges)
  "Count data values falling into bins defined by BIN-EDGES.
Returns a list of counts (length = (1- (length bin-edges)))."
  (let* ((n-bins (1- (length bin-edges)))
         (counts (make-array n-bins :initial-element 0))
         (edges (coerce bin-edges 'vector))
         (n-edges (length edges)))
    (dolist (val (coerce data 'list))
      (let ((v (float val 1.0d0)))
        (when (and (>= v (aref edges 0))
                   (<= v (aref edges (1- n-edges))))
          ;; Binary search: find the largest i with edges[i] <= v
          ;; (bisect-right minus one)
          (let ((lo 0)
                (hi n-edges))
            (loop while (< lo hi)
                  do (let ((mid (floor (+ lo hi) 2)))
                       (if (<= (aref edges mid) v)
                           (setf lo (1+ mid))
                           (setf hi mid))))
            ;; Clamp so the right edge is included in the last bin
            (let ((bin (min (1- lo) (1- n-bins))))
              (incf (aref counts bin)))))))
    (coerce counts 'list)))

(defun %normalize-to-density (counts bin-edges)
  "Normalize histogram counts to probability density.
Result: sum of area (count * bin_width) = 1.0."
  (let* ((total (reduce #'+ counts))
         (n (length counts))
         ;; Needs random access: (1+ i) pattern — coerce to vector
         (edges-vec (coerce bin-edges 'vector)))
    (if (zerop total)
        (make-list n :initial-element 0.0d0)
        (loop for i from 0 below n
              for count in counts
              for width = (- (aref edges-vec (1+ i)) (aref edges-vec i))
              collect (if (zerop width) 0.0d0
                          (float (/ count (* total width)) 1.0d0))))))

(defun %cumulative-histogram (counts)
  "Convert histogram counts to cumulative counts."
  (let ((cumsum 0))
    (mapcar (lambda (c) (incf cumsum c) cumsum) counts)))

;;; ============================================================
;;; hist — histogram plotting
;;; ============================================================

(defun hist (ax data &key (bins 10) (range nil) (density nil) (cumulative nil)
                          (histtype :bar) (color nil) (edgecolor "black")
                          (linewidth 1.0) (alpha nil) (label "") (zorder 1))
  "Plot a histogram.

AX — an axes-base instance.
DATA — sequence of data values.
BINS — number of bins (integer) or list of bin edges.
RANGE — (min max) range for binning (nil for auto).
DENSITY — if T, normalize to probability density.
CUMULATIVE — if T, cumulative histogram.
HISTTYPE — :bar (default), :step, :stepfilled.
COLOR — bar face color (default C0).
EDGECOLOR — bar edge color (default black).
LINEWIDTH — edge line width (default 0.5).
ALPHA — transparency.
LABEL — legend label.
ZORDER — drawing order (default 1).

Returns (values counts bin-edges patches)."
  (let* ((effective-color (or color "C0"))
         ;; Compute bin edges (BINS may be a count, or a list/vector of edges)
         (bin-edges (if (and (typep bins 'sequence) (not (stringp bins)))
                        (coerce bins 'list)
                        (%compute-bin-edges data bins range)))
         ;; Compute histogram counts
         (counts (%histogram-counts data bin-edges))
         ;; matplotlib semantics: density is computed first, then cumulated
         ;; as cumsum(density * bin_width) — a CDF ending at 1.0. Cumulating
         ;; raw counts and then density-normalizing those is wrong in both
         ;; shape and scale.
         (heights (cond
                    ((and density cumulative)
                     (let ((dens (%normalize-to-density counts bin-edges))
                           (edges-vec (coerce bin-edges 'vector))
                           (cumsum 0.0d0))
                       (loop for d in dens
                             for i from 0
                             do (incf cumsum
                                      (* d (- (aref edges-vec (1+ i))
                                              (aref edges-vec i))))
                             collect cumsum)))
                    (density
                     (%normalize-to-density counts bin-edges))
                    (cumulative
                     (mapcar (lambda (c) (float c 1.0d0))
                             (%cumulative-histogram counts)))
                    (t
                     (mapcar (lambda (c) (float c 1.0d0)) counts))))
         ;; Create patches/artists
         (patches nil))
    ;; Coerce bin-edges to vector once — all hist types need random access (1+ i)
    (let ((be-vec (coerce bin-edges 'vector)))
    (ecase histtype
      (:bar
       ;; Create rectangle patches for each bin
       (loop for i from 0 below (length heights)
             for h in heights
             for left = (float (aref be-vec i) 1.0d0)
             for right = (float (aref be-vec (1+ i)) 1.0d0)
             for width = (- right left)
              do (let ((rect (make-instance 'mpl.rendering:rectangle
                                           :x0 left
                                           :y0 0.0d0
                                           :width width
                                           :height h
                                           :facecolor effective-color
                                           :edgecolor edgecolor
                                           :linewidth linewidth
                                           :zorder zorder)))
                  (when alpha
                    (setf (mpl.rendering:artist-alpha rect) (float alpha 1.0d0)))
                  ;; Set label on first rect for legend auto-collect
                  (when (and (= i 0) label (plusp (length label)))
                    (setf (mpl.rendering:artist-label rect) label))
                  (setf (mpl.rendering:artist-transform rect)
                        (axes-base-trans-data ax))
                  (axes-add-patch ax rect)
                  (push rect patches))))
      (:step
       ;; Create step path as Line2D
       (let ((step-x nil) (step-y nil))
         ;; Build step path: for each bin, horizontal line at top
         (loop for i from 0 below (length heights)
               for left = (float (aref be-vec i) 1.0d0)
               for right = (float (aref be-vec (1+ i)) 1.0d0)
               for h in heights
               do (push left step-x) (push h step-y)
                  (push right step-x) (push h step-y))
         ;; Close to baseline
         (push (float (car (last bin-edges)) 1.0d0) step-x)
         (push 0.0d0 step-y)
         (push (float (first bin-edges) 1.0d0) step-x)
         (push 0.0d0 step-y)
         (setf step-x (nreverse step-x)
               step-y (nreverse step-y))
         (let ((line (make-instance 'mpl.rendering:line-2d
                                    :xdata step-x
                                    :ydata step-y
                                    :color effective-color
                                    :linewidth (or linewidth 1.5)
                                    :linestyle :solid
                                    :label label
                                    :zorder zorder)))
           (setf (mpl.rendering:artist-transform line)
                 (axes-base-trans-data ax))
           (axes-add-line ax line)
           (push line patches))))
      (:stepfilled
       ;; Create filled step polygon
       (let ((verts-x nil) (verts-y nil))
         ;; Forward pass along top of bins
         (loop for i from 0 below (length heights)
               for left = (float (aref be-vec i) 1.0d0)
               for right = (float (aref be-vec (1+ i)) 1.0d0)
               for h in heights
               do (push left verts-x) (push h verts-y)
                  (push right verts-x) (push h verts-y))
         ;; Close back along baseline
         (push (float (car (last bin-edges)) 1.0d0) verts-x)
         (push 0.0d0 verts-y)
         (push (float (first bin-edges) 1.0d0) verts-x)
         (push 0.0d0 verts-y)
         (setf verts-x (nreverse verts-x)
               verts-y (nreverse verts-y))
         (let* ((n (length verts-x))
                (verts (make-array (list n 2) :element-type 'double-float)))
           (loop for vx in verts-x
                 for vy in verts-y
                 for i from 0
                 do (setf (aref verts i 0) vx
                          (aref verts i 1) vy))
           (let ((poly (make-instance 'mpl.rendering:polygon
                                      :xy verts
                                      :closed t
                                      :facecolor effective-color
                                      :edgecolor edgecolor
                                      :linewidth (or linewidth 0.5)
                                      :label label
                                      :zorder zorder)))
             (when alpha
               (setf (mpl.rendering:artist-alpha poly) (float alpha 1.0d0)))
             (setf (mpl.rendering:artist-transform poly)
                   (axes-base-trans-data ax))
             (axes-add-patch ax poly)
             (push poly patches)))))))
    ;; Update data limits
    (let* ((all-x (coerce bin-edges 'list))
           (all-y (cons 0.0d0 heights)))
      (axes-update-datalim ax all-x all-y))
    (setf (mpl.containers::axes-base-sticky-y-min ax) t)
    (axes-autoscale-view ax)
    ;; Clamp y_min to 0 (matching matplotlib's hist behavior)
    (axes-set-ylim ax :min 0.0d0)
    ;; Return values matching matplotlib: n is the plotted values
    ;; (with density/cumulative applied), not the raw counts
    (values heights bin-edges (nreverse patches))))
