;;;; ticker.lisp — Tick locators and formatters
;;;; Ported from matplotlib's ticker.py
;;;; Pure CL implementation — no CFFI.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Helper: scale_range from matplotlib.ticker
;;; ============================================================

(defun %scale-range (vmin vmax &optional (n 1) (threshold 100))
  "Return (values scale offset) for nice tick spacing.
Ported from matplotlib.ticker.scale_range."
  (let* ((dv (abs (- vmax vmin)))
         (meanv (/ (+ vmax vmin) 2.0d0)))
    (when (zerop dv)
      (return-from %scale-range (values 1.0d0 0.0d0)))
    (let ((offset (if (< (/ (abs meanv) dv) threshold)
                      0.0d0
                      (* (signum meanv)
                         (expt 10.0d0 (floor (log (abs meanv) 10.0d0))))))
          (scale (expt 10.0d0 (floor (log (/ dv n) 10.0d0)))))
      (values scale offset))))

;;; ============================================================
;;; Helper: _Edge_integer from matplotlib.ticker
;;; ============================================================

(defun %edge-closeto (ms edge offset step)
  "Check if MS is close to EDGE, accounting for offset precision."
  (let ((tol (if (> offset 0.0d0)
                 (let ((digits (log (/ offset step) 10.0d0)))
                   (min 0.4999d0 (max 1.0d-10 (expt 10.0d0 (- digits 12)))))
                 1.0d-10)))
    (< (abs (- ms edge)) tol)))

(defun %edge-le (x step offset)
  "Return the largest n such that n*step <= x."
  (multiple-value-bind (d m) (floor x step)
    (if (%edge-closeto (/ m step) 1.0d0 offset step)
        (1+ d)
        d)))

(defun %edge-ge (x step offset)
  "Return the smallest n such that n*step >= x."
  (multiple-value-bind (d m) (floor x step)
    (if (%edge-closeto (/ m step) 0.0d0 offset step)
        d
        (1+ d))))

;;; ============================================================
;;; Helper: _nonsingular
;;; ============================================================

(defun %nonsingular (vmin vmax &key (expander 1.0d-13) (tiny 1.0d-14))
  "Ensure vmin != vmax, expanding if necessary.
Ported from matplotlib.transforms._nonsingular."
  (when (not (and (numberp vmin) (numberp vmax)))
    (return-from %nonsingular (values -0.001d0 0.001d0)))
  (let ((maxabsv (max (abs vmin) (abs vmax))))
    (when (or (<= maxabsv tiny)
              (> (/ (- vmax vmin) maxabsv) tiny))
      ;; Not singular
      (return-from %nonsingular (values (float vmin 1.0d0) (float vmax 1.0d0)))))
  ;; vmin == vmax (singular)
  (if (zerop vmin)
      (values (- expander) expander)
      (values (- vmin (* (abs vmin) expander))
              (+ vmax (* (abs vmax) expander)))))

;;; ============================================================
;;; Locator base class
;;; ============================================================

