;;;; legend.lisp — Legend class with positioning and rendering
;;;; Ported from matplotlib's legend.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Legend position constants
;;; ============================================================

(defparameter *legend-codes*
  '((:best . 0) (:upper-right . 1) (:upper-left . 2) (:lower-left . 3)
    (:lower-right . 4) (:right . 5) (:center-left . 6) (:center-right . 7)
    (:lower-center . 8) (:upper-center . 9) (:center . 10))
  "Mapping from legend location keywords to numeric codes.")

(defparameter *legend-loc-positions*
  '(;; (x-fraction, y-fraction) in axes coordinates for each loc code
    ;; Code 0 (:best) is computed dynamically
    (1 . (0.95d0 0.95d0))   ; upper-right
    (2 . (0.05d0 0.95d0))   ; upper-left
    (3 . (0.05d0 0.05d0))   ; lower-left
    (4 . (0.95d0 0.05d0))   ; lower-right
    (5 . (0.95d0 0.50d0))   ; right (= center-right)
    (6 . (0.05d0 0.50d0))   ; center-left
    (7 . (0.95d0 0.50d0))   ; center-right
    (8 . (0.50d0 0.05d0))   ; lower-center
    (9 . (0.50d0 0.95d0))   ; upper-center
    (10 . (0.50d0 0.50d0))) ; center
  "Position fractions in axes coordinates for each location code.")

;;; ============================================================
;;; Legend class
;;; ============================================================

