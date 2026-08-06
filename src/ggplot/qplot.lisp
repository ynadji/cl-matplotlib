;;;; qplot.lisp — quick plots

(in-package #:ggplot)

(defun %sequence-arg-p (v)
  (and (typep v 'sequence) (not (stringp v)) (not (keywordp v))))

(defun qplot (x &optional y &key data (geom :auto) xlab ylab main log
                                 color fill size shape alpha
                                 &allow-other-keys)
  "plotnine-style quick plot.

With :data, X/Y are column references; without it they are sequences:
  (qplot xs ys)                          ; scatter of two sequences
  (qplot :wt :mpg :data df :color :cyl)  ; column refs + mapped color
GEOM: :auto (point when y, histogram otherwise), or any geom keyword.
LOG: \"x\", \"y\", or \"xy\" for log10 scales."
  (let* ((inline-data-p (and (null data) (%sequence-arg-p x)))
         (data (cond (inline-data-p
                      (if y
                          (list :x (coerce x 'vector) :y (coerce y 'vector))
                          (list :x (coerce x 'vector))))
                     (t data)))
         (x-ref (if inline-data-p :x x))
         (y-ref (cond (inline-data-p (and y :y))
                      (t y)))
         (mapping-plist
           (append (list :x x-ref)
                   (when y-ref (list :y y-ref))
                   ;; keywords name columns -> mapped; other values fixed
                   (when (keywordp color) (list :color color))
                   (when (keywordp fill) (list :fill fill))
                   (when (keywordp size) (list :size size))
                   (when (keywordp shape) (list :shape shape))))
         (fixed (append (when (and color (not (keywordp color)))
                          (list :color color))
                        (when (and fill (not (keywordp fill)))
                          (list :fill fill))
                        (when (and size (not (keywordp size)))
                          (list :size size))
                        (when (and alpha (not (keywordp alpha)))
                          (list :alpha alpha))))
         (geom (if (eq geom :auto)
                   (if y-ref :point :histogram)
                   geom))
         (layer (apply (ecase geom
                         (:point #'geom-point)
                         (:line #'geom-line)
                         (:histogram #'geom-histogram)
                         (:bar #'geom-bar)
                         (:col #'geom-col)
                         (:boxplot #'geom-boxplot)
                         (:violin #'geom-violin)
                         (:density #'geom-density)
                         (:area #'geom-area)
                         (:tile #'geom-tile)
                         (:smooth #'geom-smooth))
                       fixed)))
    (stack (ggplot data (apply #'aes mapping-plist))
      layer
      (when (and log (find #\x log)) (scale-x-log10))
      (when (and log (find #\y log)) (scale-y-log10))
      (when xlab (gg:xlab xlab))
      (when ylab (gg:ylab ylab))
      (when main (ggtitle main)))))

(defun expand-limits (&key x y)
  "Widen scale training to include the given value(s):
(expand-limits :y 0) makes sure zero is on the y axis."
  (let ((xs (and x (if (listp x) x (list x))))
        (ys (and y (if (listp y) y (list y)))))
    (geom-blank :data (append
                       (when xs (list :x (coerce (mapcar (lambda (v) (float v 1.0d0)) xs) 'vector)))
                       (when ys (list :y (coerce (mapcar (lambda (v) (float v 1.0d0)) ys) 'vector))))
                :mapping (apply #'aes (append (when xs '(:x :x))
                                              (when ys '(:y :y)))))))
