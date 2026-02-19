;;;; fancy-arrow.lisp — FancyArrowPatch, ConnectionStyle, BoxStyle, AnchoredText
;;;; Ported from matplotlib's patches.py (FancyArrowPatch, ConnectionStyle, BoxStyle)
;;;; and offsetbox.py (AnchoredText)
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; ConnectionStyle — defines the path between two points
;;; ============================================================

(defclass connection-style ()
  ()
  (:documentation "Base class for connection styles.
Defines how to connect two points with a path.
Ported from matplotlib.patches.ConnectionStyle."))

(defgeneric connect (style posA posB)
  (:documentation "Return an mpl-path connecting posA to posB.
posA and posB are each a list (x y)."))

;;; --- Arc3 connection (Bézier curve) ---

(defclass arc3-connection (connection-style)
  ((rad :initarg :rad :initform 0.0d0 :accessor arc3-rad :type double-float
        :documentation "Curvature of the arc. 0 = straight, positive = curved."))
  (:documentation "Arc3 connection: a simple quadratic Bézier curve.
Curvature controlled by rad parameter."))

(defmethod connect ((style arc3-connection) posA posB)
  "Connect posA to posB with a quadratic Bézier curve."
  (let* ((ax (float (first posA) 1.0d0))
         (ay (float (second posA) 1.0d0))
         (bx (float (first posB) 1.0d0))
         (by (float (second posB) 1.0d0))
         (rad (arc3-rad style))
         ;; Midpoint
         (mx (* 0.5d0 (+ ax bx)))
         (my (* 0.5d0 (+ ay by)))
         ;; Perpendicular direction
         (dx (- bx ax))
         (dy (- by ay))
         ;; Control point offset perpendicular to line
         (cx (- mx (* rad dy)))
         (cy (+ my (* rad dx))))
    (if (< (abs rad) 1.0d-10)
        ;; Straight line
        (mpl.primitives:make-path
         :vertices (list (list ax ay) (list bx by))
         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+))
        ;; Quadratic Bézier via cubic approximation
        ;; Convert quadratic control point to two cubic control points
        (let ((c1x (+ ax (* 2/3 (- cx ax))))
              (c1y (+ ay (* 2/3 (- cy ay))))
              (c2x (+ bx (* 2/3 (- cx bx))))
              (c2y (+ by (* 2/3 (- cy by)))))
          (mpl.primitives:make-path
           :vertices (list (list ax ay)
                           (list c1x c1y)
                           (list c2x c2y)
                           (list bx by))
           :codes (list mpl.primitives:+moveto+
                        mpl.primitives:+curve4+
                        mpl.primitives:+curve4+
                        mpl.primitives:+curve4+))))))

;;; --- Angle3 connection (three segments) ---

(defclass angle3-connection (connection-style)
  ((angleA :initarg :angleA :initform 90.0d0 :accessor angle3-angleA :type double-float
           :documentation "Angle of first segment in degrees.")
   (angleB :initarg :angleB :initform 0.0d0 :accessor angle3-angleB :type double-float
           :documentation "Angle of last segment in degrees."))
  (:documentation "Angle3 connection: two angled line segments with a connecting segment."))

(defmethod connect ((style angle3-connection) posA posB)
  "Connect posA to posB with angled segments."
  (let* ((ax (float (first posA) 1.0d0))
         (ay (float (second posA) 1.0d0))
         (bx (float (first posB) 1.0d0))
         (by (float (second posB) 1.0d0))
         (angA-rad (* (angle3-angleA style) (/ pi 180.0d0)))
         (angB-rad (* (angle3-angleB style) (/ pi 180.0d0)))
         ;; Direction vectors
         (dax (cos angA-rad))
         (day (sin angA-rad))
         (dbx (cos angB-rad))
         (dby (sin angB-rad))
         ;; Compute intersection point
         ;; Line A: (ax + t*dax, ay + t*day)
         ;; Line B: (bx + s*dbx, by + s*dby)
         ;; Solve: ax + t*dax = bx + s*dbx, ay + t*day = by + s*dby
         (det (- (* dax dby) (* day dbx))))
    (if (< (abs det) 1.0d-10)
        ;; Nearly parallel — just use straight line
        (mpl.primitives:make-path
         :vertices (list (list ax ay) (list bx by))
         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+))
        (let* ((t-val (/ (- (* (- bx ax) dby) (* (- by ay) dbx)) det))
               (ix (+ ax (* t-val dax)))
               (iy (+ ay (* t-val day))))
          (mpl.primitives:make-path
           :vertices (list (list ax ay) (list ix iy) (list bx by))
           :codes (list mpl.primitives:+moveto+
                        mpl.primitives:+lineto+
                        mpl.primitives:+lineto+))))))

;;; --- Angle connection (simple two-segment) ---

(defclass angle-connection (connection-style)
  ((angleA :initarg :angleA :initform 90.0d0 :accessor angle-angleA :type double-float
           :documentation "Angle of first segment in degrees."))
  (:documentation "Angle connection: two segments at angleA."))

(defmethod connect ((style angle-connection) posA posB)
  "Connect posA to posB with two perpendicular segments."
  (declare (ignore style))
  (let* ((ax (float (first posA) 1.0d0))
         (ay (float (second posA) 1.0d0))
         (bx (float (first posB) 1.0d0))
         (by (float (second posB) 1.0d0)))
    ;; For simplified angle connection: go up from A to B's y, then go right to B
    (let ((corner-x ax)
          (corner-y by))
      (mpl.primitives:make-path
       :vertices (list (list ax ay) (list corner-x corner-y) (list bx by))
       :codes (list mpl.primitives:+moveto+
                    mpl.primitives:+lineto+
                    mpl.primitives:+lineto+)))))

;;; ============================================================
;;; Connection style factory
;;; ============================================================

(defun make-connection-style (style &rest args)
  "Create a connection style from a keyword or string.
STYLE can be :arc3, :angle3, :angle, or a string \"arc3\", etc."
  (let ((style-key (etypecase style
                     (keyword style)
                     (string (intern (string-upcase style) :keyword)))))
    (ecase style-key
      (:arc3 (apply #'make-instance 'arc3-connection args))
      (:angle3 (apply #'make-instance 'angle3-connection args))
      (:angle (apply #'make-instance 'angle-connection args)))))

;;; ============================================================
;;; Arrow style helpers — generate arrow head/tail paths
;;; ============================================================

(defun %arrow-head-path (tip-x tip-y dx dy head-length head-width)
  "Generate a triangle arrow head at (tip-x, tip-y) pointing in direction (dx, dy).
Returns a list of (x y) vertices forming a closed triangle."
  (let* ((len (sqrt (+ (* dx dx) (* dy dy))))
         (ux (if (> len 0) (/ dx len) 0.0d0))
         (uy (if (> len 0) (/ dy len) 0.0d0))
         ;; Perpendicular direction
         (px (- uy))
         (py ux)
         ;; Base of arrowhead
         (base-x (- tip-x (* head-length ux)))
         (base-y (- tip-y (* head-length uy)))
         ;; Half-width offsets
         (hw (* 0.5d0 head-width))
         (left-x (+ base-x (* hw px)))
         (left-y (+ base-y (* hw py)))
         (right-x (- base-x (* hw px)))
         (right-y (- base-y (* hw py))))
    (list (list tip-x tip-y) (list left-x left-y)
          (list right-x right-y) (list tip-x tip-y))))

(defun %compute-arrow-path (posA posB arrowstyle connection-path
                            &key (mutation-scale 1.0d0) (shrinkA 0.0d0) (shrinkB 0.0d0))
  "Compute the final arrow path given positions, style, and connection.
Returns (values shaft-path head-path) or just shaft-path for styles without heads."
  (let* ((ax (float (first posA) 1.0d0))
         (ay (float (second posA) 1.0d0))
         (bx (float (first posB) 1.0d0))
         (by (float (second posB) 1.0d0))
         ;; Apply shrink
         (dx (- bx ax))
         (dy (- by ay))
         (total-len (sqrt (+ (* dx dx) (* dy dy))))
         (ux (if (> total-len 0) (/ dx total-len) 0.0d0))
         (uy (if (> total-len 0) (/ dy total-len) 0.0d0))
         ;; Shrink from ends
         (shrink-a-pts (float shrinkA 1.0d0))
         (shrink-b-pts (float shrinkB 1.0d0))
         (sa-x (+ ax (* shrink-a-pts ux)))
         (sa-y (+ ay (* shrink-a-pts uy)))
         (sb-x (- bx (* shrink-b-pts ux)))
         (sb-y (- by (* shrink-b-pts uy)))
         ;; Head dimensions scaled by mutation-scale
         (head-length (* 10.0d0 mutation-scale))
         (head-width (* 8.0d0 mutation-scale))
         (style-key (etypecase arrowstyle
                      (keyword arrowstyle)
                      (string (intern (string-upcase arrowstyle) :keyword)))))
    (declare (ignore connection-path))
    (cond
      ;; -> : line with arrow head at end
      ((eq style-key :->)
       (let* ((head-verts (%arrow-head-path sb-x sb-y (- dx) (- dy) head-length head-width))
              (head-path (mpl.primitives:make-path
                          :vertices head-verts
                          :closed t))
              (shaft-path (mpl.primitives:make-path
                           :vertices (list (list sa-x sa-y) (list sb-x sb-y))
                           :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
         (values shaft-path head-path)))
      ;; <- : line with arrow head at start
      ((eq style-key :<-)
       (let* ((head-verts (%arrow-head-path sa-x sa-y dx dy head-length head-width))
              (head-path (mpl.primitives:make-path
                          :vertices head-verts
                          :closed t))
              (shaft-path (mpl.primitives:make-path
                           :vertices (list (list sa-x sa-y) (list sb-x sb-y))
                           :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
         (values shaft-path head-path)))
      ;; <-> : double-headed arrow
      ((eq style-key :<->)
       (let* ((head-b-verts (%arrow-head-path sb-x sb-y (- dx) (- dy) head-length head-width))
              (head-a-verts (%arrow-head-path sa-x sa-y dx dy head-length head-width))
              (head-b-path (mpl.primitives:make-path :vertices head-b-verts :closed t))
              (head-a-path (mpl.primitives:make-path :vertices head-a-verts :closed t))
              (shaft-path (mpl.primitives:make-path
                           :vertices (list (list sa-x sa-y) (list sb-x sb-y))
                           :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
              (both-heads (mpl.primitives:path-make-compound-path
                           (list head-a-path head-b-path))))
         (values shaft-path both-heads)))
      ;; - : line only, no heads
      ((eq style-key :-)
       (values (mpl.primitives:make-path
                :vertices (list (list sa-x sa-y) (list sb-x sb-y))
                :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+))
               nil))
      ;; -bracket : line with bracket at end
      ((eq style-key :-bracket)
       (let* ((bracket-len (* 5.0d0 mutation-scale))
              (px (- uy)) (py ux)
              (left-x (+ sb-x (* bracket-len px)))
              (left-y (+ sb-y (* bracket-len py)))
              (right-x (- sb-x (* bracket-len px)))
              (right-y (- sb-y (* bracket-len py)))
              (bracket-path (mpl.primitives:make-path
                             :vertices (list (list left-x left-y)
                                             (list sb-x sb-y)
                                             (list right-x right-y))
                             :codes (list mpl.primitives:+moveto+
                                          mpl.primitives:+lineto+
                                          mpl.primitives:+lineto+)))
              (shaft-path (mpl.primitives:make-path
                           :vertices (list (list sa-x sa-y) (list sb-x sb-y))
                           :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+))))
         (values shaft-path bracket-path)))
      ;; bar-bar : line with perpendicular bars at both ends
      ((eq style-key :-bar-bar)
       (let* ((bar-len (* 5.0d0 mutation-scale))
              (px (- uy)) (py ux)
              (bar-a (mpl.primitives:make-path
                      :vertices (list (list (+ sa-x (* bar-len px))
                                            (+ sa-y (* bar-len py)))
                                      (list (- sa-x (* bar-len px))
                                            (- sa-y (* bar-len py))))
                      :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
              (bar-b (mpl.primitives:make-path
                      :vertices (list (list (+ sb-x (* bar-len px))
                                            (+ sb-y (* bar-len py)))
                                      (list (- sb-x (* bar-len px))
                                            (- sb-y (* bar-len py))))
                      :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
              (shaft-path (mpl.primitives:make-path
                           :vertices (list (list sa-x sa-y) (list sb-x sb-y))
                           :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
              (both-bars (mpl.primitives:path-make-compound-path (list bar-a bar-b))))
         (values shaft-path both-bars)))
      ;; simple : filled triangular arrow
      ((eq style-key :simple)
       (let* ((hw (* 0.5d0 head-width))
              (px (- uy)) (py ux)
              (verts (list (list (+ sa-x (* hw 0.3d0 px)) (+ sa-y (* hw 0.3d0 py)))
                           (list (- sa-x (* hw 0.3d0 px)) (- sa-y (* hw 0.3d0 py)))
                           (list (- sb-x (* hw px)) (- sb-y (* hw py)))
                           (list sb-x sb-y)
                           (list (+ sb-x (* hw px)) (+ sb-y (* hw py)))
                           (list (+ sa-x (* hw 0.3d0 px)) (+ sa-y (* hw 0.3d0 py))))))
         (values (mpl.primitives:make-path :vertices verts :closed t) nil)))
      ;; fancy : curved fancy arrow
      ((eq style-key :fancy)
       (let* ((hw (* 0.5d0 head-width))
              (px (- uy)) (py ux)
              (verts (list (list sa-x sa-y)
                           (list (- sb-x (* hw 1.5d0 px)) (- sb-y (* hw 1.5d0 py)))
                           (list sb-x sb-y)
                           (list (+ sb-x (* hw 1.5d0 px)) (+ sb-y (* hw 1.5d0 py)))
                           (list sa-x sa-y))))
         (values (mpl.primitives:make-path :vertices verts :closed t) nil)))
      ;; wedge : wedge-shaped arrow
      ((eq style-key :wedge)
       (let* ((px (- uy)) (py ux)
              (tail-hw (* 0.5d0 mutation-scale))
              (head-hw (* head-width 0.5d0))
              (verts (list (list (+ sa-x (* tail-hw px)) (+ sa-y (* tail-hw py)))
                           (list (- sa-x (* tail-hw px)) (- sa-y (* tail-hw py)))
                           (list (- sb-x (* head-hw px)) (- sb-y (* head-hw py)))
                           (list sb-x sb-y)
                           (list (+ sb-x (* head-hw px)) (+ sb-y (* head-hw py)))
                           (list (+ sa-x (* tail-hw px)) (+ sa-y (* tail-hw py))))))
         (values (mpl.primitives:make-path :vertices verts :closed t) nil)))
      ;; Unknown style: fall back to simple line
      (t (values (mpl.primitives:make-path
                  :vertices (list (list sa-x sa-y) (list sb-x sb-y))
                  :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+))
                 nil)))))

;;; ============================================================
;;; FancyArrowPatch — styled arrow between two points
;;; ============================================================

(defclass fancy-arrow-patch (patch)
  ((posA :initarg :posA :initform nil :accessor fancy-arrow-posA
         :documentation "Start point (x y) of the arrow.")
   (posB :initarg :posB :initform nil :accessor fancy-arrow-posB
         :documentation "End point (x y) of the arrow.")
   (arrow-path :initarg :path :initform nil :accessor fancy-arrow-path-original
               :documentation "Optional explicit path for the arrow.")
   (arrowstyle :initarg :arrowstyle :initform :-> :accessor fancy-arrow-arrowstyle
               :documentation "Arrow style: :-> :- :<-> :<- :-[ :|-| :simple :fancy :wedge")
   (connectionstyle :initarg :connectionstyle :initform nil
                    :accessor fancy-arrow-connectionstyle
                    :documentation "ConnectionStyle instance or keyword.")
   (shrinkA :initarg :shrinkA :initform 2.0d0 :accessor fancy-arrow-shrinkA :type double-float
            :documentation "Shrink distance at start in points.")
   (shrinkB :initarg :shrinkB :initform 2.0d0 :accessor fancy-arrow-shrinkB :type double-float
            :documentation "Shrink distance at end in points.")
   (mutation-scale :initarg :mutation-scale :initform 1.0d0
                   :accessor fancy-arrow-mutation-scale :type double-float
                   :documentation "Scale factor for arrow style parameters.")
   (patchA :initarg :patchA :initform nil :accessor fancy-arrow-patchA
           :documentation "Optional patch at start for clipping.")
   (patchB :initarg :patchB :initform nil :accessor fancy-arrow-patchB
           :documentation "Optional patch at end for clipping.")
    (cached-path :initform nil :accessor fancy-arrow-cached-path))
  (:default-initargs :capstyle :round :joinstyle :round :zorder 2)
  (:documentation "A fancy arrow patch that draws an arrow using ArrowStyle.
Ported from matplotlib.patches.FancyArrowPatch."))

(defmethod initialize-instance :after ((fa fancy-arrow-patch) &key)
  "Initialize the FancyArrowPatch. Set up connection style."
  ;; Ensure connectionstyle is an instance
  (when (and (fancy-arrow-posA fa) (fancy-arrow-posB fa))
    (let ((cs (fancy-arrow-connectionstyle fa)))
      (when (or (null cs) (keywordp cs) (stringp cs))
        (setf (fancy-arrow-connectionstyle fa)
              (make-connection-style (or cs :arc3)))))))

(defmethod get-path ((fa fancy-arrow-patch))
  "Return the compound arrow path (shaft + head)."
  (or (fancy-arrow-cached-path fa)
      (progn (%recompute-arrow-path fa)
             (fancy-arrow-cached-path fa))))

(defun %recompute-arrow-path (fa)
  "Recompute the arrow path from positions and style."
  (cond
    ;; Explicit path provided
    ((fancy-arrow-path-original fa)
     (setf (fancy-arrow-cached-path fa) (fancy-arrow-path-original fa)))
    ;; posA/posB provided
    ((and (fancy-arrow-posA fa) (fancy-arrow-posB fa))
     (let* ((posA (fancy-arrow-posA fa))
            (posB (fancy-arrow-posB fa))
            (cs (fancy-arrow-connectionstyle fa))
            (conn-path (when cs (connect cs posA posB))))
       (multiple-value-bind (shaft-path head-path)
           (%compute-arrow-path posA posB
                                (fancy-arrow-arrowstyle fa)
                                conn-path
                                :mutation-scale (fancy-arrow-mutation-scale fa)
                                :shrinkA (fancy-arrow-shrinkA fa)
                                :shrinkB (fancy-arrow-shrinkB fa))
         (if head-path
             (setf (fancy-arrow-cached-path fa)
                   (mpl.primitives:path-make-compound-path (list shaft-path head-path)))
             (setf (fancy-arrow-cached-path fa) shaft-path)))))
    ;; Fallback: empty path
    (t (setf (fancy-arrow-cached-path fa)
             (mpl.primitives:make-path :vertices '())))))

(defmethod draw ((fa fancy-arrow-patch) renderer)
  "Draw the fancy arrow."
  (unless (artist-visible fa)
    (return-from draw))
  ;; Recompute path
  (setf (fancy-arrow-cached-path fa) nil)
  (%recompute-arrow-path fa)
  (let* ((path (fancy-arrow-cached-path fa))
         (transform (get-artist-transform fa))
         (arrowstyle (fancy-arrow-arrowstyle fa))
         (style-key (etypecase arrowstyle
                      (keyword arrowstyle)
                      (string (intern (string-upcase arrowstyle) :keyword))))
         ;; Only single-shape styles (:simple :fancy :wedge) should fill
         ;; the entire compound path. Arrow styles (:-> :<- :<->) draw
         ;; shaft + head as stroke-only to avoid filling the enclosed area.
         (filled-p (member style-key '(:simple :fancy :wedge)))
         (gc (make-gc :foreground (or (patch-edgecolor fa) "black")
                      :linewidth (patch-linewidth fa)
                      :linestyle (patch-linestyle fa)
                      :alpha (or (artist-alpha fa) 1.0)
                      :antialiased (patch-antialiased fa)
                      :capstyle (patch-capstyle fa)
                      :joinstyle (patch-joinstyle fa))))
    (when path
      (renderer-draw-path renderer gc path transform
                          :fill (when filled-p
                                  (or (patch-facecolor fa) (patch-edgecolor fa) "black"))
                          :stroke (patch-edgecolor fa))))
  (setf (artist-stale fa) nil))

;;; ============================================================
;;; BoxStyle — defines fancy box shapes
;;; ============================================================

(defclass box-style ()
  ()
  (:documentation "Base class for box styles.
Ported from matplotlib.patches.BoxStyle."))

(defgeneric box-transmute (style x y width height)
  (:documentation "Return an mpl-path for the box shape."))

;;; --- Square box ---

(defclass square-box (box-style)
  ((pad :initarg :pad :initform 0.3d0 :accessor square-box-pad :type double-float))
  (:documentation "Simple square (rectangular) box."))

(defmethod box-transmute ((style square-box) x y width height)
  (let ((p (square-box-pad style)))
    (mpl.primitives:make-path
     :vertices (list (list (- x p) (- y p))
                     (list (+ x width p) (- y p))
                     (list (+ x width p) (+ y height p))
                     (list (- x p) (+ y height p))
                     (list (- x p) (- y p)))
     :closed t)))

;;; --- Round box ---

(defclass round-box (box-style)
  ((pad :initarg :pad :initform 0.3d0 :accessor round-box-pad :type double-float)
   (rounding-size :initarg :rounding-size :initform nil :accessor round-box-rounding-size
                  :documentation "Corner radius, or nil to auto-compute."))
  (:documentation "Box with rounded corners."))

(defmethod box-transmute ((style round-box) x y width height)
  (let* ((p (round-box-pad style))
         (r (or (round-box-rounding-size style)
                (min (* 0.2d0 (min (+ width (* 2 p)) (+ height (* 2 p)))) 0.3d0)))
         (x0 (- x p)) (y0 (- y p))
         (x1 (+ x width p)) (y1 (+ y height p)))
    ;; Simplified: use straight lines (full rounded corners would need Bézier)
    ;; Approximate round corners with small straight segments
    (mpl.primitives:make-path
     :vertices (list (list (+ x0 r) y0)
                     (list (- x1 r) y0)
                     (list x1 (+ y0 r))
                     (list x1 (- y1 r))
                     (list (- x1 r) y1)
                     (list (+ x0 r) y1)
                     (list x0 (- y1 r))
                     (list x0 (+ y0 r))
                     (list (+ x0 r) y0))
     :closed t)))

;;; --- Round4 box ---

(defclass round4-box (box-style)
  ((pad :initarg :pad :initform 0.3d0 :accessor round4-box-pad :type double-float)
   (rounding-size :initarg :rounding-size :initform nil :accessor round4-box-rounding-size))
  (:documentation "Box with independently rounded corners."))

(defmethod box-transmute ((style round4-box) x y width height)
  ;; Same as round-box for simplified implementation
  (let* ((p (round4-box-pad style))
         (r (or (round4-box-rounding-size style) 0.15d0))
         (x0 (- x p)) (y0 (- y p))
         (x1 (+ x width p)) (y1 (+ y height p)))
    (mpl.primitives:make-path
     :vertices (list (list (+ x0 r) y0)
                     (list (- x1 r) y0)
                     (list x1 (+ y0 r))
                     (list x1 (- y1 r))
                     (list (- x1 r) y1)
                     (list (+ x0 r) y1)
                     (list x0 (- y1 r))
                     (list x0 (+ y0 r))
                     (list (+ x0 r) y0))
     :closed t)))

;;; --- Sawtooth box ---

(defclass sawtooth-box (box-style)
  ((pad :initarg :pad :initform 0.3d0 :accessor sawtooth-box-pad :type double-float)
   (tooth-size :initarg :tooth-size :initform nil :accessor sawtooth-box-tooth-size))
  (:documentation "Box with sawtooth edges."))

(defmethod box-transmute ((style sawtooth-box) x y width height)
  ;; Simplified: just use a rectangle (sawtooth pattern is cosmetic)
  (let ((p (sawtooth-box-pad style)))
    (mpl.primitives:make-path
     :vertices (list (list (- x p) (- y p))
                     (list (+ x width p) (- y p))
                     (list (+ x width p) (+ y height p))
                     (list (- x p) (+ y height p))
                     (list (- x p) (- y p)))
     :closed t)))

;;; --- Roundtooth box ---

(defclass roundtooth-box (box-style)
  ((pad :initarg :pad :initform 0.3d0 :accessor roundtooth-box-pad :type double-float)
   (tooth-size :initarg :tooth-size :initform nil :accessor roundtooth-box-tooth-size))
  (:documentation "Box with rounded tooth edges."))

(defmethod box-transmute ((style roundtooth-box) x y width height)
  ;; Simplified: just use a rectangle
  (let ((p (roundtooth-box-pad style)))
    (mpl.primitives:make-path
     :vertices (list (list (- x p) (- y p))
                     (list (+ x width p) (- y p))
                     (list (+ x width p) (+ y height p))
                     (list (- x p) (+ y height p))
                     (list (- x p) (- y p)))
     :closed t)))

;;; ============================================================
;;; BoxStyle factory
;;; ============================================================

(defun make-box-style (style &rest args)
  "Create a box style instance from a keyword."
  (let ((style-key (etypecase style
                     (keyword style)
                     (string (intern (string-upcase style) :keyword)))))
    (ecase style-key
      (:square (apply #'make-instance 'square-box args))
      (:round (apply #'make-instance 'round-box args))
      (:round4 (apply #'make-instance 'round4-box args))
      (:sawtooth (apply #'make-instance 'sawtooth-box args))
      (:roundtooth (apply #'make-instance 'roundtooth-box args)))))

;;; ============================================================
;;; AnchoredText — text box anchored to axes corner
;;; ============================================================

(defclass anchored-text (artist)
  ((text-content :initarg :text :initform "" :accessor anchored-text-text :type string
                 :documentation "The text content.")
   (loc :initarg :loc :initform :upper-right :accessor anchored-text-loc
        :documentation "Anchor location: :upper-left, :upper-right, :lower-left, :lower-right, :center.")
   (pad :initarg :pad :initform 0.4d0 :accessor anchored-text-pad :type double-float
        :documentation "Padding around text as fraction of fontsize.")
   (borderpad :initarg :borderpad :initform 0.5d0 :accessor anchored-text-borderpad :type double-float
              :documentation "Spacing between box frame and bbox_to_anchor.")
   (frameon :initarg :frameon :initform t :accessor anchored-text-frameon :type boolean
            :documentation "Whether to draw the frame.")
   (fontsize :initarg :fontsize :initform 12.0 :accessor anchored-text-fontsize :type real
             :documentation "Font size in points.")
   (color :initarg :color :initform "black" :accessor anchored-text-color
          :documentation "Text color.")
   (facecolor :initarg :facecolor :initform "white" :accessor anchored-text-facecolor
              :documentation "Background color.")
   (edgecolor :initarg :edgecolor :initform "black" :accessor anchored-text-edgecolor
              :documentation "Border color."))
  (:default-initargs :zorder 5)
  (:documentation "An anchored text box positioned at a corner of the axes.
Ported from matplotlib.offsetbox.AnchoredText."))

(defun %anchored-text-position (loc pad)
  "Return (x-frac y-frac) in axes fraction coordinates for LOC.
PAD is the offset from edge in axes fraction."
  (ecase loc
    (:upper-left   (list pad (- 1.0d0 pad)))
    (:upper-right  (list (- 1.0d0 pad) (- 1.0d0 pad)))
    (:lower-left   (list pad pad))
    (:lower-right  (list (- 1.0d0 pad) pad))
    (:center       (list 0.5d0 0.5d0))
    (:center-left  (list pad 0.5d0))
    (:center-right (list (- 1.0d0 pad) 0.5d0))
    (:upper-center (list 0.5d0 (- 1.0d0 pad)))
    (:lower-center (list 0.5d0 pad))))

(defmethod draw ((at anchored-text) renderer)
  "Draw the anchored text box."
  (unless (artist-visible at)
    (return-from draw))
  (when (zerop (length (anchored-text-text at)))
    (return-from draw))
  (let* ((borderpad (float (anchored-text-borderpad at) 1.0d0))
         (pos (%anchored-text-position (anchored-text-loc at) borderpad))
         (x (float (first pos) 1.0d0))
         (y (float (second pos) 1.0d0))
         (gc (make-gc :foreground (anchored-text-color at)
                      :alpha (or (artist-alpha at) 1.0)
                      :linewidth (anchored-text-fontsize at))))
    ;; Draw background box if frameon
    (when (anchored-text-frameon at)
      (let* ((fs (float (anchored-text-fontsize at) 1.0d0))
             ;; Estimate text width (rough: ~0.6 * fontsize * nchars)
             (text-width (* 0.6d0 fs (length (anchored-text-text at))))
             (text-height (* 1.2d0 fs))
             (pad-pts (* (float (anchored-text-pad at) 1.0d0) fs))
             (box-x (- x pad-pts))
             (box-y (- y pad-pts))
             (box-w (+ text-width (* 2 pad-pts)))
             (box-h (+ text-height (* 2 pad-pts)))
             (box-path (mpl.primitives:make-path
                        :vertices (list (list box-x box-y)
                                        (list (+ box-x box-w) box-y)
                                        (list (+ box-x box-w) (+ box-y box-h))
                                        (list box-x (+ box-y box-h))
                                        (list box-x box-y))
                        :closed t))
             (box-gc (make-gc :foreground (anchored-text-edgecolor at)
                              :linewidth 1.0
                              :alpha (or (artist-alpha at) 1.0))))
        (renderer-draw-path renderer box-gc box-path nil
                            :fill (anchored-text-facecolor at)
                            :stroke (anchored-text-edgecolor at))))
    ;; Draw text
    (renderer-draw-text renderer gc x y (anchored-text-text at) :angle 0.0))
  (setf (artist-stale at) nil))
