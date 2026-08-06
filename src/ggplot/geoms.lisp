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

(defgeneric geom-key-glyph (geom)
  (:documentation "How this geom's legend key is drawn inside the gray key
box: :point (marker at the center), :line (horizontal line across the key),
or :rect (fill the whole key), matching plotnine's draw_key functions.")
  (:method ((geom geom)) :rect))

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

(defmethod geom-key-glyph ((geom geom-point-obj)) :point)

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

(defun geom-jitter (&rest args &key mapping data stat (position :jitter)
                                    show-legend inherit-aes &allow-other-keys)
  "geom-point with position-jitter (plotnine's geom_jitter)."
  (declare (ignore mapping data stat show-legend inherit-aes))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (eq k :position) append (list k v))))
    (apply #'geom-point :position position clean)))

;;; ============================================================
;;; geom-line / geom-path
;;; ============================================================

(defclass geom-path-obj (geom) ())
(defclass geom-line-obj (geom-path-obj) ())

(defmethod geom-key-glyph ((geom geom-path-obj)) :line)

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

(defun make-geom-layer (geom-class args &key (stat :identity) (position :identity))
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
  (make-geom-layer 'geom-area-obj args :position position))

(defun geom-ribbon (&rest args &key mapping data stat position show-legend
                                    inherit-aes fill color alpha
                                    &allow-other-keys)
  "Filled band between ymin and ymax (both must be mapped)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color alpha))
  (make-geom-layer 'geom-ribbon-obj args))

(defun geom-density (&rest args &key mapping data stat position show-legend
                                     inherit-aes fill color alpha bw adjust
                                     &allow-other-keys)
  "Kernel density estimate drawn as a line (fill it via :fill)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color alpha))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:bw :adjust))
                       append (list k v))))
    (make-geom-layer 'geom-density-obj
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
  (make-geom-layer 'geom-boxplot-obj args :stat :boxplot :position :dodge))

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
  (make-geom-layer 'geom-violin-obj args :stat :ydensity))

;;; ============================================================
;;; geom-smooth
;;; ============================================================

(defclass geom-smooth-obj (geom-ribbon-obj) ())

(defmethod geom-default-aes ((geom geom-smooth-obj))
  '(:color "#3366FF" :fill "#999999" :size 1.0d0 :alpha 0.4d0 :linetype :solid))

(defmethod geom-draw-panel ((geom geom-smooth-obj) data panel axes)
  (declare (ignore panel))
  (loop for (nil . sub) in (gtable-split data :group) do
    (let ((x (gtable-column sub :x))
          (y (gtable-column sub :y))
          (ymin (gtable-column sub :ymin))
          (ymax (gtable-column sub :ymax)))
      (when (and x y (> (length x) 1))
        (when (and ymin ymax)
          (cl-matplotlib.containers:fill-between
           axes (coerce x 'list) (coerce ymin 'list) (coerce ymax 'list)
           :color (%column-value sub :fill "#999999")
           :alpha (%column-value sub :alpha 0.4d0)
           :zorder 2))
        (cl-matplotlib.containers:plot
         axes (coerce x 'list) (coerce y 'list)
         :color (%column-value sub :color "#3366FF")
         :linewidth (size-to-linewidth (%column-value sub :size 1.0d0))
         :zorder 3)))))

(defun geom-smooth (&rest args &key mapping data stat position show-legend
                                    inherit-aes method se level span n
                                    color fill alpha &allow-other-keys)
  "Smoothed conditional mean with confidence ribbon.
:method :lm (default) or :loess."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   color fill alpha))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:method :se :level :span :n))
                       append (list k v))))
    (make-geom-layer 'geom-smooth-obj
                      (list* :stat (make-instance
                                    'stat-smooth-obj
                                    :method (or method :lm)
                                    :se (if (member :se args) se t)
                                    :level (or level 0.95d0)
                                    :span (or span 0.75d0)
                                    :n (or n 80))
                             clean))))

;;; ============================================================
;;; geom-tile / geom-raster
;;; ============================================================

(defclass geom-tile-obj (geom) ())

(defmethod geom-default-aes ((geom geom-tile-obj))
  '(:fill "#333333" :color nil :size 0.1d0 :alpha 1.0d0))

(defun %column-resolution (col)
  "Smallest gap between distinct sorted numeric values, or 1.0."
  (let ((vals (sort (remove-duplicates (coerce col 'list) :test #'=) #'<)))
    (if (< (length vals) 2)
        1.0d0
        (loop for (a b) on vals while b minimize (- b a)))))

(defmethod geom-setup-data ((geom geom-tile-obj) data &key)
  "Tiles centered on (x, y) sized by :width/:height columns or the data
resolution."
  (let* ((x (gtable-column data :x))
         (y (gtable-column data :y))
         (n (length x))
         (width-col (gtable-column data :width))
         (height-col (gtable-column data :height))
         (w-default (%column-resolution x))
         (h-default (%column-resolution y))
         (xmin (make-array n)) (xmax (make-array n))
         (ymin (make-array n)) (ymax (make-array n)))
    (dotimes (i n)
      (let ((w (if width-col (float (svref width-col i) 1.0d0) w-default))
            (h (if height-col (float (svref height-col i) 1.0d0) h-default))
            (xc (float (svref x i) 1.0d0))
            (yc (float (svref y i) 1.0d0)))
        (setf (aref xmin i) (- xc (/ w 2.0d0))
              (aref xmax i) (+ xc (/ w 2.0d0))
              (aref ymin i) (- yc (/ h 2.0d0))
              (aref ymax i) (+ yc (/ h 2.0d0)))))
    (gtable-set-column
     (gtable-set-column
      (gtable-set-column
       (gtable-set-column data :xmin xmin) :xmax xmax)
      :ymin ymin)
     :ymax ymax)))

(defmethod geom-draw-panel ((geom geom-tile-obj) data panel axes)
  (declare (ignore panel))
  (let ((xmin (gtable-column data :xmin))
        (xmax (gtable-column data :xmax))
        (ymin (gtable-column data :ymin))
        (ymax (gtable-column data :ymax))
        (fill (gtable-column data :fill))
        (alpha (gtable-column data :alpha)))
    (dotimes (i (length xmin))
      (let ((rect (make-instance 'cl-matplotlib.rendering:rectangle
                                 :x0 (float (svref xmin i) 1.0d0)
                                 :y0 (float (svref ymin i) 1.0d0)
                                 :width (float (- (svref xmax i) (svref xmin i)) 1.0d0)
                                 :height (float (- (svref ymax i) (svref ymin i)) 1.0d0)
                                 :facecolor (if fill (svref fill i) "#333333")
                                 :edgecolor nil
                                 :linewidth 0.0d0
                                 :zorder 2)))
        (when alpha
          (setf (cl-matplotlib.rendering:artist-alpha rect)
                (float (svref alpha i) 1.0d0)))
        (cl-matplotlib.containers:axes-add-patch axes rect)))))

(defun geom-tile (&rest args &key mapping data stat position show-legend
                                  inherit-aes fill alpha width height
                                  &allow-other-keys)
  "Rectangular tiles centered on (x, y) — heatmaps."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill alpha width height))
  (make-geom-layer 'geom-tile-obj args))

(defun geom-raster (&rest args)
  "Alias for geom-tile (the backend draws tiles as rectangles either way)."
  (apply #'geom-tile args))

;;; ============================================================
;;; geom-text / geom-label
;;; ============================================================

(defclass geom-text-obj (geom) ())

(defmethod geom-default-aes ((geom geom-text-obj))
  '(:color "black" :size 8.8d0 :alpha 1.0d0))

(defmethod geom-draw-panel ((geom geom-text-obj) data panel axes)
  (declare (ignore panel))
  (let ((x (gtable-column data :x))
        (y (gtable-column data :y))
        (label (gtable-column data :label))
        (color (gtable-column data :color))
        (size (gtable-column data :size)))
    (unless label
      (error "geom-text requires a label aesthetic"))
    (dotimes (i (length x))
      (let ((artist (make-instance 'cl-matplotlib.rendering:text-artist
                                   :x (float (svref x i) 1.0d0)
                                   :y (float (svref y i) 1.0d0)
                                   ;; print doubles without the d0 suffix
                                   :text (let ((*read-default-float-format*
                                                 'double-float))
                                           (princ-to-string (svref label i)))
                                   :fontsize (float (if size (svref size i) 8.8d0) 1.0d0)
                                   :color (if color (svref color i) "black")
                                   :horizontalalignment :center
                                   :verticalalignment :center
                                   :zorder 3)))
        (setf (cl-matplotlib.rendering:artist-transform artist)
              (cl-matplotlib.containers:axes-base-trans-data axes))
        (push artist (cl-matplotlib.containers:axes-base-texts axes))))))

(defun geom-text (&rest args &key mapping data stat position show-legend
                                  inherit-aes color size nudge-x nudge-y
                                  &allow-other-keys)
  "Text at (x, y) from the label aesthetic. :nudge-x/:nudge-y offset the
text in data units (shorthand for :position (position-nudge ...))."
  (declare (ignore mapping data stat show-legend inherit-aes color size))
  (let ((args (loop for (k v) on args by #'cddr
                    unless (member k '(:nudge-x :nudge-y))
                      append (list k v))))
    (when (and (or nudge-x nudge-y) (null position))
      (setf args (list* :position (position-nudge :x (or nudge-x 0.0d0)
                                                  :y (or nudge-y 0.0d0))
                        args)))
    (make-geom-layer 'geom-text-obj args)))

(defun geom-label (&rest args)
  "Alias for geom-text (background boxes arrive with a later slice)."
  (apply #'geom-text args))

;;; ============================================================
;;; geom-segment and reference lines
;;; ============================================================

(defclass geom-segment-obj (geom) ())
(defmethod geom-key-glyph ((geom geom-segment-obj)) :line)

(defmethod geom-default-aes ((geom geom-segment-obj))
  '(:color "black" :size 0.5d0 :alpha 1.0d0 :linetype :solid))

(defmethod geom-draw-panel ((geom geom-segment-obj) data panel axes)
  (declare (ignore panel))
  (let* ((x (gtable-column data :x))
         (xend (gtable-column data :xend))
         (y (gtable-column data :y))
         (yend (gtable-column data :yend))
         (segments (loop for i from 0 below (length x)
                         collect (list (list (float (svref x i) 1.0d0)
                                             (float (svref y i) 1.0d0))
                                       (list (float (svref xend i) 1.0d0)
                                             (float (svref yend i) 1.0d0))))))
    (when segments
      (let ((lc (make-instance 'cl-matplotlib.rendering:line-collection
                               :segments segments
                               :edgecolors (coerce (or (gtable-column data :color)
                                                       #("black"))
                                                   'list)
                               :linewidths (list (size-to-linewidth
                                                  (%column-value data :size 0.5d0)))
                               :zorder 2)))
        (setf (cl-matplotlib.rendering:artist-transform lc)
              (cl-matplotlib.containers:axes-base-trans-data axes))
        (cl-matplotlib.containers:axes-add-artist axes lc)))))

(defun geom-segment (&rest args &key mapping data stat position show-legend
                                     inherit-aes color size &allow-other-keys)
  "Line segments from (x, y) to (xend, yend)."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   color size))
  (make-geom-layer 'geom-segment-obj args))

(defclass geom-hline-obj (geom) ())
(defclass geom-vline-obj (geom) ())

(defmethod geom-default-aes ((geom geom-hline-obj))
  '(:color "black" :size 0.5d0 :alpha 1.0d0 :linetype :solid))
(defmethod geom-default-aes ((geom geom-vline-obj))
  '(:color "black" :size 0.5d0 :alpha 1.0d0 :linetype :solid))

(defmethod geom-draw-panel ((geom geom-hline-obj) data panel axes)
  (declare (ignore panel))
  (let ((y (gtable-column data :yintercept)))
    (dotimes (i (length y))
      (cl-matplotlib.containers:axhline
       axes (float (svref y i) 1.0d0)
       :color (%column-value data :color "black")
       :linewidth (size-to-linewidth (%column-value data :size 0.5d0))
       :linestyle (%column-value data :linetype :solid)
       :zorder 3))))

(defmethod geom-draw-panel ((geom geom-vline-obj) data panel axes)
  (declare (ignore panel))
  (let ((x (gtable-column data :xintercept)))
    (dotimes (i (length x))
      (cl-matplotlib.containers:axvline
       axes (float (svref x i) 1.0d0)
       :color (%column-value data :color "black")
       :linewidth (size-to-linewidth (%column-value data :size 0.5d0))
       :linestyle (%column-value data :linetype :solid)
       :zorder 3))))

(defun geom-hline (&key yintercept color size linetype)
  "Horizontal reference line(s)."
  (let ((ys (if (listp yintercept) yintercept (list yintercept))))
    (make-layer :geom (make-instance 'geom-hline-obj)
                :data (list :yintercept (coerce ys 'vector))
                :mapping (aes :yintercept :yintercept)
                :inherit-aes nil
                :show-legend nil
                :params (append (when color (list :color color))
                                (when size (list :size size))
                                (when linetype (list :linetype linetype))))))

(defclass geom-abline-obj (geom) ())

(defmethod geom-default-aes ((geom geom-abline-obj))
  '(:color "black" :size 0.5d0 :alpha 1.0d0 :linetype :solid))

(defmethod geom-draw-panel ((geom geom-abline-obj) data panel axes)
  (let ((slope (gtable-column data :slope))
        (intercept (gtable-column data :intercept))
        (x-range (getf panel :x-range)))
    (dotimes (i (length slope))
      (let* ((m (float (svref slope i) 1.0d0))
             (b (float (svref intercept i) 1.0d0))
             (x0 (first x-range))
             (x1 (second x-range)))
        (cl-matplotlib.containers:plot
         axes (list x0 x1) (list (+ (* m x0) b) (+ (* m x1) b))
         :color (%column-value data :color "black")
         :linewidth (size-to-linewidth (%column-value data :size 0.5d0))
         :linestyle (%column-value data :linetype :solid)
         :zorder 3)))))

(defun geom-abline (&key (slope 1.0d0) (intercept 0.0d0) color size linetype)
  "Line(s) with SLOPE and INTERCEPT spanning the panel."
  (let ((ms (if (listp slope) slope (list slope)))
        (bs (if (listp intercept) intercept (list intercept))))
    (let ((n (max (length ms) (length bs))))
      (make-layer :geom (make-instance 'geom-abline-obj)
                  :data (list :slope (coerce (loop for i from 0 below n
                                                   collect (elt ms (min i (1- (length ms)))))
                                             'vector)
                              :intercept (coerce (loop for i from 0 below n
                                                       collect (elt bs (min i (1- (length bs)))))
                                                 'vector))
                  :mapping (aes :slope :slope :intercept :intercept)
                  :inherit-aes nil
                  :show-legend nil
                  :params (append (when color (list :color color))
                                  (when size (list :size size))
                                  (when linetype (list :linetype linetype)))))))

(defun geom-vline (&key xintercept color size linetype)
  "Vertical reference line(s)."
  (let ((xs (if (listp xintercept) xintercept (list xintercept))))
    (make-layer :geom (make-instance 'geom-vline-obj)
                :data (list :xintercept (coerce xs 'vector))
                :mapping (aes :xintercept :xintercept)
                :inherit-aes nil
                :show-legend nil
                :params (append (when color (list :color color))
                                (when size (list :size size))
                                (when linetype (list :linetype linetype))))))

(defclass geom-rect-obj (geom-bar-obj) ())

(defmethod geom-setup-data ((geom geom-rect-obj) data &key)
  ;; xmin/xmax/ymin/ymax come straight from the mapping
  data)

(defun geom-rect (&rest args &key mapping data stat position show-legend
                                  inherit-aes fill color alpha
                                  &allow-other-keys)
  "Rectangles from mapped xmin/xmax/ymin/ymax."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   fill color alpha))
  (make-geom-layer 'geom-rect-obj args))

;;; ============================================================
;;; annotate
;;; ============================================================

(defun annotate (geom &rest args &key x y xend yend label &allow-other-keys)
  "One-off annotation layer: (annotate :text :x 3 :y 5 :label \"peak\").
GEOM is a keyword naming the geom (:text, :segment, :rect, :point, ...)."
  (declare (ignore xend yend label))
  (let* ((fields (loop for (k v) on args by #'cddr
                       when (member k '(:x :y :xend :yend :label
                                        :xmin :xmax :ymin :ymax))
                         append (list k v)))
         (params (loop for (k v) on args by #'cddr
                       unless (member k '(:x :y :xend :yend :label
                                          :xmin :xmax :ymin :ymax))
                         append (list k v)))
         (n (max 1 (loop for (k v) on fields by #'cddr
                         maximize (if (listp v) (length v) 1))))
         (data (loop for (k v) on fields by #'cddr
                     append (list k (coerce (if (listp v)
                                                v
                                                (make-list n :initial-element v))
                                            'vector))))
         (mapping (apply #'aes (loop for (k nil) on fields by #'cddr
                                     append (list k k))))
         (constructor (ecase geom
                        (:text #'geom-text)
                        (:label #'geom-label)
                        (:segment #'geom-segment)
                        (:rect #'geom-rect)
                        (:point #'geom-point))))
    (declare (ignore x y))
    (apply constructor :data data :mapping mapping :inherit-aes nil
           :show-legend nil params)))

;;; ============================================================
;;; geom-step / geom-rug / range geoms / ecdf / qq
;;; ============================================================

(defclass geom-step-obj (geom-path-obj) ())

(defmethod geom-setup-data ((geom geom-step-obj) data &key)
  (gtable-sort-by data :x))

(defmethod geom-draw-panel ((geom geom-step-obj) data panel axes)
  (let* ((x (gtable-column data :x))
         (y (gtable-column data :y))
         (x-range (getf panel :x-range)))
    (when (and x y (> (length x) 1))
      ;; stat-ecdf pads with +/-Inf so the step runs to the panel edges;
      ;; clamp the infinities to the expanded x range
      (let ((xs (loop for v across x
                      collect (let ((v (float v 1.0d0)))
                                (if (float-features:float-infinity-p v)
                                    (if (plusp v)
                                        (second x-range)
                                        (first x-range))
                                    v)))))
        (cl-matplotlib.containers:axes-step
         axes xs (coerce y 'list)
         :color (%column-value data :color "black")
         :linewidth (size-to-linewidth (%column-value data :size 0.5d0))
         :zorder 2)))))

(defun geom-step (&rest args &key mapping data stat position show-legend
                                  inherit-aes color size &allow-other-keys)
  "Step function: horizontal then vertical segments between points."
  (declare (ignore mapping data stat position show-legend inherit-aes color size))
  (make-geom-layer 'geom-step-obj args))

(defclass geom-rug-obj (geom) ())

(defmethod geom-default-aes ((geom geom-rug-obj))
  '(:color "black" :size 0.5d0 :alpha 1.0d0))

(defmethod geom-draw-panel ((geom geom-rug-obj) data panel axes)
  (let* ((x (gtable-column data :x))
         (y-range (getf panel :y-range))
         (rug-h (* 0.03d0 (- (second y-range) (first y-range))))
         (y0 (first y-range))
         (segments (when x
                     (loop for i from 0 below (length x)
                           collect (list (list (float (svref x i) 1.0d0) y0)
                                         (list (float (svref x i) 1.0d0)
                                               (+ y0 rug-h)))))))
    (when segments
      (let ((lc (make-instance 'cl-matplotlib.rendering:line-collection
                               :segments segments
                               :edgecolors (list (%column-value data :color "black"))
                               :linewidths (list (size-to-linewidth
                                                  (%column-value data :size 0.5d0)))
                               :zorder 3)))
        (setf (cl-matplotlib.rendering:artist-transform lc)
              (cl-matplotlib.containers:axes-base-trans-data axes))
        (cl-matplotlib.containers:axes-add-artist axes lc)))))

(defun geom-rug (&rest args &key mapping data stat position show-legend
                                 inherit-aes color size &allow-other-keys)
  "Marginal tick marks along the x axis."
  (declare (ignore mapping data stat position show-legend inherit-aes color size))
  (make-geom-layer 'geom-rug-obj args))

(defclass geom-linerange-obj (geom) ())
(defmethod geom-key-glyph ((geom geom-linerange-obj)) :line)
(defclass geom-errorbar-obj (geom-linerange-obj) ())
(defclass geom-pointrange-obj (geom-linerange-obj) ())
(defmethod geom-key-glyph ((geom geom-pointrange-obj)) :point)

(defmethod geom-default-aes ((geom geom-linerange-obj))
  '(:color "black" :size 0.5d0 :alpha 1.0d0))

(defmethod geom-draw-panel ((geom geom-linerange-obj) data panel axes)
  (declare (ignore panel))
  (let ((x (gtable-column data :x))
        (ymin (gtable-column data :ymin))
        (ymax (gtable-column data :ymax))
        (color (%column-value data :color "black"))
        (lw (size-to-linewidth (%column-value data :size 0.5d0))))
    (unless (and x ymin ymax)
      (error "linerange-family geoms require x, ymin, ymax aesthetics"))
    (dotimes (i (length x))
      (let ((xi (float (svref x i) 1.0d0)))
        (cl-matplotlib.containers:plot
         axes (list xi xi)
         (list (float (svref ymin i) 1.0d0) (float (svref ymax i) 1.0d0))
         :color color :linewidth lw :zorder 2)
        ;; errorbar caps
        (when (typep geom 'geom-errorbar-obj)
          (let ((cap 0.05d0))
            (dolist (yv (list (svref ymin i) (svref ymax i)))
              (cl-matplotlib.containers:plot
               axes (list (- xi cap) (+ xi cap))
               (list (float yv 1.0d0) (float yv 1.0d0))
               :color color :linewidth lw :zorder 2))))
        ;; pointrange midpoint
        (when (typep geom 'geom-pointrange-obj)
          (let ((y-col (gtable-column data :y)))
            (when y-col
              (cl-matplotlib.containers:scatter
               axes (list xi) (list (float (svref y-col i) 1.0d0))
               :c color :s (size-to-scatter-s 1.5d0 0.5d0) :zorder 3))))))))

(defun geom-linerange (&rest args &key mapping data stat position show-legend
                                       inherit-aes color size &allow-other-keys)
  "Vertical line from ymin to ymax at each x."
  (declare (ignore mapping data stat position show-legend inherit-aes color size))
  (make-geom-layer 'geom-linerange-obj args))

(defun geom-errorbar (&rest args &key mapping data stat position show-legend
                                      inherit-aes color size &allow-other-keys)
  "Linerange with caps."
  (declare (ignore mapping data stat position show-legend inherit-aes color size))
  (make-geom-layer 'geom-errorbar-obj args))

(defun geom-pointrange (&rest args &key mapping data stat position show-legend
                                        inherit-aes color size &allow-other-keys)
  "Linerange with a point at y."
  (declare (ignore mapping data stat position show-legend inherit-aes color size))
  (make-geom-layer 'geom-pointrange-obj args))

(defun geom-qq (&rest args &key mapping data position show-legend
                                inherit-aes color size &allow-other-keys)
  "Normal quantile-quantile points (stat-qq over the sample aesthetic)."
  (declare (ignore mapping data position show-legend inherit-aes color size))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (eq k :stat) append (list k v))))
    (destructuring-bind (&key mapping data (show-legend :auto) (inherit-aes t)
                              &allow-other-keys)
        clean
      (let ((params (loop for (k v) on clean by #'cddr
                          unless (member k '(:mapping :data :show-legend
                                             :inherit-aes))
                            append (list k v))))
        (make-layer :geom (make-instance 'geom-point-obj)
                    :stat :qq :position :identity
                    :mapping mapping :data data :params params
                    :show-legend show-legend :inherit-aes inherit-aes)))))

;;; ============================================================
;;; geom-crossbar: box from ymin..ymax with a line at y
;;; ============================================================

(defclass geom-crossbar-obj (geom) ())

(defmethod geom-default-aes ((geom geom-crossbar-obj))
  '(:color "black" :fill nil :size 0.5d0 :alpha 1.0d0 :width 0.9d0))

(defmethod geom-setup-data ((geom geom-crossbar-obj) data &key)
  (let* ((x (gtable-column data :x))
         (width (gtable-column data :width))
         (n (length x))
         (xmin (make-array n)) (xmax (make-array n)))
    (dotimes (i n)
      (let ((w (if width (float (svref width i) 1.0d0) 0.9d0))
            (xc (float (svref x i) 1.0d0)))
        (setf (aref xmin i) (- xc (/ w 2.0d0))
              (aref xmax i) (+ xc (/ w 2.0d0)))))
    (gtable-set-column (gtable-set-column data :xmin xmin) :xmax xmax)))

(defmethod geom-draw-panel ((geom geom-crossbar-obj) data panel axes)
  (declare (ignore panel))
  (dotimes (i (gtable-nrows data))
    (flet ((col (name) (let ((c (gtable-column data name)))
                         (and c (svref c i)))))
      (let ((xmin (float (col :xmin) 1.0d0))
            (xmax (float (col :xmax) 1.0d0))
            (ymin (float (col :ymin) 1.0d0))
            (ymax (float (col :ymax) 1.0d0))
            (y (float (col :y) 1.0d0))
            (color (or (col :color) "black"))
            (fill (col :fill))
            (lw (size-to-linewidth (or (col :size) 0.5d0))))
        (let ((rect (make-instance 'cl-matplotlib.rendering:rectangle
                                   :x0 xmin :y0 ymin
                                   :width (- xmax xmin)
                                   :height (- ymax ymin)
                                   :facecolor (or fill "none")
                                   :edgecolor color
                                   :linewidth lw
                                   :zorder 2)))
          (cl-matplotlib.containers:axes-add-patch axes rect))
        (cl-matplotlib.containers:plot
         axes (list xmin xmax) (list y y)
         :color color :linewidth (* lw 2.0d0) :zorder 3)))))

(defun geom-crossbar (&rest args &key mapping data stat position show-legend
                                      inherit-aes width color fill
                                      &allow-other-keys)
  "Hollow bar from ymin to ymax with a doubled line at y."
  (declare (ignore mapping data stat position show-legend inherit-aes
                   width color fill))
  (make-geom-layer 'geom-crossbar-obj args))

;;; ============================================================
;;; geom-bin2d: heatmap of 2D bin counts (stat-bin2d)
;;; ============================================================

(defclass geom-bin2d-obj (geom) ())

(defmethod geom-default-aes ((geom geom-bin2d-obj))
  (list :fill (after-stat :count) :alpha 1.0d0))

(defmethod geom-draw-panel ((geom geom-bin2d-obj) data panel axes)
  (declare (ignore panel))
  (dotimes (i (gtable-nrows data))
    (flet ((col (name) (let ((c (gtable-column data name)))
                         (and c (svref c i)))))
      (let ((rect (make-instance 'cl-matplotlib.rendering:rectangle
                                 :x0 (float (col :xmin) 1.0d0)
                                 :y0 (float (col :ymin) 1.0d0)
                                 :width (- (float (col :xmax) 1.0d0)
                                           (float (col :xmin) 1.0d0))
                                 :height (- (float (col :ymax) 1.0d0)
                                            (float (col :ymin) 1.0d0))
                                 :facecolor (or (col :fill) "#132B43")
                                 :edgecolor nil
                                 :linewidth 0.0d0
                                 :zorder 2)))
        (cl-matplotlib.containers:axes-add-patch axes rect)))))

(defun geom-bin2d (&rest args &key mapping data stat position
                                   show-legend inherit-aes (bins 30)
                                   &allow-other-keys)
  "2D histogram: rectangular bins filled by count."
  (declare (ignore mapping data position show-legend inherit-aes))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:bins :stat)) append (list k v))))
    (make-geom-layer 'geom-bin2d-obj clean
                     :stat (or stat
                               (make-instance 'stat-bin2d-obj :bins bins)))))

(defun geom-bin-2d (&rest args)
  "plotnine-style alias for geom-bin2d."
  (apply #'geom-bin2d args))

;;; ============================================================
;;; geom-count: points sized by overlap count (stat-sum)
;;; ============================================================

(defclass geom-count-obj (geom-point-obj) ())

(defun geom-count (&rest args &key mapping data (stat :sum) position
                                   show-legend inherit-aes
                                   &allow-other-keys)
  "Points sized by the number of observations at each location."
  (declare (ignore mapping data position show-legend inherit-aes))
  (make-geom-layer 'geom-count-obj args :stat stat))
