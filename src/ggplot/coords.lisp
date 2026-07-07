;;;; coords.lisp — coordinate systems: the coord protocol plus
;;;; cartesian, flip, fixed, trans, and polar implementations.
;;;;
;;;; Protocol defaults preserve cartesian behavior exactly; coord-flip
;;;; keeps its SSIM-calibrated build-time column swap and is simply
;;;; routed through the protocol.

(in-package #:ggplot)

;;; ============================================================
;;; Protocol
;;; ============================================================

(defgeneric coord-transform-table (coord table plot)
  (:documentation "Build-time table rewrite (flip's column swap, trans's
position transform). Default: TABLE unchanged.")
  (:method ((coord coord) table plot)
    (declare (ignore plot))
    table))

(defgeneric coord-flipped-p (coord)
  (:documentation "T when x/y roles are swapped (labels, panel params).")
  (:method ((coord coord)) nil))

(defgeneric coord-transform-points (coord xs ys panel)
  (:documentation "Draw-time point map for non-cartesian coords (polar).
XS/YS are lists in scale units; PANEL carries panel params. Returns
(values xs ys). Default: identity.")
  (:method ((coord coord) xs ys panel)
    (declare (ignore panel))
    (values xs ys)))

(defgeneric coord-munch-p (coord)
  (:documentation "T when straight segments must be interpolated into
many short ones before coord-transform-points (polar wedges).")
  (:method ((coord coord)) nil))

(defgeneric coord-aspect (coord panel)
  (:documentation "Required panel aspect ratio, or NIL for free.
coord-fixed returns its ratio; coord-polar returns 1.")
  (:method ((coord coord) panel)
    (declare (ignore panel))
    nil))

(defgeneric coord-uses-axes-frame-p (coord)
  (:documentation "NIL when the coord draws its own grid/axis furniture
(polar) instead of the rectangular panel frame and ticks.")
  (:method ((coord coord)) t))

(defgeneric coord-draw-grid (coord panel axes theme)
  (:documentation "Draw coord-specific grid/axis furniture (polar's
circles, rays, and circular labels). Only called when
coord-uses-axes-frame-p is NIL.")
  (:method ((coord coord) panel axes theme)
    (declare (ignore panel axes theme))
    nil))

(defgeneric coord-adjust-breaks (coord breaks which)
  (:documentation "Map break POSITIONS for coord-trans (labels keep the
original values). WHICH is :x or :y. Default: unchanged.")
  (:method ((coord coord) breaks which)
    (declare (ignore which))
    breaks))

;;; ============================================================
;;; Cartesian and flip
;;; ============================================================

(defclass coord-cartesian-obj (coord)
  ((xlim :initarg :xlim :initform nil :reader coord-xlim)
   (ylim :initarg :ylim :initform nil :reader coord-ylim)))

(defun coord-cartesian (&key xlim ylim)
  "The default coordinate system. :xlim/:ylim zoom the view without
dropping data (unlike scale limits)."
  (make-instance 'coord-cartesian-obj :xlim xlim :ylim ylim))

(defclass coord-flip-obj (coord-cartesian-obj) ())

(defun coord-flip (&key xlim ylim)
  "Flip the axes: x becomes vertical, y horizontal. Resolved at build time
by swapping aesthetic columns, so every geom works flipped for free."
  (make-instance 'coord-flip-obj :xlim xlim :ylim ylim))

(defparameter *flip-pairs*
  '((:x . :y) (:xmin . :ymin) (:xmax . :ymax) (:xend . :yend)
    (:xintercept . :yintercept))
  "Column pairs swapped by coord-flip.")

(defun %flip-table (table)
  "Swap x-family and y-family columns."
  (%make-gtable
   (mapcar (lambda (c)
             (let* ((name (car c))
                    (pair (or (cdr (assoc name *flip-pairs*))
                              (car (rassoc name *flip-pairs*)))))
               (if pair (cons pair (cdr c)) c)))
           (gtable-columns table))
   (gtable-nrows table)))

(defmethod coord-flipped-p ((coord coord-flip-obj)) t)

(defmethod coord-transform-table ((coord coord-flip-obj) table plot)
  (declare (ignore plot))
  (%flip-table table))

;;; ============================================================
;;; coord-fixed
;;; ============================================================

(defclass coord-fixed-obj (coord-cartesian-obj)
  ((ratio :initarg :ratio :initform 1.0d0 :reader coord-fixed-ratio)))

(defun coord-fixed (&key (ratio 1.0d0) xlim ylim)
  "Fixed aspect: RATIO data units of y render the same length as one
data unit of x (ggplot2 coord_fixed / coord_equal at ratio 1)."
  (make-instance 'coord-fixed-obj :ratio (float ratio 1.0d0)
                                  :xlim xlim :ylim ylim))

(defun coord-equal (&key xlim ylim)
  (coord-fixed :ratio 1.0d0 :xlim xlim :ylim ylim))

(defmethod coord-aspect ((coord coord-fixed-obj) panel)
  (declare (ignore panel))
  (coord-fixed-ratio coord))

;;; ============================================================
;;; coord-trans
;;; ============================================================

(defclass coord-trans-obj (coord)
  ((x-trans :initarg :x :initform nil :reader coord-trans-x)
   (y-trans :initarg :y :initform nil :reader coord-trans-y))
  (:documentation "Transform positions AFTER stats (unlike scale
transforms which apply before): breaks are computed on the original
scale, positioned transformed, labeled with the original values."))

(defun coord-trans (&key x y)
  "Post-stat coordinate transform: :x/:y name a transform (:log10,
:sqrt, :reverse)."
  (make-instance 'coord-trans-obj :x x :y y))

(defun %trans-fn (name)
  (ecase name
    ((nil) nil)
    (:log10 (lambda (v) (log (max v 1d-300) 10d0)))
    (:sqrt (lambda (v) (sqrt (max v 0d0))))
    (:reverse (lambda (v) (- v)))))

(defmethod coord-transform-table ((coord coord-trans-obj) table plot)
  (declare (ignore plot))
  (let ((fx (%trans-fn (coord-trans-x coord)))
        (fy (%trans-fn (coord-trans-y coord)))
        (result table))
    (flet ((apply-to (fn aesthetics)
             (dolist (aes aesthetics)
               (let ((col (gtable-column result aes)))
                 (when col
                   (setf result
                         (gtable-set-column
                          result aes
                          (map 'simple-vector
                               (lambda (v) (funcall fn (float v 1d0)))
                               col))))))))
      (when fx (apply-to fx '(:x :xmin :xmax :xend :xintercept)))
      (when fy (apply-to fy '(:y :ymin :ymax :yend :yintercept
                              :lower :middle :upper))))
    result))

(defmethod coord-adjust-breaks ((coord coord-trans-obj) breaks which)
  (let ((fn (%trans-fn (ecase which
                         (:x (coord-trans-x coord))
                         (:y (coord-trans-y coord))))))
    (if fn (mapcar fn breaks) breaks)))

;;; ============================================================
;;; coord-polar
;;; ============================================================

(defclass coord-polar-obj (coord)
  ((theta :initarg :theta :initform :x :reader coord-polar-theta
          :documentation ":x (angle from x, rose charts) or :y (angle
from y, pie charts).")
   (start :initarg :start :initform 0.0d0 :reader coord-polar-start
          :documentation "Angle offset from 12 o'clock, radians.")
   (direction :initarg :direction :initform 1
              :reader coord-polar-direction
              :documentation "1 clockwise, -1 anticlockwise.")))

(defun coord-polar (&key (theta :x) (start 0.0d0) (direction 1))
  "Polar coordinates (plotnine coord_polar): bar + :theta :y = pie."
  (make-instance 'coord-polar-obj :theta theta
                                  :start (float start 1.0d0)
                                  :direction direction))

(defmethod coord-munch-p ((coord coord-polar-obj)) t)
(defmethod coord-uses-axes-frame-p ((coord coord-polar-obj)) nil)
(defmethod coord-aspect ((coord coord-polar-obj) panel)
  (declare (ignore panel))
  1.0d0)

(defun %polar-theta-r (coord x y panel)
  "Normalized (theta radians from 12 o'clock, r in [0,1]) for
scale-space X Y. Uses the RAW (unexpanded) ranges so the circle closes
over the data extent, like ggplot2."
  (let* ((theta-x-p (eq (coord-polar-theta coord) :x))
         (t-range (or (getf panel (if theta-x-p :x-raw-range :y-raw-range))
                      (getf panel (if theta-x-p :x-range :y-range))))
         (r-range (or (getf panel (if theta-x-p :y-raw-range :x-raw-range))
                      (getf panel (if theta-x-p :y-range :x-range))))
         (tv (if theta-x-p x y))
         (rv (if theta-x-p y x))
         (theta (+ (coord-polar-start coord)
                   (* (coord-polar-direction coord) 2.0d0 pi
                      (/ (- tv (first t-range))
                         (max (- (second t-range) (first t-range))
                              1d-12)))))
         (r (/ (- rv (first r-range))
               (max (- (second r-range) (first r-range)) 1d-12))))
    (values theta r)))

(defmethod coord-transform-points ((coord coord-polar-obj) xs ys panel)
  "Map scale-space points into the [-1.05, 1.05]^2 polar panel: theta
measured from 12 o'clock, r in [0, 1]."
  (let ((out-x '()) (out-y '()))
    (loop for x in xs
          for y in ys
          do (multiple-value-bind (theta r)
                 (%polar-theta-r coord (float x 1d0) (float y 1d0) panel)
               (push (* r (sin theta)) out-x)
               (push (* r (cos theta)) out-y)))
    (values (nreverse out-x) (nreverse out-y))))

(defun %munch-segments (xs ys &key (n 20))
  "Interpolate N points into each straight segment so the polar
transform bends it (ggplot2's munching)."
  (if (< (length xs) 2)
      (values xs ys)
      (let ((out-x '()) (out-y '()))
        (loop for (x0 x1) on (coerce xs 'list)
              for (y0 y1) on (coerce ys 'list)
              while x1
              do (dotimes (k n)
                   (let ((f (/ (float k 1d0) n)))
                     (push (+ x0 (* f (- x1 x0))) out-x)
                     (push (+ y0 (* f (- y1 y0))) out-y))))
        (push (car (last (coerce xs 'list))) out-x)
        (push (car (last (coerce ys 'list))) out-y)
        (values (nreverse out-x) (nreverse out-y)))))

(defmethod coord-draw-grid ((coord coord-polar-obj) panel axes theme)
  "Polar furniture: r-break circles, theta rays and labels around r=1."
  (let* ((grid-el (theme-element theme :panel-grid-major))
         (grid-color (or (and (element-line-p grid-el)
                              (element-line-color grid-el))
                         "white"))
         (grid-lw (or (and (element-line-p grid-el)
                           (element-line-linewidth grid-el))
                      1.0d0))
         (theta-x-p (eq (coord-polar-theta coord) :x))
         (t-breaks (getf panel (if theta-x-p :x-breaks :y-breaks)))
         (t-labels (getf panel (if theta-x-p :x-labels :y-labels)))
         (r-breaks (getf panel (if theta-x-p :y-breaks :x-breaks)))
         (t-range (or (getf panel (if theta-x-p :x-raw-range :y-raw-range))
                      (getf panel (if theta-x-p :x-range :y-range))))
         (r-range (or (getf panel (if theta-x-p :y-raw-range :x-raw-range))
                      (getf panel (if theta-x-p :y-range :x-range)))))
    (flet ((draw-line (xs ys)
             (cl-matplotlib.containers:plot
              axes xs ys :color grid-color :linewidth grid-lw :zorder 1))
           (theta-of (tv)
             (+ (coord-polar-start coord)
                (* (coord-polar-direction coord) 2.0d0 pi
                   (/ (- tv (first t-range))
                      (max (- (second t-range) (first t-range)) 1d-12)))))
           (r-of (rv)
             (/ (- rv (first r-range))
                (max (- (second r-range) (first r-range)) 1d-12))))
      ;; r circles at r breaks (plus the outer boundary)
      (dolist (r (append (mapcar #'r-of r-breaks) (list 1.0d0)))
        (when (and (> r 0.02d0) (<= r 1.001d0))
          (let ((xs '()) (ys '()))
            (dotimes (k 121)
              (let ((a (* 2.0d0 pi (/ k 120.0d0))))
                (push (* r (sin a)) xs)
                (push (* r (cos a)) ys)))
            (draw-line xs ys))))
      ;; theta rays + labels just outside r = 1
      (loop for tb in t-breaks
            for label in t-labels
            for theta = (theta-of tb)
            do (draw-line (list 0.0d0 (sin theta))
                          (list 0.0d0 (cos theta)))
               (cl-matplotlib.containers:text
                axes (* 1.12d0 (sin theta)) (* 1.12d0 (cos theta))
                label
                :fontsize 8.8d0 :color "#4D4D4D"
                :ha :center :va :center)))))
