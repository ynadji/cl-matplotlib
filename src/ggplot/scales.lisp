;;;; scales.lisp — scale protocol and continuous positional scales
;;;;
;;;; PR0 scope: continuous x/y scales with plotnine-parity expansion and
;;;; extended-Wilkinson breaks. Discrete and non-positional scales follow.

(in-package #:ggplot)

;;; ============================================================
;;; Scale protocol
;;; ============================================================

(defgeneric scale-train (scale values)
  (:documentation "Accumulate range (continuous) or levels (discrete) from VALUES."))

(defgeneric scale-transform (scale values)
  (:documentation "Apply the scale's forward transformation to VALUES.")
  (:method ((scale scale) values) values))

(defgeneric scale-map (scale values)
  (:documentation "Map data values to aesthetic values.")
  (:method ((scale scale) values) values))

(defgeneric scale-limits (scale)
  (:documentation "Effective (min max) limits: user limits or trained range."))

(defgeneric scale-breaks (scale)
  (:documentation "List of break (tick) positions within the limits."))

(defgeneric scale-break-labels (scale breaks)
  (:documentation "List of label strings for BREAKS."))

(defgeneric scale-expanded-range (scale)
  (:documentation "(min max) limits after applying the scale's expansion."))

(defgeneric scale-minor-breaks (scale breaks range)
  (:documentation "Positions of minor gridlines given the major BREAKS
and the expanded RANGE. plotnine default: midpoints between majors;
log scales place them at 2..9 x 10^k.")
  (:method ((scale scale) breaks range)
    (declare (ignore range))
    (loop for (a b) on breaks
          while b
          collect (/ (+ a b) 2.0d0))))

;;; ============================================================
;;; Continuous scales
;;; ============================================================

(defclass scale-continuous (scale)
  ((trans :initarg :trans :initform :identity :reader scale-trans)
   (range-min :initform nil :accessor scale-range-min)
   (range-max :initform nil :accessor scale-range-max))
  (:documentation "Continuous scale. Default expansion is plotnine's
(mult 0.05, add 0) on each side."))

(defmethod scale-train ((scale scale-continuous) values)
  (multiple-value-bind (lo hi) (finite-range values)
    (when lo
      (when (or (null (scale-range-min scale)) (< lo (scale-range-min scale)))
        (setf (scale-range-min scale) lo))
      (when (or (null (scale-range-max scale)) (> hi (scale-range-max scale)))
        (setf (scale-range-max scale) hi)))))

(defmethod scale-limits ((scale scale-continuous))
  (let ((user (scale-user-limits scale)))
    (list (or (and user (first user)) (scale-range-min scale) 0.0d0)
          (or (and user (second user)) (scale-range-max scale) 1.0d0))))

(defmethod scale-expanded-range ((scale scale-continuous))
  (destructuring-bind (lo hi) (scale-limits scale)
    (let* ((expand (or (scale-user-expand scale) '(0.05d0 0.0d0)))
           (mult (first expand))
           (add (or (second expand) 0.0d0))
           (range (- hi lo))
           ;; Degenerate range: plotnine expands by 0.5 units either side
           (range (if (zerop range) 1.0d0 range))
           (pad (+ (* mult range) add)))
      (list (- lo pad) (+ hi pad)))))

(defmethod scale-breaks ((scale scale-continuous))
  (let ((user (scale-user-breaks scale)))
    (if (not (eq user :auto))
        user
        (destructuring-bind (lo hi) (scale-expanded-range scale)
          ;; Breaks are computed on the EXPANDED limits (plotnine >= 0.15;
          ;; verified against 0.15.7), then the renderer keeps only those
          ;; inside the panel range.
          (extended-breaks lo hi 5)))))

(defun %decimals-needed (x &optional (max-decimals 10))
  "Smallest number of decimal places that represents X exactly enough."
  (loop for d from 0 to max-decimals
        for scale = (expt 10 d)
        when (< (abs (- x (/ (round (* x scale)) scale))) 1.0d-9)
          do (return d)
        finally (return max-decimals)))

(defun %format-break-set (breaks)
  "Format BREAKS the way mizani does: one shared decimal precision across
the whole set (so 10, 12.5 render as \"10.0\", \"12.5\", but 1, 2, 3 render
without decimal points)."
  (let ((decimals (reduce #'max breaks :key #'%decimals-needed
                                       :initial-value 0)))
    (mapcar (lambda (b)
              (if (zerop decimals)
                  (format nil "~D" (round b))
                  (format nil "~,VF" decimals b)))
            breaks)))

(defmethod scale-break-labels ((scale scale-continuous) breaks)
  (let ((user (scale-user-labels scale)))
    (cond ((not (eq user :auto)) user)
          ((null breaks) '())
          (t (%format-break-set breaks)))))

;;; ============================================================
;;; Constructors
;;; ============================================================

(defun scale-x-continuous (&rest args &key name breaks labels limits expand trans)
  (declare (ignore name breaks labels limits expand trans))
  (apply #'make-instance 'scale-continuous :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-continuous (&rest args &key name breaks labels limits expand trans)
  (declare (ignore name breaks labels limits expand trans))
  (apply #'make-instance 'scale-continuous :aesthetics '(:y :ymin :ymax :yend) args))

(defun xlim (min max)
  "Set x limits (shorthand for scale-x-continuous :limits)."
  (scale-x-continuous :limits (list (and min (float min 1.0d0))
                                    (and max (float max 1.0d0)))))

(defun ylim (min max)
  "Set y limits (shorthand for scale-y-continuous :limits)."
  (scale-y-continuous :limits (list (and min (float min 1.0d0))
                                    (and max (float max 1.0d0)))))

(defun lims (&key x y)
  "Set limits for several aesthetics at once: (lims :x '(0 10) :y '(0 1))."
  (remove nil (list (when x (apply #'xlim x))
                    (when y (apply #'ylim y)))))

;;; ============================================================
;;; Discrete scales
;;; ============================================================

(defclass scale-discrete (scale)
  ((values-seen :initform '() :accessor scale-values-seen)
   (drop :initarg :drop :initform t :reader scale-drop-p))
  (:documentation "Discrete scale: distinct values map to positions 1..n
(positional) or palette entries (non-positional). Default expansion is
plotnine's additive 0.6."))

(defmethod scale-train ((scale scale-discrete) values)
  (map nil (lambda (v)
             (pushnew v (scale-values-seen scale) :test #'equal))
       values))

(defun scale-levels (scale)
  "Sorted distinct values: numbers numerically, everything else by string."
  (let ((user (scale-user-limits scale)))
    (or user
        (let ((vals (scale-values-seen scale)))
          (if (every #'realp vals)
              (sort (copy-list vals) #'<)
              (sort (copy-list vals) #'string<
                    :key (lambda (v) (princ-to-string v))))))))

(defun %level-position (scale value)
  (let ((pos (position value (scale-levels scale) :test #'equal)))
    (unless pos
      (error "Value ~S is not among the scale's levels ~S"
             value (scale-levels scale)))
    (1+ pos)))

(defmethod scale-limits ((scale scale-discrete))
  (let ((n (length (scale-levels scale))))
    (list 1.0d0 (float (max n 1) 1.0d0))))

(defmethod scale-expanded-range ((scale scale-discrete))
  (destructuring-bind (lo hi) (scale-limits scale)
    (let* ((expand (or (scale-user-expand scale) '(0.0d0 0.6d0)))
           (mult (first expand))
           (add (or (second expand) 0.6d0))
           (range (max (- hi lo) 1.0d0))
           (pad (+ (* mult range) add)))
      (list (- lo pad) (+ hi pad)))))

(defmethod scale-map ((scale scale-discrete) values)
  (map 'simple-vector (lambda (v) (float (%level-position scale v) 1.0d0))
       values))

(defmethod scale-breaks ((scale scale-discrete))
  (let ((user (scale-user-breaks scale)))
    (if (not (eq user :auto))
        user
        (loop for i from 1 to (length (scale-levels scale))
              collect (float i 1.0d0)))))

(defmethod scale-break-labels ((scale scale-discrete) breaks)
  (declare (ignore breaks))
  (let ((user (scale-user-labels scale)))
    (if (not (eq user :auto))
        user
        (mapcar #'princ-to-string (scale-levels scale)))))

(defun scale-x-discrete (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-discrete :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-discrete (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-discrete :aesthetics '(:y :ymin :ymax :yend) args))

;;; ============================================================
;;; Non-positional discrete scales (color/fill/shape)
;;; ============================================================

(defclass scale-discrete-palette (scale-discrete)
  ((palette :initarg :palette :reader scale-palette
            :documentation "Function n -> list of n aesthetic values."))
  (:documentation "Discrete scale mapping levels through a palette."))

(defmethod scale-map ((scale scale-discrete-palette) values)
  (let* ((levels (scale-levels scale))
         (mapped (funcall (scale-palette scale) (length levels))))
    (unless (>= (length mapped) (length levels))
      (error "Palette supplied ~D values for ~D levels"
             (length mapped) (length levels)))
    (map 'simple-vector
         (lambda (v) (elt mapped (1- (%level-position scale v))))
         values)))

(defun scale-color-discrete (&rest args &key name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (apply #'make-instance 'scale-discrete-palette
         :aesthetics '(:color) :palette #'hls-palette args))

(defun scale-fill-discrete (&rest args &key name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (apply #'make-instance 'scale-discrete-palette
         :aesthetics '(:fill) :palette #'hls-palette args))

(defun %manual-palette (values)
  (lambda (n)
    (unless (>= (length values) n)
      (error "scale-*-manual: ~D values supplied but ~D levels present"
             (length values) n))
    (coerce values 'list)))

(defun scale-color-manual (&rest args &key values name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (eq k :values) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:color) :palette (%manual-palette values) rest)))

(defun scale-fill-manual (&rest args &key values name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (eq k :values) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:fill) :palette (%manual-palette values) rest)))

(defparameter *default-shapes* '(:o :^ :s :d :v :star :p :x)
  "plotnine's default shape order, as backend marker keywords.")

(defun scale-shape-manual (&rest args &key values name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (eq k :values) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:shape)
           :palette (%manual-palette (or values *default-shapes*)) rest)))

;;; ============================================================
;;; Continuous size / alpha scales
;;; ============================================================

(defclass scale-size-obj (scale-continuous)
  ((range :initarg :range :initform '(1.0d0 6.0d0) :reader scale-size-range))
  (:documentation "Continuous size scale using plotnine's area palette:
sizes proportional to sqrt of the rescaled value."))

(defmethod scale-map ((scale scale-size-obj) values)
  (destructuring-bind (lo hi) (scale-limits scale)
    (destructuring-bind (rmin rmax) (scale-size-range scale)
      (let ((span (max (- hi lo) 1.0d-12)))
        (map 'simple-vector
             (lambda (v)
               (let ((u (/ (- (float v 1.0d0) lo) span)))
                 (sqrt (+ (* u (- (* rmax rmax) (* rmin rmin)))
                          (* rmin rmin)))))
             values)))))

(defun scale-size (&rest args &key range name breaks labels limits guide)
  (declare (ignore range name breaks labels limits guide))
  (apply #'make-instance 'scale-size-obj :aesthetics '(:size) args))

(defclass scale-alpha-obj (scale-continuous)
  ((range :initarg :range :initform '(0.1d0 1.0d0) :reader scale-alpha-range)))

(defmethod scale-map ((scale scale-alpha-obj) values)
  (destructuring-bind (lo hi) (scale-limits scale)
    (destructuring-bind (rmin rmax) (scale-alpha-range scale)
      (let ((span (max (- hi lo) 1.0d-12)))
        (map 'simple-vector
             (lambda (v)
               (+ rmin (* (/ (- (float v 1.0d0) lo) span) (- rmax rmin))))
             values)))))

(defun scale-alpha (&rest args &key range name breaks labels limits guide)
  (declare (ignore range name breaks labels limits guide))
  (apply #'make-instance 'scale-alpha-obj :aesthetics '(:alpha) args))

;;; ============================================================
;;; Default scale inference
;;; ============================================================

(defun find-default-scale (aesthetic sample-values)
  "Create a default scale for AESTHETIC based on SAMPLE-VALUES' types."
  (let ((discrete (some #'discrete-value-p sample-values)))
    (case aesthetic
      ((:x :xmin :xmax :xend)
       (if discrete (scale-x-discrete) (scale-x-continuous)))
      ((:y :ymin :ymax :yend)
       (if discrete (scale-y-discrete) (scale-y-continuous)))
      ;; plotnine >= 0.13: default continuous color/fill is viridis
      (:color
       (if discrete (scale-color-discrete) (scale-color-cmap)))
      (:fill
       (if discrete (scale-fill-discrete) (scale-fill-cmap)))
      (:shape (scale-shape-manual))
      (:size
       (if discrete
           (error "Discrete size scales are not supported (use a manual scale)")
           (scale-size)))
      (:alpha
       (if discrete
           (error "Discrete alpha scales are not supported (use a manual scale)")
           (scale-alpha)))
      (t nil))))

;;; ============================================================
;;; Continuous color scales (gradients)
;;; ============================================================

(defun %parse-hex-color (hex)
  "\"#RRGGBB\" -> (values r g b) in [0,1]."
  (let ((rgba (cl-matplotlib.colors:to-rgba hex)))
    (values (float (aref rgba 0) 1.0d0)
            (float (aref rgba 1) 1.0d0)
            (float (aref rgba 2) 1.0d0))))

(defclass scale-gradient-obj (scale-continuous)
  ((low :initarg :low :initform "#132B43" :reader scale-gradient-low)
   (high :initarg :high :initform "#56B1F7" :reader scale-gradient-high)
   (cmap :initarg :cmap :initform nil :reader scale-gradient-cmap
         :documentation "A cl-matplotlib colormap designator; when set it
takes precedence over low/high. plotnine >= 0.13 defaults continuous
color/fill to the viridis colormap."))
  (:documentation "Continuous color scale: either a registered colormap
(:cmap) or a two-color RGB gradient (ggplot2's blues #132B43 -> #56B1F7),
interpolated like mizani."))

(defun %gradient-fraction-color (scale u)
  "Hex color for U in [0,1] under SCALE's cmap or low/high gradient."
  (let ((cmap (scale-gradient-cmap scale)))
    (if cmap
        (let ((rgba (cl-matplotlib.primitives:colormap-call
                     (cl-matplotlib.primitives:get-colormap cmap) u)))
          (%rgb-to-hex (aref rgba 0) (aref rgba 1) (aref rgba 2)))
        (multiple-value-bind (r0 g0 b0)
            (%parse-hex-color (scale-gradient-low scale))
          (multiple-value-bind (r1 g1 b1)
              (%parse-hex-color (scale-gradient-high scale))
            (%rgb-to-hex (+ r0 (* u (- r1 r0)))
                         (+ g0 (* u (- g1 g0)))
                         (+ b0 (* u (- b1 b0)))))))))

(defmethod scale-map ((scale scale-gradient-obj) values)
  (destructuring-bind (lo hi) (scale-limits scale)
    (let ((span (max (- hi lo) 1.0d-12)))
      (map 'simple-vector
           (lambda (v)
             (%gradient-fraction-color
              scale
              (max 0.0d0 (min 1.0d0 (/ (- (float v 1.0d0) lo) span)))))
           values))))

(defun scale-color-gradient (&rest args &key low high name breaks labels limits guide)
  (declare (ignore low high name breaks labels limits guide))
  (apply #'make-instance 'scale-gradient-obj :aesthetics '(:color) args))

(defun scale-fill-gradient (&rest args &key low high name breaks labels limits guide)
  (declare (ignore low high name breaks labels limits guide))
  (apply #'make-instance 'scale-gradient-obj :aesthetics '(:fill) args))

(defun scale-color-cmap (&rest args &key (cmap-name "viridis") name breaks
                                         labels limits guide)
  "Continuous color scale through a registered matplotlib colormap
(viridis by default, like plotnine)."
  (declare (ignore name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (eq k :cmap-name) append (list k v))))
    (apply #'make-instance 'scale-gradient-obj
           :aesthetics '(:color) :cmap cmap-name clean)))

(defun scale-fill-cmap (&rest args &key (cmap-name "viridis") name breaks
                                        labels limits guide)
  "Continuous fill scale through a registered matplotlib colormap."
  (declare (ignore name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (eq k :cmap-name) append (list k v))))
    (apply #'make-instance 'scale-gradient-obj
           :aesthetics '(:fill) :cmap cmap-name clean)))

;;; ============================================================
;;; Log10 positional scales
;;; ============================================================
;;; plotnine transforms the data into log space before stats and keeps the
;;; axis linear, placing ticks at integer exponents. Same approach here.

(defclass scale-log10-obj (scale-continuous) ())

(defmethod scale-transform ((scale scale-log10-obj) values)
  (map 'simple-vector
       (lambda (v)
         (let ((v (float v 1.0d0)))
           (if (plusp v)
               (log v 10.0d0)
               (error "log10 scale: non-positive value ~S" v))))
       values))

(defmethod scale-breaks ((scale scale-log10-obj))
  (let ((user (scale-user-breaks scale)))
    (if (not (eq user :auto))
        user
        (destructuring-bind (lo hi) (scale-limits scale)
          (loop for k from (ceiling (- lo 1.0d-9)) to (floor (+ hi 1.0d-9))
                collect (float k 1.0d0))))))

(defmethod scale-break-labels ((scale scale-log10-obj) breaks)
  (let ((user (scale-user-labels scale)))
    (if (not (eq user :auto))
        user
        ;; mizani log_format: plain decimals while every exponent is in
        ;; [-4, 4]; once any break reaches 1e5 (or 1e-5) ALL labels switch
        ;; to 1eN notation
        (if (some (lambda (k) (or (>= k 5.0d0) (<= k -5.0d0))) breaks)
            (mapcar (lambda (k) (format nil "1e~D" (round k))) breaks)
            (mapcar (lambda (k)
                      (let ((v (expt 10.0d0 k)))
                        (if (>= v 1.0d0)
                            (format nil "~D" (round v))
                            (format nil "~F" v))))
                    breaks)))))

(defmethod scale-minor-breaks ((scale scale-log10-obj) breaks range)
  "Log minors: 2..9 x 10^k between decades (positions in log10 space)."
  (declare (ignore breaks))
  (destructuring-bind (lo hi) range
    (loop for k from (1- (floor lo)) to (ceiling hi)
          append (loop for m from 2 to 9
                       for pos = (+ k (log (float m 1.0d0) 10.0d0))
                       when (<= lo pos hi) collect pos))))

(defun scale-x-log10 (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-log10-obj :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-log10 (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-log10-obj :aesthetics '(:y :ymin :ymax :yend) args))

;;; ============================================================
;;; ColorBrewer palettes (hex values extracted from mizani's brewer_pal,
;;; which plotnine uses; qualitative palettes at max size, sequential and
;;; diverging at 9 levels, interpolated when more are needed)
;;; ============================================================

(defparameter *brewer-palettes*
  '(;; qualitative
    ("Set1" "#E41A1C" "#377EB8" "#4DAF4A" "#984EA3" "#FF7F00" "#FFFF33" "#A65628" "#F781BF" "#999999")
    ("Set2" "#66C2A5" "#FC8D62" "#8DA0CB" "#E78AC3" "#A6D854" "#FFD92F" "#E5C494" "#B3B3B3")
    ("Set3" "#8DD3C7" "#FFFFB3" "#BEBADA" "#FB8072" "#80B1D3" "#FDB462" "#B3DE69" "#FCCDE5" "#D9D9D9" "#BC80BD" "#CCEBC5" "#FFED6F")
    ("Dark2" "#1B9E77" "#D95F02" "#7570B3" "#E7298A" "#66A61E" "#E6AB02" "#A6761D" "#666666")
    ("Paired" "#A6CEE3" "#1F78B4" "#B2DF8A" "#33A02C" "#FB9A99" "#E31A1C" "#FDBF6F" "#FF7F00" "#CAB2D6" "#6A3D9A" "#FFFF99" "#B15928")
    ("Accent" "#7FC97F" "#BEAED4" "#FDC086" "#FFFF99" "#386CB0" "#F0027F" "#BF5B17" "#666666")
    ("Pastel1" "#FBB4AE" "#B3CDE3" "#CCEBC5" "#DECBE4" "#FED9A6" "#FFFFCC" "#E5D8BD" "#FDDAEC" "#F2F2F2")
    ("Pastel2" "#B3E2CD" "#FDCDAC" "#CBD5E8" "#F4CAE4" "#E6F5C9" "#FFF2AE" "#F1E2CC" "#CCCCCC")
    ;; sequential
    ("Blues" "#F7FBFF" "#DEEBF7" "#C6DBEF" "#9ECAE1" "#6BAED6" "#4292C6" "#2171B5" "#08519C" "#08306B")
    ("Greens" "#F7FCF5" "#E5F5E0" "#C7E9C0" "#A1D99B" "#74C476" "#41AB5D" "#238B45" "#006D2C" "#00441B")
    ("Reds" "#FFF5F0" "#FEE0D2" "#FCBBA1" "#FC9272" "#FB6A4A" "#EF3B2C" "#CB181D" "#A50F15" "#67000D")
    ("Oranges" "#FFF5EB" "#FEE6CE" "#FDD0A2" "#FDAE6B" "#FD8D3C" "#F16913" "#D94801" "#A63603" "#7F2704")
    ("Purples" "#FCFBFD" "#EFEDF5" "#DADAEB" "#BCBDDC" "#9E9AC8" "#807DBA" "#6A51A3" "#54278F" "#3F007D")
    ("Greys" "#FFFFFF" "#F0F0F0" "#D9D9D9" "#BDBDBD" "#969696" "#737373" "#525252" "#252525" "#000000")
    ("YlOrBr" "#FFFFE5" "#FFF7BC" "#FEE391" "#FEC44F" "#FE9929" "#EC7014" "#CC4C02" "#993404" "#662506")
    ("YlGnBu" "#FFFFD9" "#EDF8B1" "#C7E9B4" "#7FCDBB" "#41B6C4" "#1D91C0" "#225EA8" "#253494" "#081D58")
    ;; diverging
    ("RdBu" "#B2182B" "#D6604D" "#F4A582" "#FDDBC7" "#F7F7F7" "#D1E5F0" "#92C5DE" "#4393C3" "#2166AC")
    ("RdYlBu" "#D73027" "#F46D43" "#FDAE61" "#FEE090" "#FFFFBF" "#E0F3F8" "#ABD9E9" "#74ADD1" "#4575B4")
    ("BrBG" "#8C510A" "#BF812D" "#DFC27D" "#F6E8C3" "#F5F5F5" "#C7EAE5" "#80CDC1" "#35978F" "#01665E")
    ("PiYG" "#C51B7D" "#DE77AE" "#F1B6DA" "#FDE0EF" "#F7F7F7" "#E6F5D0" "#B8E186" "#7FBC41" "#4D9221")
    ("PRGn" "#762A83" "#9970AB" "#C2A5CF" "#E7D4E8" "#F7F7F7" "#D9F0D3" "#A6DBA0" "#5AAE61" "#1B7837")
    ("Spectral" "#D53E4F" "#F46D43" "#FDAE61" "#FEE08B" "#FFFFBF" "#E6F598" "#ABDDA4" "#66C2A5" "#3288BD")))

(defun brewer-palette (palette n)
  "First N colors of the ColorBrewer PALETTE (a name string), erroring
past the palette's size like mizani does for qualitative palettes."
  (let ((colors (cdr (assoc palette *brewer-palettes* :test #'string-equal))))
    (unless colors
      (error "Unknown brewer palette ~S. Known: ~{~A~^ ~}"
             palette (mapcar #'car *brewer-palettes*)))
    (when (> n (length colors))
      (error "Brewer palette ~A has only ~D colors (asked for ~D)"
             palette (length colors) n))
    (subseq colors 0 n)))

(defun scale-color-brewer (&rest args &key (palette "Set1") type name breaks
                                           labels limits guide)
  "Discrete colors from a ColorBrewer palette. TYPE is accepted for
plotnine compatibility and ignored (the palette name is unambiguous)."
  (declare (ignore type name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:palette :type)) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:color)
           :palette (lambda (n) (brewer-palette palette n))
           clean)))

(defun scale-fill-brewer (&rest args &key (palette "Set1") type name breaks
                                          labels limits guide)
  "Discrete fills from a ColorBrewer palette."
  (declare (ignore type name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:palette :type)) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:fill)
           :palette (lambda (n) (brewer-palette palette n))
           clean)))

;;; ============================================================
;;; Diverging and multi-stop gradients (mizani gradient_n_pal: linear
;;; RGB interpolation between stops)
;;; ============================================================

(defclass scale-gradientn-obj (scale-continuous)
  ((colors :initarg :colors :reader scale-gradientn-colors)
   (stop-values :initarg :stop-values :initform nil
                :reader scale-gradientn-values
                :documentation "Stop positions in [0,1]; NIL = even.")
   (midpoint :initarg :midpoint :initform nil
             :reader scale-gradientn-midpoint
             :documentation "Data value mapped to the middle stop
(gradient2); NIL maps limits linearly onto [0,1]."))
  (:documentation "Continuous color scale interpolating a color list."))

(defmethod scale-map ((scale scale-gradientn-obj) values)
  (destructuring-bind (lo hi) (scale-limits scale)
    (let* ((colors (scale-gradientn-colors scale))
           (n (length colors))
           (stops (or (scale-gradientn-values scale)
                      (loop for i from 0 below n
                            collect (/ (float i 1.0d0) (max 1 (1- n))))))
           (rgbs (mapcar (lambda (c)
                           (multiple-value-list (%parse-hex-color c)))
                         colors))
           (mid (scale-gradientn-midpoint scale)))
      (flet ((to-unit (v)
               (let ((v (float v 1.0d0)))
                 (if mid
                     ;; symmetric around the midpoint (gradient2)
                     (let ((half (max (- hi mid) (- mid lo) 1.0d-12)))
                       (max 0.0d0 (min 1.0d0
                                       (+ 0.5d0 (/ (- v mid) (* 2 half))))))
                     (max 0.0d0 (min 1.0d0 (/ (- v lo)
                                              (max (- hi lo) 1.0d-12)))))))
             (interp (u)
               (loop for (s0 s1) on stops
                     for (c0 c1) on rgbs
                     while s1
                     when (<= u s1)
                       return (let ((f (/ (- u s0) (max (- s1 s0) 1.0d-12))))
                                (%rgb-to-hex
                                 (+ (first c0) (* f (- (first c1) (first c0))))
                                 (+ (second c0) (* f (- (second c1) (second c0))))
                                 (+ (third c0) (* f (- (third c1) (third c0))))))
                     finally (return (apply #'%rgb-to-hex (car (last rgbs)))))))
        (map 'simple-vector (lambda (v) (interp (to-unit v))) values)))))

(defun scale-color-gradient2 (&rest args &key (low "#832424") (mid "#FFFFFF")
                                              (high "#3A3A98") (midpoint 0.0d0)
                                              name breaks labels limits guide)
  "Diverging gradient: LOW at one end, MID at MIDPOINT, HIGH at the other
(plotnine defaults #832424/white/#3A3A98, midpoint 0)."
  (declare (ignore name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:low :mid :high :midpoint))
                       append (list k v))))
    (apply #'make-instance 'scale-gradientn-obj
           :aesthetics '(:color)
           :colors (list low mid high) :midpoint midpoint clean)))

(defun scale-fill-gradient2 (&rest args &key (low "#832424") (mid "#FFFFFF")
                                             (high "#3A3A98") (midpoint 0.0d0)
                                             name breaks labels limits guide)
  "Diverging fill gradient (see scale-color-gradient2)."
  (declare (ignore name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:low :mid :high :midpoint))
                       append (list k v))))
    (apply #'make-instance 'scale-gradientn-obj
           :aesthetics '(:fill)
           :colors (list low mid high) :midpoint midpoint clean)))

(defun scale-color-gradientn (&rest args &key colors values name breaks
                                              labels limits guide)
  "Continuous colors through an arbitrary stop list."
  (declare (ignore name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:colors :values)) append (list k v))))
    (apply #'make-instance 'scale-gradientn-obj
           :aesthetics '(:color) :colors colors :stop-values values clean)))

(defun scale-fill-gradientn (&rest args &key colors values name breaks
                                             labels limits guide)
  "Continuous fills through an arbitrary stop list."
  (declare (ignore name breaks labels limits guide))
  (let ((clean (loop for (k v) on args by #'cddr
                     unless (member k '(:colors :values)) append (list k v))))
    (apply #'make-instance 'scale-gradientn-obj
           :aesthetics '(:fill) :colors colors :stop-values values clean)))

;;; ============================================================
;;; sqrt / reverse positional transforms
;;; ============================================================

(defclass scale-sqrt-obj (scale-continuous) ())

(defmethod scale-transform ((scale scale-sqrt-obj) values)
  (map 'simple-vector
       (lambda (v)
         (let ((v (float v 1.0d0)))
           (if (minusp v)
               (error "sqrt scale: negative value ~S" v)
               (sqrt v))))
       values))

(defmethod scale-break-labels ((scale scale-sqrt-obj) breaks)
  (let ((user (scale-user-labels scale)))
    (if (not (eq user :auto))
        user
        ;; label with the untransformed values
        (%format-break-set (mapcar (lambda (b) (* b b)) breaks)))))

(defun scale-x-sqrt (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-sqrt-obj :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-sqrt (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-sqrt-obj :aesthetics '(:y :ymin :ymax :yend) args))

(defclass scale-reverse-obj (scale-continuous) ())

(defmethod scale-transform ((scale scale-reverse-obj) values)
  (map 'simple-vector (lambda (v) (- (float v 1.0d0))) values))

(defmethod scale-break-labels ((scale scale-reverse-obj) breaks)
  (let ((user (scale-user-labels scale)))
    (if (not (eq user :auto))
        user
        (%format-break-set (mapcar #'- breaks)))))

(defun scale-x-reverse (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-reverse-obj :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-reverse (&rest args &key name breaks labels limits expand)
  (declare (ignore name breaks labels limits expand))
  (apply #'make-instance 'scale-reverse-obj :aesthetics '(:y :ymin :ymax :yend) args))

;;; ============================================================
;;; Identity scales: values used as-is
;;; ============================================================

(defclass scale-identity-obj (scale)
  ())

(defmethod scale-train ((scale scale-identity-obj) values)
  (declare (ignore values)))
(defmethod scale-transform ((scale scale-identity-obj) values) values)
(defmethod scale-map ((scale scale-identity-obj) values) values)
(defmethod scale-limits ((scale scale-identity-obj)) (list 0 1))
(defmethod scale-breaks ((scale scale-identity-obj)) '())
(defmethod scale-break-labels ((scale scale-identity-obj) breaks)
  (declare (ignore breaks))
  '())

(defun scale-color-identity ()
  "Use the mapped column's values directly as colors."
  (make-instance 'scale-identity-obj :aesthetics '(:color) :guide :none))

(defun scale-fill-identity ()
  "Use the mapped column's values directly as fills."
  (make-instance 'scale-identity-obj :aesthetics '(:fill) :guide :none))

(defun scale-shape-identity ()
  (make-instance 'scale-identity-obj :aesthetics '(:shape) :guide :none))

(defun scale-size-identity ()
  (make-instance 'scale-identity-obj :aesthetics '(:size) :guide :none))

;;; ============================================================
;;; Grey palettes
;;; ============================================================

(defun grey-palette (n &key (start 0.2d0) (end 0.8d0))
  "ggplot2's grey_pal: N evenly spaced greys from START to END luminance."
  (loop for i from 0 below n
        for g = (if (= n 1)
                    start
                    (+ start (* i (/ (- end start) (1- n)))))
        collect (%rgb-to-hex g g g)))

(defun scale-color-grey (&rest args &key start end name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (member k '(:start :end)) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:color)
           :palette (lambda (n) (grey-palette n :start (or start 0.2d0)
                                                :end (or end 0.8d0)))
           rest)))

(defun scale-fill-grey (&rest args &key start end name breaks labels limits guide)
  (declare (ignore name breaks labels limits guide))
  (let ((rest (loop for (k v) on args by #'cddr
                    unless (member k '(:start :end)) append (list k v))))
    (apply #'make-instance 'scale-discrete-palette
           :aesthetics '(:fill)
           :palette (lambda (n) (grey-palette n :start (or start 0.2d0)
                                                :end (or end 0.8d0)))
           rest)))

;;; ============================================================
;;; Date scales
;;; ============================================================
;;; Dates in gg are Common Lisp universal times (integers). The scale
;;; positions them as fractional days and generates calendar-aware breaks
;;; and strftime-style labels. All conversions use GMT so results don't
;;; depend on the host timezone (pandas datetimes are naive/UTC-like).

(defconstant +seconds-per-day+ 86400)

(defun date (year month day &optional (hour 0) (minute 0) (second 0))
  "A date value for gg data columns: universal time at GMT."
  (encode-universal-time second minute hour day month year 0))

(defun %ut-to-days (ut)
  (/ (float ut 1.0d0) +seconds-per-day+))

(defun %days-to-ut (days)
  (round (* days +seconds-per-day+)))

(defparameter *month-abbrevs*
  #("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))
(defparameter *month-names*
  #("January" "February" "March" "April" "May" "June" "July" "August"
    "September" "October" "November" "December"))

(defun format-date (ut fmt)
  "Format universal-time UT with strftime-style directives:
%Y year, %m month (2-digit), %d day (2-digit), %e day (no pad),
%b abbreviated month, %B full month, %y 2-digit year."
  (multiple-value-bind (sec min hour day month year)
      (decode-universal-time ut 0)
    (declare (ignore sec min hour))
    (with-output-to-string (out)
      (loop with i = 0
            while (< i (length fmt))
            do (let ((ch (char fmt i)))
                 (if (and (char= ch #\%) (< (1+ i) (length fmt)))
                     (progn
                       (case (char fmt (1+ i))
                         (#\Y (format out "~D" year))
                         (#\y (format out "~2,'0D" (mod year 100)))
                         (#\m (format out "~2,'0D" month))
                         (#\d (format out "~2,'0D" day))
                         (#\e (format out "~D" day))
                         (#\b (write-string (aref *month-abbrevs* (1- month)) out))
                         (#\B (write-string (aref *month-names* (1- month)) out))
                         (#\% (write-char #\% out))
                         (t (write-char #\% out)
                            (write-char (char fmt (1+ i)) out)))
                       (incf i 2))
                     (progn (write-char ch out) (incf i)))))
      out)))

(defclass scale-date-obj (scale-continuous)
  ((date-breaks :initarg :date-breaks :initform nil
                :reader scale-date-breaks-spec
                :documentation "NIL for auto, or (:unit n) with unit one of
:year :month :week :day, e.g. (:month 6).")
   (date-labels :initarg :date-labels :initform nil
                :reader scale-date-labels-fmt
                :documentation "strftime-style format string, or NIL for
an automatic choice based on the break unit.")))

(defmethod scale-transform ((scale scale-date-obj) values)
  (map 'simple-vector (lambda (v) (%ut-to-days v)) values))

(defun %date-add-months (year month n)
  "(values year month) N months after YEAR-MONTH."
  (let ((total (+ (* year 12) (1- month) n)))
    (values (floor total 12) (1+ (mod total 12)))))

(defun %date-break-uts (lo-ut hi-ut spec)
  "Universal times of calendar breaks covering [LO-UT, HI-UT]."
  (multiple-value-bind (s mi h d mo y) (decode-universal-time lo-ut 0)
    (declare (ignore s mi h))
    (destructuring-bind (unit n) spec
      (ecase unit
        ;; Sequences anchor at the first unit boundary AT/AFTER lo and step
        ;; by N from there (plotnine phase: Jan..Dec data with '6 months'
        ;; shows Dec/Jun breaks, anchored inside the expanded range).
        (:year
         (let ((y0 (if (>= (encode-universal-time 0 0 0 1 1 y 0)
                           (- lo-ut +seconds-per-day+))
                       y
                       (1+ y))))
           (loop for yy from y0 by n
                 for ut = (encode-universal-time 0 0 0 1 1 yy 0)
                 while (<= ut (+ hi-ut +seconds-per-day+))
                 collect ut)))
        (:month
         (multiple-value-bind (y0 m0)
             (if (>= (encode-universal-time 0 0 0 1 mo y 0)
                     (- lo-ut +seconds-per-day+))
                 (values y mo)
                 (%date-add-months y mo 1))
           (loop with yy = y0 and mm = m0
                 for ut = (encode-universal-time 0 0 0 1 mm yy 0)
                 while (<= ut (+ hi-ut +seconds-per-day+))
                 collect ut
                 do (multiple-value-setq (yy mm) (%date-add-months yy mm n)))))
        ((:week :day)
         (let ((step (* n (if (eq unit :week) 7 1) +seconds-per-day+))
               (start (encode-universal-time 0 0 0 d mo y 0)))
           (loop for ut = start then (+ ut step)
                 while (<= ut hi-ut)
                 when (>= ut lo-ut) collect ut)))))))

(defun %auto-date-spec (span-days)
  (cond ((> span-days 1460) (list :year 1))
        ((> span-days 730) (list :month 6))
        ((> span-days 240) (list :month 3))
        ((> span-days 60) (list :month 1))
        ((> span-days 14) (list :week 1))
        (t (list :day 1))))

(defun %auto-date-fmt (spec)
  (ecase (first spec)
    (:year "%Y")
    (:month "%Y-%m")
    ((:week :day) "%b %e")))

(defmethod scale-breaks ((scale scale-date-obj))
  (let ((user (scale-user-breaks scale)))
    (if (not (eq user :auto))
        user
        ;; plotnine anchors the break sequence at the first calendar unit
        ;; inside the EXPANDED range (that is why a Jan-Dec span shows a
        ;; December break before the data starts)
        (destructuring-bind (lo hi) (scale-expanded-range scale)   ; in days
          (let* ((lo-ut (%days-to-ut lo))
                 (hi-ut (%days-to-ut hi))
                 (spec (or (scale-date-breaks-spec scale)
                           (%auto-date-spec (- hi lo)))))
            (mapcar #'%ut-to-days (%date-break-uts lo-ut hi-ut spec)))))))

(defmethod scale-break-labels ((scale scale-date-obj) breaks)
  (let ((user (scale-user-labels scale)))
    (if (not (eq user :auto))
        user
        (let ((fmt (or (scale-date-labels-fmt scale)
                       (%auto-date-fmt (or (scale-date-breaks-spec scale)
                                           (destructuring-bind (lo hi)
                                               (scale-limits scale)
                                             (%auto-date-spec (- hi lo))))))))
          (mapcar (lambda (b) (format-date (%days-to-ut b) fmt)) breaks)))))

(defun scale-x-date (&rest args &key date-breaks date-labels
                                     name breaks labels limits expand)
  "Date x axis for universal-time columns:
(scale-x-date :date-breaks '(:month 6) :date-labels \"%b %Y\")."
  (declare (ignore date-breaks date-labels name breaks labels limits expand))
  (apply #'make-instance 'scale-date-obj :aesthetics '(:x :xmin :xmax :xend) args))

(defun scale-y-date (&rest args &key date-breaks date-labels
                                     name breaks labels limits expand)
  (declare (ignore date-breaks date-labels name breaks labels limits expand))
  (apply #'make-instance 'scale-date-obj :aesthetics '(:y :ymin :ymax :yend) args))
