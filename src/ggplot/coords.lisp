;;;; coords.lisp — coordinate systems

(in-package #:ggplot)

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