(defclass locator ()
  ((locator-axis :initarg :axis
                 :initform nil
                 :accessor locator-axis
                 :documentation "The axis this locator is attached to."))
  (:documentation "Base class for tick locators.
Ported from matplotlib.ticker.Locator."))

(defgeneric locator-tick-values (locator vmin vmax)
  (:documentation "Return a list of tick locations between VMIN and VMAX."))

(defgeneric locator-call (locator)
  (:documentation "Return tick locations for the current axis view."))

(defmethod locator-call ((loc locator))
  "Default: get view interval from axis and call tick-values."
  (let* ((axis (locator-axis loc))
         (vmin 0.0d0)
         (vmax 1.0d0))
    (when axis
      (multiple-value-setq (vmin vmax) (axis-get-view-interval axis)))
    (locator-tick-values loc vmin vmax)))

;;; ============================================================
;;; NullLocator — no ticks
;;; ============================================================

(defclass null-locator (locator)
  ()
  (:documentation "Place no ticks. Ported from matplotlib.ticker.NullLocator."))

(defmethod locator-tick-values ((loc null-locator) vmin vmax)
  (declare (ignore vmin vmax))
  nil)

;;; ============================================================
;;; FixedLocator — ticks at specified locations
;;; ============================================================

(defclass fixed-locator (locator)
  ((locs :initarg :locs
         :accessor fixed-locator-locs
         :documentation "List of tick locations.")
   (nbins :initarg :nbins
          :initform nil
          :accessor fixed-locator-nbins
          :documentation "Max number of bins (nil = all ticks)."))
  (:documentation "Place ticks at a set of fixed values.
Ported from matplotlib.ticker.FixedLocator."))

(defmethod locator-tick-values ((loc fixed-locator) vmin vmax)
  (declare (ignore vmin vmax))
  (let ((locs (fixed-locator-locs loc))
        (nbins (fixed-locator-nbins loc)))
    (if (or (null nbins) (null locs))
        (copy-list locs)
        ;; Subsample to at most nbins ticks
        (let* ((n (length locs))
               (step (max 1 (ceiling n nbins))))
          (loop for i from 0 below n by step
                collect (nth i locs))))))

;;; ============================================================
;;; LinearLocator — N evenly spaced ticks
;;; ============================================================

(defclass linear-locator (locator)
  ((numticks :initarg :numticks
             :initform 11
             :accessor linear-locator-numticks
             :documentation "Number of ticks to place."))
  (:documentation "Place ticks at evenly spaced values.
Ported from matplotlib.ticker.LinearLocator."))

(defmethod locator-tick-values ((loc linear-locator) vmin vmax)
  (let* ((vmin (float vmin 1.0d0))
         (vmax (float vmax 1.0d0))
         (n (linear-locator-numticks loc)))
    (multiple-value-setq (vmin vmax) (%nonsingular vmin vmax))
    (if (<= n 1)
        (list vmin)
        (let ((step (/ (- vmax vmin) (1- n))))
          (loop for i from 0 below n
                collect (+ vmin (* i step)))))))

;;; ============================================================
;;; MultipleLocator — ticks at multiples of base
;;; ============================================================

(defclass multiple-locator (locator)
  ((base :initarg :base
         :initform 1.0d0
         :accessor multiple-locator-base
         :type double-float
         :documentation "Interval between ticks.")
   (offset :initarg :offset
           :initform 0.0d0
           :accessor multiple-locator-offset
           :type double-float
           :documentation "Offset added to each multiple."))
  (:documentation "Place ticks at every integer multiple of base.
Ported from matplotlib.ticker.MultipleLocator."))

(defmethod locator-tick-values ((loc multiple-locator) vmin vmax)
  (let* ((step (float (multiple-locator-base loc) 1.0d0))
         (off (float (multiple-locator-offset loc) 1.0d0))
         (vmin (float vmin 1.0d0))
         (vmax (float vmax 1.0d0)))
    (when (< vmax vmin)
      (rotatef vmin vmax))
    (let* ((adj-vmin (- vmin off))
           (adj-vmax (- vmax off))
           (start (* (%edge-ge adj-vmin step (abs off)) step))
           (n (floor (+ (- adj-vmax start) (* 0.001d0 step)) step)))
      (loop for i from -1 to (1+ n)
            collect (+ (- start step) (* i step) off)))))

;;; ============================================================
;;; MaxNLocator — nice ticks with max N bins
;;; ============================================================

(defclass max-n-locator (locator)
  ((nbins :initarg :nbins
          :initform 10
          :accessor max-n-locator-nbins
          :documentation "Max number of intervals.")
   (steps :initarg :steps
          :initform nil
          :accessor max-n-locator-steps
          :documentation "Sequence of acceptable tick multiples.")
   (integer-p :initarg :integer
              :initform nil
              :accessor max-n-locator-integer-p
              :type boolean
              :documentation "If T, ticks are only at integer values.")
   (symmetric-p :initarg :symmetric
                :initform nil
                :accessor max-n-locator-symmetric-p
                :type boolean
                :documentation "If T, range is symmetric about zero.")
   (prune :initarg :prune
          :initform nil
          :accessor max-n-locator-prune
          :documentation "Remove :lower, :upper, or :both edge ticks.")
   (min-n-ticks :initarg :min-n-ticks
                :initform 2
                :accessor max-n-locator-min-n-ticks
                :documentation "Minimum number of ticks."))
  (:documentation "Place evenly spaced ticks with a max number of ticks.
Ported from matplotlib.ticker.MaxNLocator."))

(defmethod initialize-instance :after ((loc max-n-locator) &key)
  "Set default steps if not provided."
  (unless (max-n-locator-steps loc)
    (setf (max-n-locator-steps loc)
          '(1.0d0 1.5d0 2.0d0 2.5d0 3.0d0 4.0d0 5.0d0 6.0d0 8.0d0 10.0d0))))

(defun %max-n-locator-extended-steps (steps)
  "Create an extended staircase from STEPS.
Matches matplotlib's _staircase method."
  (let ((result nil))
    ;; 0.1 * steps[:-1]
    (loop for s in (butlast steps)
          do (push (* 0.1d0 s) result))
    ;; steps
    (dolist (s steps) (push s result))
    ;; 10 * steps[1]
    (when (cdr steps)
      (push (* 10.0d0 (second steps)) result))
    (sort (nreverse result) #'<)))

(defun %axis-tick-space (axis)
  "Compute the tick space (number of ticks that fit) based on axis pixel length.
Matches matplotlib's Axis.get_tick_space():
  X-axis: pixel_length / (fontsize * 4)
  Y-axis: pixel_length / (fontsize * 2.5)
where fontsize defaults to 10pt."
  (when axis
    (let ((ax (axis-axes axis)))
      (when ax
        (let* ((fig (axes-base-figure ax))
               (pos (axes-base-position ax)))
          (when (and fig pos)
            (let ((fig-w-px (float (figure-width-px fig) 1.0d0))
                  (fig-h-px (float (figure-height-px fig) 1.0d0))
                  (ax-width-frac (third pos))
                  (ax-height-frac (fourth pos))
                  (fontsize 10.0d0))
              (if (typep axis 'x-axis)
                  ;; X axis: width / (fontsize * 4) — ~40px per tick
                  (max 1 (floor (* ax-width-frac fig-w-px) (* fontsize 4.0d0)))
                  ;; Y axis: height / (fontsize * 2.5) — ~25px per tick
                  (max 1 (floor (* ax-height-frac fig-h-px) (* fontsize 2.5d0)))))))))))

(defun %auto-nbins (loc)
  "Compute auto nbins, matching matplotlib's behavior for nbins='auto'."
  (let* ((axis (locator-axis loc))
         (tick-space (%axis-tick-space axis))
         (min-n-ticks (max-n-locator-min-n-ticks loc)))
    (if tick-space
        (max (1- min-n-ticks) (min tick-space 9))
        9)))

(defun %max-n-locator-raw-ticks (loc vmin vmax)
  "Generate raw tick locations spanning vmin to vmax.
Ported from MaxNLocator._raw_ticks."
  (let* ((nbins (max-n-locator-nbins loc))
         (nbins (if (eq nbins :auto) (%auto-nbins loc) nbins))
         (steps (max-n-locator-steps loc))
         (extended-steps (%max-n-locator-extended-steps steps))
         (min-n-ticks (max 1 (max-n-locator-min-n-ticks loc))))
    (multiple-value-bind (scale offset) (%scale-range vmin vmax nbins)
      (let* ((_vmin (- vmin offset))
             (_vmax (- vmax offset))
             (scaled-steps (mapcar (lambda (s) (* s scale)) extended-steps))
             (raw-step (/ (- _vmax _vmin) nbins))
             ;; Find steps >= raw-step
             (large-steps (remove-if (lambda (s) (< s raw-step)) scaled-steps))
             ;; Find the smallest large step
             (best-step (if large-steps
                            (reduce #'min large-steps)
                            (car (last scaled-steps)))))
        ;; Try from the smallest adequate step backwards
        (let ((candidates (sort (remove-if (lambda (s) (> s best-step)) scaled-steps) #'>)))
          (dolist (step (or candidates (list best-step)))
            (let* ((best-vmin (* (floor _vmin step) step))
                   (low (%edge-le (- _vmin best-vmin) step (abs offset)))
                   (high (%edge-ge (- _vmax best-vmin) step (abs offset)))
                   (ticks (loop for i from low to high
                                collect (+ (* i step) best-vmin offset)))
                   (nticks (count-if (lambda (t-val)
                                       (and (<= _vmin (- t-val offset))
                                            (>= _vmax (- t-val offset))))
                                     ticks)))
              (when (>= nticks min-n-ticks)
                (return-from %max-n-locator-raw-ticks ticks))))
          ;; Fallback: use best-step
          (let* ((step best-step)
                 (best-vmin (* (floor _vmin step) step))
                 (low (%edge-le (- _vmin best-vmin) step (abs offset)))
                 (high (%edge-ge (- _vmax best-vmin) step (abs offset))))
            (loop for i from low to high
                  collect (+ (* i step) best-vmin offset))))))))

(defmethod locator-tick-values ((loc max-n-locator) vmin vmax)
  (let ((vmin (float vmin 1.0d0))
        (vmax (float vmax 1.0d0)))
    (when (max-n-locator-symmetric-p loc)
      (let ((absmax (max (abs vmin) (abs vmax))))
        (setf vmin (- absmax) vmax absmax)))
    (multiple-value-setq (vmin vmax) (%nonsingular vmin vmax))
    (let ((locs (%max-n-locator-raw-ticks loc vmin vmax))
          (prune (max-n-locator-prune loc)))
      (cond
        ((eq prune :lower)
         (setf locs (cdr locs)))
        ((eq prune :upper)
         (setf locs (butlast locs)))
        ((eq prune :both)
         (setf locs (butlast (cdr locs)))))
      locs)))

;;; ============================================================
;;; AutoLocator — MaxNLocator with nice defaults
;;; ============================================================

(defclass auto-locator (max-n-locator)
  ()
  (:default-initargs :nbins :auto :steps '(1.0d0 2.0d0 2.5d0 5.0d0 10.0d0))
  (:documentation "Place ticks automatically at nice locations.
Ported from matplotlib.ticker.AutoLocator."))

;;; ============================================================
;;; LogLocator — logarithmic ticks
;;; ============================================================

(defclass log-locator (locator)
  ((base :initarg :base
         :initform 10.0d0
         :accessor log-locator-base
         :type double-float
         :documentation "Base of the logarithm.")
   (subs :initarg :subs
         :initform '(1.0d0)
         :accessor log-locator-subs
         :documentation "List of tick multipliers within each decade.")
   (numticks :initarg :numticks
             :initform nil
             :accessor log-locator-numticks
             :documentation "Max number of ticks. nil = auto."))
  (:documentation "Place ticks on a logarithmic scale.
Ported from matplotlib.ticker.LogLocator."))

(defmethod locator-tick-values ((loc log-locator) vmin vmax)
  (let* ((base (float (log-locator-base loc) 1.0d0))
         (subs (log-locator-subs loc))
         (vmin (max (float vmin 1.0d0) 1.0d-300))
         (vmax (max (float vmax 1.0d0) 1.0d-300)))
    (when (< vmax vmin) (rotatef vmin vmax))
    (let* ((log-vmin (floor (log vmin base)))
           (log-vmax (ceiling (log vmax base)))
           (ticks nil))
      ;; Generate ticks: subs[j] * base^i
      (loop for i from (1- log-vmin) to (1+ log-vmax) do
        (dolist (s subs)
          (let ((tick (* s (expt base (float i 1.0d0)))))
            (when (and (>= tick (* vmin 0.999d0))
                       (<= tick (* vmax 1.001d0)))
              (push tick ticks)))))
      (sort (nreverse ticks) #'<))))

;;; ============================================================
;;; Formatter base class
;;; ============================================================

(defclass tick-formatter ()
  ((tick-formatter-axis :initarg :axis
                        :initform nil
                        :accessor tick-formatter-axis
                        :documentation "The axis this formatter is attached to."))
  (:documentation "Base class for tick formatters.
Ported from matplotlib.ticker.Formatter."))

(defgeneric tick-formatter-call (tick-formatter value &optional pos)
  (:documentation "Return a formatted string for VALUE at position POS."))

(defgeneric tick-formatter-format-ticks (tick-formatter values)
  (:documentation "Format a list of tick VALUES, returning a list of strings."))

(defmethod tick-formatter-format-ticks ((fmt tick-formatter) values)
  "Default: call tick-formatter on each value."
  (loop for v in values
        for pos from 0
        collect (tick-formatter-call fmt v pos)))

;;; ============================================================
;;; NullFormatter — no labels
;;; ============================================================

(defclass null-formatter (tick-formatter)
  ()
  (:documentation "Always return empty string. Ported from matplotlib.ticker.NullFormatter."))

(defmethod tick-formatter-call ((fmt null-formatter) value &optional pos)
  (declare (ignore value pos))
  "")

;;; ============================================================
;;; FixedFormatter — use fixed list of strings
;;; ============================================================

(defclass fixed-formatter (tick-formatter)
  ((seq :initarg :seq
        :accessor fixed-formatter-seq
        :documentation "Sequence of fixed strings for labels."))
  (:documentation "Return fixed strings for tick labels based on position.
Ported from matplotlib.ticker.FixedFormatter."))

(defmethod tick-formatter-call ((fmt fixed-formatter) value &optional pos)
  (declare (ignore value))
  (let ((seq (fixed-formatter-seq fmt)))
    (if (and pos (< pos (length seq)))
        (nth pos seq)
        "")))

;;; ============================================================
;;; ScalarFormatter — format numbers with appropriate precision
;;; ============================================================

(defclass scalar-formatter (tick-formatter)
  ((use-offset-p :initarg :use-offset
                 :initform nil
                 :accessor scalar-formatter-use-offset-p
                 :type boolean
                 :documentation "Whether to use offset notation.")
   (scientific-p :initarg :scientific
                 :initform t
                 :accessor scalar-formatter-scientific-p
                 :type boolean
                 :documentation "Whether to use scientific notation.")
   (power-limits :initarg :power-limits
                 :initform '(-4 5)
                 :accessor scalar-formatter-power-limits
                 :documentation "Exponent range for switching to sci notation.")
   (order-of-magnitude :initform 0
                       :accessor scalar-formatter-order-of-magnitude
                       :documentation "Computed order of magnitude for formatting.")
   (format-str :initform "~G"
               :accessor scalar-formatter-format-str
               :documentation "Format string for output.")
   (offset :initform 0.0d0
           :accessor scalar-formatter-offset
           :type double-float))
  (:documentation "Format tick values as numbers with appropriate precision.
Ported from matplotlib.ticker.ScalarFormatter."))

(defun %scalar-format-value (value &optional (order-of-magnitude 0))
  "Format a scalar value to a clean string.
Handles appropriate decimal places based on magnitude."
  (let ((adjusted (if (zerop order-of-magnitude)
                      value
                      (/ value (expt 10.0d0 order-of-magnitude)))))
    ;; Determine how many decimals to use
    (cond
      ;; Zero
      ((zerop adjusted) "0")
      ;; Integer-like values
      ((and (< (abs (- adjusted (round adjusted))) 1.0d-9)
            (< (abs adjusted) 1.0d15))
       (format nil "~D" (round adjusted)))
      ;; Small values — more decimals
      ((< (abs adjusted) 0.01d0)
       (let ((str (format nil "~,6F" adjusted)))
         (%trim-trailing-zeros str)))
      ((< (abs adjusted) 1.0d0)
       (let ((str (format nil "~,4F" adjusted)))
         (%trim-trailing-zeros str)))
      ((< (abs adjusted) 100.0d0)
       (let ((str (format nil "~,2F" adjusted)))
         (%trim-trailing-zeros str)))
      ((< (abs adjusted) 10000.0d0)
       (let ((str (format nil "~,1F" adjusted)))
         (%trim-trailing-zeros str)))
      (t
       (format nil "~D" (round adjusted))))))

(defun %trim-trailing-zeros (str)
  "Trim trailing zeros from a decimal string, but keep at least one digit after dot."
  (let ((dot-pos (position #\. str)))
    (if (null dot-pos)
        str
        (let ((end (length str)))
          ;; Find last non-zero
          (loop while (and (> end (+ dot-pos 2))
                          (char= (char str (1- end)) #\0))
                do (decf end))
          (subseq str 0 end)))))

(defmethod tick-formatter-call ((fmt scalar-formatter) value &optional pos)
  (declare (ignore pos))
  (%scalar-format-value (float value 1.0d0)
                        (scalar-formatter-order-of-magnitude fmt)))

(defmethod tick-formatter-format-ticks ((fmt scalar-formatter) values)
  "Format a list of tick values with consistent decimal places.
Matches matplotlib's ScalarFormatter._set_format: uses loc_range to compute
initial sigfigs, then refines by checking if rounding loses precision."
  (when (null values)
    (return-from tick-formatter-format-ticks nil))
  (let* ((vals (mapcar (lambda (v) (float v 1.0d0)) values))
         (oom (scalar-formatter-order-of-magnitude fmt))
         ;; Adjust values by order of magnitude
         (locs (mapcar (lambda (v) (if (zerop oom) v (/ v (expt 10.0d0 oom)))) vals))
         ;; Compute loc_range (peak-to-peak of adjusted locs)
         (loc-min (reduce #'min locs))
         (loc-max (reduce #'max locs))
         (loc-range (- loc-max loc-min))
         (loc-range (if (zerop loc-range)
                        (let ((m (reduce #'max (mapcar #'abs locs))))
                          (if (zerop m) 1.0d0 m))
                        loc-range))
         ;; matplotlib: loc_range_oom = floor(log10(loc_range))
         (loc-range-oom (floor (log loc-range 10.0d0)))
         ;; First estimate: sigfigs = max(0, 3 - loc_range_oom)
         (sigfigs (max 0 (- 3 loc-range-oom)))
         ;; Threshold for refinement
         (thresh (* 1.0d-3 (expt 10.0d0 loc-range-oom))))
    ;; Refine: reduce sigfigs while rounding doesn't lose precision
    (loop while (>= sigfigs 0)
          do (let* ((factor (expt 10.0d0 sigfigs))
                    (rounded (mapcar (lambda (v) (/ (fround (* v factor)) factor)) locs))
                    (max-diff (reduce #'max (mapcar (lambda (a b) (abs (- a b)))
                                                    locs rounded))))
               (if (< max-diff thresh)
                   (decf sigfigs)
                   (return))))
    (incf sigfigs)
    (setf sigfigs (max 0 sigfigs))
    ;; Format all values with consistent decimal places
    (loop for v in locs
          collect (if (zerop sigfigs)
                      (format nil "~D" (round v))
                      (format nil (format nil "~~,~DF" sigfigs) v)))))

;;; ============================================================
;;; StrMethodFormatter — format using format string
;;; ============================================================

(defclass str-method-formatter (tick-formatter)
  ((fmt-string :initarg :fmt
               :accessor str-method-formatter-fmt
               :documentation "CL format string for tick values."))
  (:documentation "Format tick values using a CL format string.
Ported from matplotlib.ticker.StrMethodFormatter."))

(defmethod tick-formatter-call ((fmt str-method-formatter) value &optional pos)
  (declare (ignore pos))
  (format nil (str-method-formatter-fmt fmt) (float value 1.0d0)))

;;; ============================================================
;;; LogFormatter — format for log scale
;;; ============================================================

(defclass log-formatter (tick-formatter)
  ((base :initarg :base
         :initform 10.0d0
         :accessor log-formatter-base
         :type double-float
         :documentation "Base of the logarithm.")
   (label-only-base-p :initarg :label-only-base
                      :initform nil
                      :accessor log-formatter-label-only-base-p
                      :type boolean
                      :documentation "If T, only label integer powers of base."))
  (:documentation "Format values for log axes.
Ported from matplotlib.ticker.LogFormatter."))

(defmethod tick-formatter-call ((fmt log-formatter) value &optional pos)
  (declare (ignore pos))
  (let ((base (log-formatter-base fmt)))
    (if (<= value 0.0d0)
        ""
        (let* ((exp (log (float value 1.0d0) base))
               (is-decade (< (abs (- exp (round exp))) 0.001d0)))
          (if (and (log-formatter-label-only-base-p fmt)
                   (not is-decade))
              ""
              (if is-decade
                  (let ((iexp (round exp)))
                    (if (= base 10.0d0)
                        (format nil "10^~D" iexp)
                        (format nil "~G^~D" base iexp)))
                  (%scalar-format-value value)))))))

;;; ============================================================
;;; PercentFormatter — format as percentages
;;; ============================================================

(defclass percent-formatter (tick-formatter)
  ((xmax :initarg :xmax
         :initform 100.0d0
         :accessor percent-formatter-xmax
         :type double-float
         :documentation "Data value that corresponds to 100%.")
   (decimals :initarg :decimals
             :initform nil
             :accessor percent-formatter-decimals
             :documentation "Number of decimal places (nil = auto).")
   (symbol :initarg :symbol
           :initform "%"
           :accessor percent-formatter-symbol
           :documentation "String appended to label."))
  (:documentation "Format numbers as percentages.
Ported from matplotlib.ticker.PercentFormatter."))

(defmethod tick-formatter-call ((fmt percent-formatter) value &optional pos)
  (declare (ignore pos))
  (let* ((xmax (percent-formatter-xmax fmt))
         (pct (* 100.0d0 (/ (float value 1.0d0) xmax)))
         (decimals (percent-formatter-decimals fmt))
         (sym (or (percent-formatter-symbol fmt) "")))
    (if decimals
        (format nil "~,vF~A" decimals pct sym)
        ;; Auto decimals based on range
        (let ((auto-dec (cond
                          ((> (abs pct) 50.0d0) 0)
                          ((> (abs pct) 5.0d0) 1)
                          ((> (abs pct) 0.5d0) 2)
                          (t 3))))
          (format nil "~,vF~A" auto-dec pct sym)))))