(defclass mpl-legend (mpl.rendering:artist)
  ((legend-parent :initarg :parent
                  :initform nil
                  :accessor legend-parent
                  :documentation "Parent Axes or Figure.")
   (legend-handles :initarg :handles
                   :initform nil
                   :accessor legend-handles
                   :documentation "List of artist handles for legend entries.")
   (legend-labels :initarg :labels
                  :initform nil
                  :accessor legend-labels
                  :documentation "List of string labels for legend entries.")
   (legend-loc :initarg :loc
               :initform :best
               :accessor legend-loc
               :documentation "Legend position keyword or numeric code.")
   (legend-bbox-to-anchor :initarg :bbox-to-anchor
                          :initform nil
                          :accessor legend-bbox-to-anchor
                          :documentation "Custom bbox for legend positioning.")
   (legend-ncol :initarg :ncol
                :initform 1
                :accessor legend-ncol
                :type fixnum
                :documentation "Number of columns in the legend.")
   (legend-fontsize :initarg :fontsize
                    :initform 10.0
                    :accessor legend-fontsize
                    :type real
                    :documentation "Font size for legend text in points.")
   (legend-frameon :initarg :frameon
                   :initform t
                   :accessor legend-frameon-p
                   :type boolean
                   :documentation "Whether to draw a frame around the legend.")
   (legend-facecolor :initarg :facecolor
                     :initform "white"
                     :accessor legend-facecolor
                     :documentation "Legend frame background color.")
   (legend-edgecolor :initarg :edgecolor
                     :initform "#cccccc"
                     :accessor legend-edgecolor
                     :documentation "Legend frame edge color.")
   (legend-framealpha :initarg :framealpha
                      :initform 0.8d0
                      :accessor legend-framealpha
                      :type (or null double-float)
                      :documentation "Legend frame alpha (transparency).")
   (legend-title :initarg :title
                 :initform ""
                 :accessor legend-title
                 :type string
                 :documentation "Legend title text.")
   (legend-title-fontsize :initarg :title-fontsize
                          :initform 11.0
                          :accessor legend-title-fontsize
                          :type real
                          :documentation "Font size for legend title.")
   (legend-handleheight :initarg :handleheight
                        :initform 0.7d0
                        :accessor legend-handleheight
                        :type double-float
                        :documentation "Height of the legend handle in font-size units.")
   (legend-handlelength :initarg :handlelength
                        :initform 2.0d0
                        :accessor legend-handlelength
                        :type double-float
                        :documentation "Length of the legend handle in font-size units.")
   (legend-handletextpad :initarg :handletextpad
                         :initform 0.8d0
                         :accessor legend-handletextpad
                         :type double-float
                         :documentation "Padding between handle and text in font-size units.")
   (legend-columnspacing :initarg :columnspacing
                         :initform 2.0d0
                         :accessor legend-columnspacing
                         :type double-float
                         :documentation "Spacing between columns in font-size units.")
   (legend-borderpad :initarg :borderpad
                     :initform 0.4d0
                     :accessor legend-borderpad
                     :type double-float
                     :documentation "Padding inside the legend frame in font-size units.")
   (legend-labelspacing :initarg :labelspacing
                        :initform 0.5d0
                        :accessor legend-labelspacing
                        :type double-float
                        :documentation "Spacing between legend entries in font-size units.")
   (legend-handler-map :initarg :handler-map
                       :initform nil
                       :accessor legend-handler-map
                       :documentation "Custom handler map (merged with defaults).")
   ;; Cached layout
   (legend-entry-artists :initform nil
                         :accessor legend-entry-artists
                         :documentation "Cached list of (handle-artists . text-artist) for each entry.")
   (legend-frame :initform nil
                 :accessor legend-frame
                 :documentation "Legend frame rectangle patch."))
  (:default-initargs :zorder 5)
  (:documentation "Represents a legend on an Axes or Figure.
Contains handles (artists) and labels (text) arranged in a box.
Ported from matplotlib.legend.Legend."))

(defmethod initialize-instance :after ((leg mpl-legend) &key parent)
  "Initialize legend: resolve loc, build entry artists, create frame."
  (when parent
    (setf (legend-parent leg) parent)
    (setf (mpl.rendering:artist-axes leg) parent)
    (when (typep parent 'axes-base)
      (setf (mpl.rendering:artist-figure leg) (axes-base-figure parent))))
  ;; Resolve loc keyword to numeric code
  (let ((loc (legend-loc leg)))
    (when (keywordp loc)
      (let ((entry (assoc loc *legend-codes*)))
        (when entry
          (setf (legend-loc leg) (cdr entry))))))
  ;; Build legend entries
  (%legend-build-entries leg)
  ;; Create frame
  (when (legend-frameon-p leg)
    (setf (legend-frame leg)
          (make-instance 'mpl.rendering:rectangle
                         :x0 0.0d0 :y0 0.0d0
                         :width 1.0d0 :height 1.0d0
                         :facecolor (legend-facecolor leg)
                         :edgecolor (legend-edgecolor leg)
                         :linewidth 0.8
                         :zorder 4.99))))

;;; ============================================================
;;; Legend entry building
;;; ============================================================

(defun %legend-build-entries (leg)
  "Build legend entry artists from handles and labels."
  (let ((handles (legend-handles leg))
        (labels (legend-labels leg))
        (handler-map (or (legend-handler-map leg) *default-handler-map*))
        (fontsize (legend-fontsize leg))
        (entries nil))
    (loop for handle in handles
          for label in labels
          do (let* ((handler (get-legend-handler handle handler-map))
                    (handle-artists (when handler
                                     (legend-artist handler leg handle
                                                    fontsize
                                                    (* (legend-handlelength leg) fontsize))))
                    (text-art (make-instance 'mpl.rendering:text-artist
                                             :text label
                                             :fontsize fontsize
                                             :color "black"
                                             :verticalalignment :center
                                             :horizontalalignment :left
                                             :zorder 5)))
               (push (cons handle-artists text-art) entries)))
    (setf (legend-entry-artists leg) (nreverse entries))))

;;; ============================================================
;;; Legend positioning
;;; ============================================================

(defun %legend-get-loc-position (loc-code)
  "Get the (x-frac, y-frac) position in axes coordinates for LOC-CODE."
  (let ((entry (assoc loc-code *legend-loc-positions*)))
    (if entry
        (cdr entry)
        (list 0.95d0 0.95d0))))  ; default to upper-right

(defun %legend-compute-bbox (leg renderer)
  "Compute the legend bounding box in display coordinates.
Returns (values x y width height) in display space."
  (let* ((parent (legend-parent leg))
         (fontsize (legend-fontsize leg))
         ;; DPI scale factor: convert points to pixels
         (dpi-scale (if (and renderer (typep renderer 'mpl.backends:renderer-base))
                        (/ (mpl.backends:renderer-dpi renderer) 72.0d0)
                        1.0d0))
         (n-entries (length (legend-entry-artists leg)))
         (ncol (min (legend-ncol leg) (max 1 n-entries)))
         (nrow (ceiling n-entries ncol))
         ;; Compute dimensions in points then convert to pixels
         (handle-len (* (legend-handlelength leg) fontsize dpi-scale))
         (handle-height (* (legend-handleheight leg) fontsize dpi-scale))
         (text-pad (* (legend-handletextpad leg) fontsize dpi-scale))
         (border-pad (* (legend-borderpad leg) fontsize dpi-scale))
         (label-spacing (* (legend-labelspacing leg) fontsize dpi-scale))
         (col-spacing (* (legend-columnspacing leg) fontsize dpi-scale))
         ;; Compute text width using actual glyph metrics (returns points, scale to px)
         (font-loader (mpl.rendering:load-font "sans-serif"))
         (max-label-width (* dpi-scale
                             (loop for entry in (legend-entry-artists leg)
                                   maximize (let ((txt (cdr entry)))
                                              (mpl.primitives:bbox-width
                                               (mpl.rendering:get-text-extents
                                                (mpl.rendering:text-text txt)
                                                font-loader fontsize))))))
         ;; Total column width = handle + pad + text
         ;; Scale text width by 1.05x to compensate for zpb-ttf vs FreeType metrics
         ;; (zpb-ttf measures ~61px vs FreeType ~64px for same text at 10pt/100dpi)
         (col-width (+ handle-len text-pad (* 1.05d0 max-label-width)))
         ;; Total legend width
         (legend-width (+ (* 2 border-pad)
                          (* ncol col-width)
                          (* (max 0 (1- ncol)) col-spacing)))
         ;; Total legend height
         (row-height (max handle-height (* fontsize dpi-scale)))
         (legend-height (+ (* 2 border-pad)
                           (* nrow row-height)
                           (* (max 0 (1- nrow)) label-spacing)))
         ;; Title adds to height
         (title (legend-title leg)))
    (when (and title (plusp (length title)))
      (incf legend-height (* (legend-title-fontsize leg) 1.5d0 dpi-scale)))
    ;; Compute position in display coordinates using matplotlib's algorithm:
    ;; borderaxespad (default 0.5 * fontsize) is the gap from axes edge to legend edge.
    (let* ((loc-code (legend-loc leg))
           (resolved-code (if (numberp loc-code)
                              (if (= loc-code 0)
                                  (%legend-find-best-position leg legend-width legend-height)
                                  loc-code)
                              1))
           ;; borderaxespad: gap between axes edge and legend, in fontsize units
           ;; matplotlib default is 0.5
           (axes-pad (* 0.5d0 fontsize dpi-scale)))
      (if (and parent (typep parent 'axes-base))
          (let ((trans-axes (axes-base-trans-axes parent)))
            (multiple-value-bind (dx dy dw dh)
                (cl-matplotlib.containers::%compute-display-bbox parent)
              (declare (ignore dw dh))
              (let* ((axes-width (- (aref (mpl.primitives:transform-point
                                           trans-axes (list 1.0d0 0.0d0)) 0)
                                    (aref (mpl.primitives:transform-point
                                           trans-axes (list 0.0d0 0.0d0)) 0)))
                     (axes-height (- (aref (mpl.primitives:transform-point
                                            trans-axes (list 0.0d0 1.0d0)) 1)
                                     (aref (mpl.primitives:transform-point
                                            trans-axes (list 0.0d0 0.0d0)) 1)))
                     ;; Compute x,y based on loc code using borderaxespad
                     ;; In display coords: dx=axes-left, dy=axes-bottom
                     ;; axes-right = dx + axes-width, axes-top = dy + axes-height
                     (x-display
                      (case resolved-code
                        ;; upper-right, lower-right, right, center-right
                        ((1 4 5 7) (+ dx axes-width (- legend-width) (- axes-pad)))
                        ;; upper-left, lower-left, center-left
                        ((2 3 6) (+ dx axes-pad))
                        ;; lower-center, upper-center, center
                        ((8 9 10) (+ dx (/ (- axes-width legend-width) 2.0d0)))
                        (otherwise (+ dx axes-width (- legend-width) (- axes-pad)))))
                     (y-display
                      (case resolved-code
                        ;; upper-right, upper-left, upper-center
                        ((1 2 9) (+ dy axes-height (- legend-height) (- axes-pad)))
                        ;; lower-left, lower-right, lower-center
                        ((3 4 8) (+ dy axes-pad))
                        ;; right, center-left, center-right, center
                        ((5 6 7 10) (+ dy (/ (- axes-height legend-height) 2.0d0)))
                        (otherwise (+ dy axes-height (- legend-height) (- axes-pad))))))
                (values x-display y-display legend-width legend-height))))
          ;; No parent — use figure-level positioning
          (values 320.0d0 240.0d0 legend-width legend-height)))))

;;; ============================================================
;;; Legend auto-placement ("best" position)
;;; ============================================================

(defun %legend-find-best-position (leg legend-width legend-height)
  "Find the best position for the legend by minimizing overlap with artists.
Returns a position code (1-10).
Matches matplotlib's _find_best_position: counts data points (vertices) that
fall inside the legend box for each candidate position, plus patch bbox overlaps.
Tests positions 1-9; ties favor lower code (earlier in test order)."
  (let* ((parent (legend-parent leg))
         (fontsize (legend-fontsize leg))
         (best-code 1)
         (best-badness most-positive-double-float)
         ;; axes-pad: borderaxespad in pixels
         (dpi (if (and parent (typep parent 'axes-base))
                  (let ((fig (axes-base-figure parent)))
                    (if fig (figure-dpi fig) 100.0d0))
                  100.0d0))
         (axes-pad (* 0.5d0 fontsize (/ dpi 72.0d0)))
         ;; matplotlib tests positions in this order; ties favor earlier entries
         (test-order '(1 2 3 4 5 6 7 8 9)))
    (when (and parent (typep parent 'axes-base))
      (let* ((trans (axes-base-trans-data parent))
             ;; Collect all line vertices in display coordinates
             (all-vertices nil)
             ;; Collect patch bboxes in display coordinates
             (patch-bboxes nil))
        ;; Transform all line data points to display coordinates
        (dolist (line (axes-base-lines parent))
          (let ((xdata (mpl.rendering:line-2d-xdata line))
                (ydata (mpl.rendering:line-2d-ydata line)))
            (when (and (> (length xdata) 0) (> (length ydata) 0))
              (let ((n (min (length xdata) (length ydata))))
                (dotimes (i n)
                  (let ((pt (mpl.primitives:transform-point
                             trans (list (float (elt xdata i) 1.0d0)
                                        (float (elt ydata i) 1.0d0)))))
                    (push (cons (aref pt 0) (aref pt 1)) all-vertices)))))))
        ;; Collect patch bboxes (bar charts etc.)
        (dolist (patch (axes-base-patches parent))
          (when (and (typep patch 'mpl.rendering:rectangle)
                     (eq (mpl.rendering:get-artist-transform patch) trans))
            (let* ((x0 (mpl.rendering:rectangle-x0 patch))
                   (y0 (mpl.rendering:rectangle-y0 patch))
                   (w  (mpl.rendering:rectangle-width patch))
                   (h  (mpl.rendering:rectangle-height patch))
                   (p0 (mpl.primitives:transform-point trans (list x0 y0)))
                   (p1 (mpl.primitives:transform-point trans (list (+ x0 w) (+ y0 h)))))
              (push (list (min (aref p0 0) (aref p1 0))
                          (min (aref p0 1) (aref p1 1))
                          (max (aref p0 0) (aref p1 0))
                          (max (aref p0 1) (aref p1 1)))
                    patch-bboxes))))
        ;; Test each candidate position.
        ;; Matches matplotlib: min over (badness, idx) tuples — idx only
        ;; breaks exact ties (lexicographic comparison).
        (let ((best-idx most-positive-fixnum))
          (loop for code in test-order
                for idx from 0
                do (let ((badness (%compute-legend-point-overlap
                                    parent code legend-width legend-height
                                    axes-pad all-vertices patch-bboxes)))
                     ;; If zero overlap, return immediately (matches matplotlib)
                     (when (= badness 0)
                       (return-from %legend-find-best-position code))
                     ;; Lexicographic (badness, idx) comparison
                     (when (or (< badness best-badness)
                               (and (= badness best-badness) (< idx best-idx)))
                       (setf best-badness badness
                             best-idx idx
                             best-code code)))))))
    best-code))

(defun %compute-legend-point-overlap (parent loc-code legend-width legend-height
                                       axes-pad vertices patch-bboxes)
  "Count data points inside legend box at LOC-CODE, plus patch bbox overlaps.
Matches matplotlib's _find_best_position: counts vertices contained in the
legend box and bboxes that overlap with it."
  (multiple-value-bind (dx dy dw dh)
      (%compute-display-bbox parent)
    (declare (ignore dw dh))
    (let* ((trans-axes (axes-base-trans-axes parent))
           (axes-width (- (aref (mpl.primitives:transform-point
                                   trans-axes (list 1.0d0 0.0d0)) 0)
                          (aref (mpl.primitives:transform-point
                                   trans-axes (list 0.0d0 0.0d0)) 0)))
           (axes-height (- (aref (mpl.primitives:transform-point
                                    trans-axes (list 0.0d0 1.0d0)) 1)
                            (aref (mpl.primitives:transform-point
                                    trans-axes (list 0.0d0 0.0d0)) 1)))
           ;; Legend position (same logic as %legend-compute-bbox)
           (lx0 (case loc-code
                   ((1 4 5 7) (+ dx axes-width (- legend-width) (- axes-pad)))
                   ((2 3 6) (+ dx axes-pad))
                   ((8 9 10) (+ dx (/ (- axes-width legend-width) 2.0d0)))
                   (otherwise (+ dx axes-width (- legend-width) (- axes-pad)))))
           (ly0 (case loc-code
                   ((1 2 9) (+ dy axes-height (- legend-height) (- axes-pad)))
                   ((3 4 8) (+ dy axes-pad))
                   ((5 6 7 10) (+ dy (/ (- axes-height legend-height) 2.0d0)))
                   (otherwise (+ dy axes-height (- legend-height) (- axes-pad)))))
           (lx1 (+ lx0 legend-width))
           (ly1 (+ ly0 legend-height))
           (count 0))
      ;; Count vertices inside legend box
      (dolist (v vertices)
        (let ((vx (car v)) (vy (cdr v)))
          (when (and (>= vx lx0) (<= vx lx1)
                     (>= vy ly0) (<= vy ly1))
            (incf count))))
      ;; Count patch bboxes that overlap with legend box
      (dolist (bbox patch-bboxes)
        (let* ((bx0 (first bbox)) (by0 (second bbox))
               (bx1 (third bbox)) (by1 (fourth bbox)))
          (when (and (< bx0 lx1) (> bx1 lx0)
                     (< by0 ly1) (> by1 ly0))
            (incf count))))
      count)))

;;; ============================================================
;;; Legend draw method
;;; ============================================================

(defmethod mpl.rendering:draw ((leg mpl-legend) renderer)
  "Draw the legend: frame, then entries (handle artists + labels)."
  (unless (mpl.rendering:artist-visible leg)
    (return-from mpl.rendering:draw))
  (multiple-value-bind (x y width height)
      (%legend-compute-bbox leg renderer)
    ;; Draw frame
    (when (legend-frameon-p leg)
      (%legend-draw-frame leg renderer x y width height))
    ;; Draw title
    (let ((title (legend-title leg))
          (current-y (+ y height))
          ;; DPI scale factor: must match %legend-compute-bbox
          (dpi-scale (if (and renderer (typep renderer 'mpl.backends:renderer-base))
                         (/ (mpl.backends:renderer-dpi renderer) 72.0d0)
                         1.0d0)))
      (when (and title (plusp (length title)))
        (let* ((title-fontsize (legend-title-fontsize leg))
               (title-x (+ x (* (legend-borderpad leg) (legend-fontsize leg) dpi-scale)))
               (title-y (- current-y (* title-fontsize 1.2d0 dpi-scale))))
          (%legend-draw-text renderer title title-x title-y
                              :fontsize (* title-fontsize dpi-scale) :weight :bold)
          (decf current-y (* title-fontsize 1.5d0 dpi-scale))))
      ;; Draw entries
      (let* ((fontsize (legend-fontsize leg))
             (border-pad (* (legend-borderpad leg) fontsize dpi-scale))
             (handle-len (* (legend-handlelength leg) fontsize dpi-scale))
             (text-pad (* (legend-handletextpad leg) fontsize dpi-scale))
             (label-spacing (* (legend-labelspacing leg) fontsize dpi-scale))
             (row-height (max (* (legend-handleheight leg) fontsize dpi-scale)
                              (* fontsize dpi-scale)))
             (entry-x (+ x border-pad))
             (entry-y (- current-y border-pad)))
        (loop for entry in (legend-entry-artists leg)
              for i from 0
              do (let* ((handle-artists (car entry))
                        (text-art (cdr entry))
                        ;; Position for this entry
                        (ex entry-x)
                        (ey (- entry-y (* i (+ row-height label-spacing))
                               (/ row-height 2.0d0))))
                   ;; Draw handle artists
                   (dolist (artist handle-artists)
                     (%legend-draw-handle-artist
                      renderer artist ex ey handle-len row-height))
                    ;; Draw label text — use :center VA to match matplotlib's center_baseline
                    (let ((text-x (+ ex handle-len text-pad)))
                      (when (typep renderer 'mpl.backends:renderer-base)
                        (let* ((rgba-color (%resolve-legend-color "black" 1.0d0))
                               (gc (mpl.backends:make-graphics-context
                                    :facecolor nil
                                    :edgecolor rgba-color
                                    :linewidth (* fontsize dpi-scale))))
                          (mpl.backends:draw-text renderer gc
                                                  (float text-x 1.0d0) (float ey 1.0d0)
                                                  (mpl.rendering:text-text text-art)
                                                  nil 0.0 nil :left :center)))))))))
  (setf (mpl.rendering:artist-stale leg) nil))

;;; ============================================================
;;; Legend drawing helpers
;;; ============================================================

(defun %legend-draw-frame (leg renderer x y width height)
  "Draw the legend frame rectangle."
  (let* ((facecolor (legend-facecolor leg))
         (edgecolor (legend-edgecolor leg))
         (alpha (or (legend-framealpha leg) 1.0d0))
         (path (mpl.primitives:path-unit-rectangle))
         (transform (mpl.primitives:make-affine-2d
                     :scale (list width height)
                     :translate (list x y))))
    ;; Resolve colors
    (let ((face-rgba (%resolve-legend-color facecolor alpha))
          (edge-rgba (%resolve-legend-color edgecolor 1.0d0)))
      (when (typep renderer 'mpl.backends:renderer-base)
        (let ((gc (mpl.backends:make-graphics-context
                   :facecolor face-rgba
                   :edgecolor edge-rgba
                   :linewidth 0.8)))
          (mpl.backends:draw-path renderer gc path transform face-rgba))))))

(defun %resolve-legend-color (color alpha)
  "Resolve a color spec to an RGBA list with given alpha."
  (if (and (stringp color) (string= color "none"))
      nil
      (let ((rgba (mpl.colors:to-rgba color)))
        (if (vectorp rgba)
            (list (aref rgba 0) (aref rgba 1) (aref rgba 2)
                  (* (aref rgba 3) (float alpha 1.0d0)))
            (list 1.0d0 1.0d0 1.0d0 (float alpha 1.0d0))))))

(defun %legend-draw-handle-artist (renderer artist x y width height)
  "Draw a legend handle artist at the given position."
  (cond
    ;; Line2D handle
    ((typep artist 'mpl.rendering:line-2d)
     (let* ((color (mpl.rendering:line-2d-color artist))
            (lw (mpl.rendering:line-2d-linewidth artist))
            (linestyle (mpl.rendering:line-2d-linestyle artist))
            (rgba-color (%resolve-legend-color color 1.0d0)))
       (when (and rgba-color (typep renderer 'mpl.backends:renderer-base))
         (let* ((xdata (list x (+ x width)))
                (ydata (list y y))
                (verts (make-array (list 2 2) :element-type 'double-float))
                (_ (progn
                     (setf (aref verts 0 0) (float (first xdata) 1.0d0)
                           (aref verts 0 1) (float (first ydata) 1.0d0)
                           (aref verts 1 0) (float (second xdata) 1.0d0)
                           (aref verts 1 1) (float (second ydata) 1.0d0))))
                (path (mpl.primitives:make-path :vertices verts))
                (transform (mpl.primitives:make-identity-transform))
                (gc (mpl.backends:make-graphics-context
                     :facecolor nil
                     :edgecolor rgba-color
                     :linewidth lw
                     :linestyle (or linestyle :solid))))
           (declare (ignore _))
           (mpl.backends:draw-path renderer gc path transform nil)))))
    ;; Rectangle/Patch handle
    ((typep artist 'mpl.rendering:rectangle)
     (let* ((facecolor (or (mpl.rendering:patch-facecolor artist) "C0"))
            (edgecolor (or (mpl.rendering:patch-edgecolor artist) "black"))
            (face-rgba (%resolve-legend-color facecolor 1.0d0))
      (edge-rgba (%resolve-legend-color edgecolor 1.0d0)))
       (when (typep renderer 'mpl.backends:renderer-base)
         (let* ((path (mpl.primitives:path-unit-rectangle))
                (transform (mpl.primitives:make-affine-2d
                            :scale (list width (* height 0.7d0))
                            :translate (list x (- y (* height 0.35d0)))))
                (gc (mpl.backends:make-graphics-context
                     :facecolor face-rgba
                     :edgecolor edge-rgba
                     :linewidth 0.5)))
           (mpl.backends:draw-path renderer gc path transform face-rgba)))))
    ;; Circle handle (for scatter)
    ((typep artist 'mpl.rendering:circle)
     (let* ((facecolor (or (mpl.rendering:patch-facecolor artist) "C0"))
            (face-rgba (%resolve-legend-color facecolor 1.0d0)))
       (when (typep renderer 'mpl.backends:renderer-base)
         (let* ((center-x (+ x (/ width 2.0d0)))
                (radius (* (min width height) 0.25d0))
                (path (mpl.primitives:path-unit-circle))
                (transform (mpl.primitives:make-affine-2d
                            :scale (list radius radius)
                            :translate (list center-x y)))
                (gc (mpl.backends:make-graphics-context
                     :facecolor face-rgba
                     :edgecolor face-rgba
                     :linewidth 0.5)))
           (mpl.backends:draw-path renderer gc path transform face-rgba)))))
    ;; Generic artist — try draw protocol
    (t
     (when (typep artist 'mpl.rendering:artist)
       (mpl.rendering:draw artist renderer)))))

(defun %legend-draw-text (renderer text x y &key (fontsize 10.0) (weight :normal)
                                                   (color "black"))
  "Draw text at a position using the renderer.
Fontsize is passed through gc-linewidth (matching the backend convention)."
  (declare (ignore weight))
  (when (typep renderer 'mpl.backends:renderer-base)
    (let* ((rgba-color (%resolve-legend-color color 1.0d0))
           (gc (mpl.backends:make-graphics-context
                :facecolor nil
                :edgecolor rgba-color
                :linewidth fontsize)))
      (mpl.backends:draw-text renderer gc
                              (float x 1.0d0) (float y 1.0d0)
                              text nil 0.0))))

;;; ============================================================
;;; Axes.legend() — convenience function
;;; ============================================================

(defun axes-legend (ax &key handles labels (loc :best)
                            (fontsize 10.0) (frameon t)
                            (facecolor "white") (edgecolor "#cccccc")
                            (framealpha 0.8) (title "")
                            (ncol 1) handler-map)
  "Create and add a legend to the axes AX.

If HANDLES and LABELS are not provided, extracts labeled artists from the axes.
LOC specifies the position: :best, :upper-right, :upper-left, :lower-left,
:lower-right, :center, :center-left, :center-right, :upper-center, :lower-center.

Returns the created mpl-legend."
  ;; Auto-collect handles and labels if not provided
  (when (and (null handles) (null labels))
    (multiple-value-bind (h l) (%axes-get-legend-handles-labels ax)
      (setf handles h labels l)))
  ;; If still no handles, return nil
  (when (null handles)
    (return-from axes-legend nil))
  ;; Ensure labels list matches handles length
  (when (< (length labels) (length handles))
    (setf labels (append labels
                         (loop for i from (length labels) below (length handles)
                               collect (format nil "Entry ~D" i)))))
  ;; Create legend
  (let ((legend (make-instance 'mpl-legend
                               :parent ax
                               :handles handles
                               :labels labels
                               :loc loc
                               :fontsize fontsize
                               :frameon frameon
                               :facecolor facecolor
                               :edgecolor edgecolor
                               :framealpha (float framealpha 1.0d0)
                               :title title
                               :ncol ncol
                               :handler-map handler-map
                               :zorder 5)))
    ;; Store in axes
    (setf (axes-base-legend ax) legend)
    ;; Add to axes artists for drawing
    (axes-add-artist ax legend)
    legend))

(defun %axes-get-legend-handles-labels (ax)
  "Extract handles and labels from labeled artists in AX.
Returns (values handles labels) as two lists."
  (let ((handles nil)
        (labels nil))
    ;; Collect from lines (axes-base-lines stores in reverse-add order via push,
    ;; so reverse to get original insertion order matching matplotlib)
    (dolist (line (reverse (axes-base-lines ax)))
      (let ((label (mpl.rendering:artist-label line)))
        (when (and label (stringp label) (plusp (length label))
                   (not (char= (char label 0) #\_)))
          (push line handles)
          (push label labels))))
    ;; Collect from patches (skip background patch)
    (dolist (patch (reverse (axes-base-patches ax)))
      (let ((label (mpl.rendering:artist-label patch)))
        (when (and label (stringp label) (plusp (length label))
                   (not (char= (char label 0) #\_)))
          (push patch handles)
          (push label labels))))
    ;; Collect from extra artists
    (dolist (artist (reverse (axes-base-artists ax)))
      (unless (typep artist 'mpl-legend)
        (let ((label (mpl.rendering:artist-label artist)))
          (when (and label (stringp label) (plusp (length label))
                     (not (char= (char label 0) #\_)))
            (push artist handles)
            (push label labels)))))
    (values (nreverse handles) (nreverse labels))))
