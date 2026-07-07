;;;; geoms.lisp — geom protocol, layer construction, geom-blank
;;;;
;;;; PR0 scope: the protocol plus geom-blank (draws nothing, trains scales),
;;;; which is what a layer-less ggplot renders with implicitly.

(in-package #:ggplot)

;;; ============================================================
;;; Geom protocol
;;; ============================================================

(defgeneric geom-default-aes (geom)
  (:documentation "Plist of default fixed aesthetic values for GEOM.")
  (:method ((geom geom)) '()))

(defgeneric geom-setup-data (geom data &key &allow-other-keys)
  (:documentation "Derive geometry columns (e.g. bar x/width -> xmin/xmax).")
  (:method ((geom geom) data &key) data))

(defgeneric geom-draw-panel (geom data panel axes)
  (:documentation "Draw one panel's worth of DATA (a gtable of fully mapped
aesthetic columns) onto AXES. PANEL carries the panel parameters (ranges,
breaks) computed at build time."))

(defgeneric geom-legend-artist (geom key-plist)
  (:documentation "Return a detached proxy artist representing one legend key.")
  (:method ((geom geom) key-plist) (declare (ignore key-plist)) nil))

;;; ============================================================
;;; Layer construction
;;; ============================================================

(defun make-layer (&key geom (stat :identity) (position :identity)
                        mapping data params (show-legend :auto) (inherit-aes t))
  (make-instance 'layer
                 :geom geom
                 :stat (resolve-stat stat)
                 :position (resolve-position position)
                 :mapping mapping
                 :data data
                 :params params
                 :show-legend show-legend
                 :inherit-aes inherit-aes))

;;; ============================================================
;;; geom-blank
;;; ============================================================

(defclass geom-blank-obj (geom) ())

(defmethod geom-draw-panel ((geom geom-blank-obj) data panel axes)
  (declare (ignore data panel axes))
  nil)

(defun geom-blank (&key mapping data)
  "A geom that draws nothing but still trains scales on its data.
Added implicitly when a plot has no layers, so (ggplot data (aes ...))
renders an empty panel scaled to the data — like ggplot2."
  (make-layer :geom (make-instance 'geom-blank-obj)
              :mapping mapping :data data :show-legend nil))

;;; ============================================================
;;; Size unit conversion
;;; ============================================================
;;; plotnine multiplies gg sizes by SIZE_FACTOR = sqrt(pi) to get matplotlib
;;; points (plotnine/_utils SIZE_FACTOR). Points additionally add the stroke
;;; width on each side (geom_point: size = (size + stroke) * SIZE_FACTOR,
;;; edge linewidth = stroke * SIZE_FACTOR). Our backend scatter draws
;;; fill-only, so the stroke ring is folded into the diameter.

(defconstant +size-factor+ 1.7724538509055159d0)  ; sqrt(pi)

(defun size-to-linewidth (size)
  "gg line size -> backend linewidth (points)."
  (* (float size 1.0d0) +size-factor+))

(defun size-to-scatter-s (size &optional (stroke 0.5d0))
  "gg point size -> matplotlib-style scatter S (area, points^2).
Includes the stroke ring plotnine draws as marker edge."
  (expt (* (+ (float size 1.0d0) (* 2.0d0 (float stroke 1.0d0)))
           +size-factor+)
        2))

;;; ============================================================
;;; Shared draw helpers
;;; ============================================================

(defun %column-value (table name default)
  "First value of column NAME, or DEFAULT. PR1 geoms draw uniformly from
the first row; per-row aesthetics arrive with the scale-mapping slice."
  (let ((col (gtable-column table name)))
    (if (and col (plusp (length col)))
        (svref col 0)
        default)))

;;; ============================================================
;;; geom-point
;;; ============================================================

(defclass geom-point-obj (geom) ())

(defmethod geom-default-aes ((geom geom-point-obj))
  '(:color "black" :size 1.5d0 :alpha 1.0d0 :shape :o :stroke 0.5d0))

(defun %uniform-column-p (col)
  (or (null col)
      (loop for i from 1 below (length col)
            always (equal (svref col i) (svref col 0)))))

(defmethod geom-draw-panel ((geom geom-point-obj) data panel axes)
  (declare (ignore panel))
  (let ((x (gtable-column data :x))
        (y (gtable-column data :y))
        (color (gtable-column data :color))
        (size (gtable-column data :size))
        (stroke (gtable-column data :stroke)))
    (when (and x y (plusp (length x)))
      (let ((n (length x)))
        (cl-matplotlib.containers:scatter
         axes (coerce x 'list) (coerce y 'list)
         ;; uniform values keep the backend's single-value fast path;
         ;; varying columns go through per-item collection properties
         :c (if (%uniform-column-p color)
                (if color (svref color 0) "black")
                (coerce color 'list))
         :s (let ((sizes (loop for i from 0 below n
                               collect (size-to-scatter-s
                                        (if size (svref size i) 1.5d0)
                                        (if stroke (svref stroke i) 0.5d0)))))
              (if (every (lambda (v) (= v (first sizes))) sizes)
                  (first sizes)
                  sizes))
         :marker (%column-value data :shape :o)
         :alpha (%column-value data :alpha 1.0d0)
         :zorder 2)))))

(defmethod geom-legend-artist ((geom geom-point-obj) key-plist)
  (make-instance 'cl-matplotlib.rendering:line-2d
                 :xdata '(0.0d0) :ydata '(0.0d0)
                 :marker :o
                 :linestyle :none
                 :color (getf key-plist :value "black")
                 :markersize 6.0d0))

(defun geom-point (&rest args &key mapping data (stat :identity) (position :identity)
                                   (show-legend :auto) (inherit-aes t)
                                   &allow-other-keys)
  "Scatter points. Fixed aesthetics (:color :size :alpha :shape) may be
passed as keywords; mapped aesthetics come from (aes ...)."
  (let ((params (loop for (k v) on args by #'cddr
                      unless (member k '(:mapping :data :stat :position
                                         :show-legend :inherit-aes))
                        append (list k v))))
    (make-layer :geom (make-instance 'geom-point-obj)
                :stat stat :position position
                :mapping mapping :data data :params params
                :show-legend show-legend :inherit-aes inherit-aes)))

;;; ============================================================
;;; geom-line / geom-path
;;; ============================================================

(defclass geom-path-obj (geom) ())
(defclass geom-line-obj (geom-path-obj) ())

(defmethod geom-default-aes ((geom geom-path-obj))
  '(:color "black" :size 0.5d0 :alpha 1.0d0 :linetype :solid))

(defmethod geom-setup-data ((geom geom-line-obj) data &key)
  ;; geom-line connects points in x order; geom-path in data order
  (gtable-sort-by data :x))

(defmethod geom-draw-panel ((geom geom-path-obj) data panel axes)
  (declare (ignore panel))
  (let ((x (gtable-column data :x))
        (y (gtable-column data :y)))
    (when (and x y (> (length x) 1))
      (cl-matplotlib.containers:plot
       axes (coerce x 'list) (coerce y 'list)
       :color (%column-value data :color "black")
       :linewidth (size-to-linewidth (%column-value data :size 0.5d0))
       :linestyle (%column-value data :linetype :solid)
       :zorder 2))))

(defun %make-path-layer (geom-class args)
  (destructuring-bind (&key mapping data (stat :identity) (position :identity)
                            (show-legend :auto) (inherit-aes t) &allow-other-keys)
      args
    (let ((params (loop for (k v) on args by #'cddr
                        unless (member k '(:mapping :data :stat :position
                                           :show-legend :inherit-aes))
                          append (list k v))))
      (make-layer :geom (make-instance geom-class)
                  :stat stat :position position
                  :mapping mapping :data data :params params
                  :show-legend show-legend :inherit-aes inherit-aes))))

(defun geom-line (&rest args &key mapping data stat position show-legend inherit-aes
                                  &allow-other-keys)
  "Connect observations in order of the x aesthetic."
  (declare (ignore mapping data stat position show-legend inherit-aes))
  (%make-path-layer 'geom-line-obj args))

;;; ============================================================
;;; geom-bar / geom-col
;;; ============================================================

(defclass geom-bar-obj (geom) ())

(defmethod geom-default-aes ((geom geom-bar-obj))
  '(:fill "#595959" :color nil :size 0.5d0 :alpha 1.0d0 :width 0.9d0))

(defmethod geom-setup-data ((geom geom-bar-obj) data &key)
  "x + width -> xmin/xmax; y -> ymin 0, ymax y."
  (let* ((x (gtable-column data :x))
         (y (gtable-column data :y))
         (width (gtable-column data :width))
         (n (length x)))
    (unless (and x y)
      (error "geom-bar/geom-col require x and y aesthetics after the stat"))
    (let ((xmin (make-array n)) (xmax (make-array n))
          (ymin (make-array n)) (ymax (make-array n)))
      (dotimes (i n)
        (let ((w (if width (float (svref width i) 1.0d0) 0.9d0))
              (xc (float (svref x i) 1.0d0)))
          (setf (aref xmin i) (- xc (/ w 2.0d0))
                (aref xmax i) (+ xc (/ w 2.0d0))
                (aref ymin i) 0.0d0
                (aref ymax i) (float (svref y i) 1.0d0))))
      (gtable-set-column
       (gtable-set-column
        (gtable-set-column
         (gtable-set-column data :xmin xmin) :xmax xmax)
        :ymin ymin)
       :ymax ymax))))

(defmethod geom-draw-panel ((geom geom-bar-obj) data panel axes)
  (declare (ignore panel))
  (let ((xmin (gtable-column data :xmin))
        (xmax (gtable-column data :xmax))
        (ymin (gtable-column data :ymin))
        (ymax (gtable-column data :ymax))
        (fill (gtable-column data :fill))
        (color (gtable-column data :color))
        (alpha (gtable-column data :alpha))
        (size (gtable-column data :size)))
    (dotimes (i (length xmin))
      (let* ((edge (and color (svref color i)))
             (rect (make-instance 'cl-matplotlib.rendering:rectangle
                                  :x0 (float (svref xmin i) 1.0d0)
                                  :y0 (float (svref ymin i) 1.0d0)
                                  :width (float (- (svref xmax i) (svref xmin i)) 1.0d0)
                                  :height (float (- (svref ymax i) (svref ymin i)) 1.0d0)
                                  :facecolor (if fill (svref fill i) "#595959")
                                  :edgecolor edge
                                  :linewidth (if edge
                                                 (size-to-linewidth
                                                  (if size (svref size i) 0.5d0))
                                                 0.0d0)
                                  :zorder 2)))
        (when alpha
          (setf (cl-matplotlib.rendering:artist-alpha rect)
                (float (svref alpha i) 1.0d0)))
        (cl-matplotlib.containers:axes-add-patch axes rect)))))

(defmethod geom-legend-artist ((geom geom-bar-obj) key-plist)
  (make-instance 'cl-matplotlib.rendering:rectangle
                 :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0
                 :facecolor (getf key-plist :value "#595959")
                 :edgecolor nil :linewidth 0.0d0))

(defun %make-bar-layer (args &key (stat :count))
  (destructuring-bind (&key mapping data (position :stack)
                            (show-legend :auto) (inherit-aes t)
                            &allow-other-keys)
      args
    (let ((params (loop for (k v) on args by #'cddr
                        unless (member k '(:mapping :data :stat :position
                                           :show-legend :inherit-aes))
                          append (list k v))))
      (make-layer :geom (make-instance 'geom-bar-obj)
                  :stat (getf args :stat stat) :position position
                  :mapping mapping :data data :params params
                  :show-legend show-legend :inherit-aes inherit-aes))))

(defun %make-geom-layer (geom-class args &key (stat :identity) (position :identity))
  "Generic layer constructor: keyword args other than the layer options
become fixed-aesthetic params. STAT/POSITION defaults may be overridden
per call via :stat/:position in ARGS."
  (let ((default-stat stat)
        (default-position position))
    (destructuring-bind (&key mapping data stat position
                              (show-legend :auto) (inherit-aes t)
                              &allow-other-keys)
        args
      (let ((params (loop for (k v) on args by #'cddr
                          unless (member k '(:mapping :data :stat :position
                                             :show-legend :inherit-aes))
                            append (list k v))))
        (make-layer :geom (make-instance geom-class)
                    :stat (or stat default-stat)
                    :position (or position default-position)
                    :mapping mapping :data data :params params
                    :show-legend show-legend :inherit-aes inherit-aes)))))

(defun geom-bar (&rest args &key mapping data stat position show-legend inherit-aes
                                 width fill color alpha &allow-other-keys)
  "Bars whose height is the count of rows at each x (stat-count).
Default position is :stack, like ggplot2."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   width fill color alpha))
  (%make-bar-layer args :stat :count))

(defun geom-col (&rest args &key mapping data stat position show-legend inherit-aes
                                 width fill color alpha &allow-other-keys)
  "Bars whose height is a mapped y value (stat-identity)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   width fill color alpha))
  (%make-bar-layer args :stat :identity))

(defun geom-path (&rest args &key mapping data stat position show-legend inherit-aes
                                  &allow-other-keys)
  "Connect observations in the order they appear in the data."
  (declare (ignore mapping data stat position show-legend inherit-aes))
  (%make-path-layer 'geom-path-obj args))

;;; ============================================================
;;; geom-histogram / geom-freqpoly
;;; ============================================================

(defun geom-histogram (&rest args &key mapping data stat position show-legend
                                       inherit-aes bins binwidth boundary
                                       fill color alpha &allow-other-keys)
  "Binned bars of a continuous variable (stat-bin, position stack)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color alpha))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:bins :binwidth :boundary))
                       append (list k v))))
    (%make-bar-layer (list* :stat (make-instance 'stat-bin-obj
                                                 :bins bins
                                                 :binwidth binwidth
                                                 :boundary boundary)
                            clean)
                     :stat :bin)))

(defun geom-freqpoly (&rest args &key mapping data stat position show-legend
                                      inherit-aes bins binwidth &allow-other-keys)
  "Frequency polygon: binned counts drawn as a line."
  (declare (ignore mapping data stat position show-legend inherit-aes))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:bins :binwidth))
                       append (list k v))))
    (%make-path-layer 'geom-path-obj
                      (list* :stat (make-instance 'stat-bin-obj
                                                  :bins bins :binwidth binwidth)
                             clean))))

;;; ============================================================
;;; geom-area / geom-ribbon / geom-density
;;; ============================================================

(defclass geom-ribbon-obj (geom) ())
(defclass geom-area-obj (geom-ribbon-obj) ())
(defclass geom-density-obj (geom-area-obj) ())

(defmethod geom-default-aes ((geom geom-ribbon-obj))
  '(:color nil :fill "#333333" :size 0.5d0 :alpha 1.0d0 :linetype :solid))

(defmethod geom-default-aes ((geom geom-density-obj))
  '(:color "black" :fill nil :size 0.5d0 :alpha 1.0d0 :linetype :solid))

(defmethod geom-setup-data ((geom geom-area-obj) data &key)
  "Area sits on the x axis: ymin 0, ymax y; sorted by x."
  (let* ((sorted (gtable-sort-by data :x))
         (y (gtable-column sorted :y))
         (n (length y)))
    (gtable-set-column
     (gtable-set-column sorted :ymin (make-array n :initial-element 0.0d0))
     :ymax (map 'simple-vector (lambda (v) (float v 1.0d0)) y))))

(defmethod geom-setup-data ((geom geom-ribbon-obj) data &key)
  (gtable-sort-by data :x))

(defmethod geom-draw-panel ((geom geom-ribbon-obj) data panel axes)
  (declare (ignore panel))
  (loop for (nil . sub) in (gtable-split data :group) do
    (let ((x (gtable-column sub :x))
          (ymin (gtable-column sub :ymin))
          (ymax (gtable-column sub :ymax))
          (fill (%column-value sub :fill nil))
          (color (%column-value sub :color nil))
          (alpha (%column-value sub :alpha 1.0d0)))
      (when (and x ymin ymax (> (length x) 1))
        (when fill
          (cl-matplotlib.containers:fill-between
           axes (coerce x 'list) (coerce ymin 'list) (coerce ymax 'list)
           :color fill :alpha alpha :zorder 2))
        ;; outline along the upper edge (plotnine outline_type="upper")
        (when color
          (cl-matplotlib.containers:plot
           axes (coerce x 'list) (coerce ymax 'list)
           :color color
           :linewidth (size-to-linewidth (%column-value sub :size 0.5d0))
           :zorder 2))))))

(defmethod geom-legend-artist ((geom geom-ribbon-obj) key-plist)
  (make-instance 'cl-matplotlib.rendering:rectangle
                 :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0
                 :facecolor (getf key-plist :value "#333333")
                 :edgecolor nil :linewidth 0.0d0))

(defun geom-area (&rest args &key mapping data stat (position :stack)
                                  show-legend inherit-aes fill color alpha
                                  &allow-other-keys)
  "Area chart: filled region between the x axis and y, stacked by default."
  (declare (ignore mapping data stat show-legend inherit-aes fill color alpha))
  (%make-geom-layer 'geom-area-obj args :position position))

(defun geom-ribbon (&rest args &key mapping data stat position show-legend
                                    inherit-aes fill color alpha
                                    &allow-other-keys)
  "Filled band between ymin and ymax (both must be mapped)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color alpha))
  (%make-geom-layer 'geom-ribbon-obj args))

(defun geom-density (&rest args &key mapping data stat position show-legend
                                     inherit-aes fill color alpha bw adjust
                                     &allow-other-keys)
  "Kernel density estimate drawn as a line (fill it via :fill)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color alpha))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:bw :adjust))
                       append (list k v))))
    (%make-geom-layer 'geom-density-obj
                      (list* :stat (make-instance
                                    'stat-density-obj
                                    :bw (or bw :nrd0)
                                    :adjust (or adjust 1.0d0))
                             clean))))

;;; ============================================================
;;; geom-boxplot
;;; ============================================================

(defclass geom-boxplot-obj (geom) ())

(defmethod geom-default-aes ((geom geom-boxplot-obj))
  '(:color "#333333" :fill "white" :size 0.5d0 :alpha 1.0d0 :width 0.75d0))

(defmethod geom-setup-data ((geom geom-boxplot-obj) data &key)
  "Box x extent from the group position and width."
  (let* ((x (gtable-column data :x))
         (width (gtable-column data :width))
         (n (length x))
         (xmin (make-array n)) (xmax (make-array n)))
    (dotimes (i n)
      (let ((w (if width (float (svref width i) 1.0d0) 0.75d0))
            (xc (float (svref x i) 1.0d0)))
        (setf (aref xmin i) (- xc (/ w 2.0d0))
              (aref xmax i) (+ xc (/ w 2.0d0)))))
    (gtable-set-column (gtable-set-column data :xmin xmin) :xmax xmax)))

(defmethod geom-draw-panel ((geom geom-boxplot-obj) data panel axes)
  (declare (ignore panel))
  (dotimes (i (gtable-nrows data))
    (flet ((col (name) (let ((c (gtable-column data name)))
                         (and c (svref c i)))))
      (let* ((x (float (col :x) 1.0d0))
             (xmin (float (col :xmin) 1.0d0))
             (xmax (float (col :xmax) 1.0d0))
             (lower (float (col :lower) 1.0d0))
             (upper (float (col :upper) 1.0d0))
             (middle (float (col :middle) 1.0d0))
             (ymin (float (col :ymin) 1.0d0))
             (ymax (float (col :ymax) 1.0d0))
             (color (or (col :color) "#333333"))
             (fill (or (col :fill) "white"))
             (lw (size-to-linewidth (or (col :size) 0.5d0))))
        ;; whiskers first (under the box)
        (dolist (pair (list (list upper ymax) (list ymin lower)))
          (cl-matplotlib.containers:plot
           axes (list x x) pair :color color :linewidth lw :zorder 2))
        ;; box
        (let ((rect (make-instance 'cl-matplotlib.rendering:rectangle
                                   :x0 xmin :y0 lower
                                   :width (- xmax xmin)
                                   :height (- upper lower)
                                   :facecolor fill
                                   :edgecolor color
                                   :linewidth lw
                                   :zorder 3)))
          (cl-matplotlib.containers:axes-add-patch axes rect))
        ;; median
        (cl-matplotlib.containers:plot
         axes (list xmin xmax) (list middle middle)
         :color color :linewidth (* lw 2.0d0) :zorder 4)
        ;; outliers
        (let ((outliers (col :outliers)))
          (when outliers
            (cl-matplotlib.containers:scatter
             axes (make-list (length outliers) :initial-element x)
             outliers
             :c color
             :s (size-to-scatter-s 1.5d0 0.5d0)
             :zorder 4)))))))

(defmethod geom-legend-artist ((geom geom-boxplot-obj) key-plist)
  (make-instance 'cl-matplotlib.rendering:rectangle
                 :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0
                 :facecolor (getf key-plist :value "white")
                 :edgecolor "#333333" :linewidth 1.0d0))

(defun geom-boxplot (&rest args &key mapping data stat position show-legend
                                     inherit-aes fill color width alpha
                                     &allow-other-keys)
  "Box-and-whisker summary per x group (stat-boxplot)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color width alpha))
  (%make-geom-layer 'geom-boxplot-obj args :stat :boxplot :position :dodge))

;;; ============================================================
;;; geom-violin
;;; ============================================================

(defclass geom-violin-obj (geom) ())

(defmethod geom-default-aes ((geom geom-violin-obj))
  '(:color "#333333" :fill "white" :size 0.5d0 :alpha 1.0d0 :width 0.9d0))

(defmethod geom-draw-panel ((geom geom-violin-obj) data panel axes)
  (declare (ignore panel))
  (loop for (nil . sub) in (gtable-split data :group) do
    (let* ((x (%column-value sub :x 0.0d0))
           (y (gtable-column sub :y))
           (vw (gtable-column sub :violinwidth))
           (width (%column-value sub :width 0.9d0))
           (color (%column-value sub :color "#333333"))
           (fill (%column-value sub :fill "white"))
           (lw (size-to-linewidth (%column-value sub :size 0.5d0)))
           (n (and y (length y))))
      (when (and y vw (> n 1))
        ;; closed polygon: up the right side, back down the left
        (let ((verts (make-array (list (* 2 n) 2) :element-type 'double-float)))
          (dotimes (i n)
            (let ((half (* (float (svref vw i) 1.0d0) (/ (float width 1.0d0) 2.0d0)))
                  (yi (float (svref y i) 1.0d0)))
              (setf (aref verts i 0) (+ (float x 1.0d0) half)
                    (aref verts i 1) yi
                    (aref verts (- (* 2 n) 1 i) 0) (- (float x 1.0d0) half)
                    (aref verts (- (* 2 n) 1 i) 1) yi)))
          (let ((poly (make-instance 'cl-matplotlib.rendering:polygon
                                     :xy verts
                                     :closed t
                                     :facecolor fill
                                     :edgecolor color
                                     :linewidth lw
                                     :zorder 2)))
            (cl-matplotlib.containers:axes-add-patch axes poly)))))))

(defun geom-violin (&rest args &key mapping data stat position show-legend
                                    inherit-aes fill color width alpha
                                    &allow-other-keys)
  "Mirrored density (violin) per x group (stat-ydensity)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color width alpha))
  (%make-geom-layer 'geom-violin-obj args :stat :ydensity))
