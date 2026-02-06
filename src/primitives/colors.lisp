;;;; colors.lisp — Colormap and Normalize classes for cl-matplotlib
;;;; Ported from matplotlib.colors
;;;;
;;;; Pipeline: data → Normalize → [0,1] → Colormap → RGBA

(in-package #:cl-matplotlib.primitives)

;;; ============================================================
;;; Utility: to-hex, to-rgb (extend the existing to-rgba)
;;; ============================================================

(defun to-hex (color &key keep-alpha)
  "Convert COLOR to a hex string \"#rrggbb\" or \"#rrggbbaa\"."
  (let ((rgba (cl-matplotlib.colors:to-rgba color)))
    (string-downcase
     (if keep-alpha
         (format nil "#~2,'0x~2,'0x~2,'0x~2,'0x"
                 (round (* (aref rgba 0) 255))
                 (round (* (aref rgba 1) 255))
                 (round (* (aref rgba 2) 255))
                 (round (* (aref rgba 3) 255)))
         (format nil "#~2,'0x~2,'0x~2,'0x"
                 (round (* (aref rgba 0) 255))
                 (round (* (aref rgba 1) 255))
                 (round (* (aref rgba 2) 255)))))))

(defun to-rgb (color)
  "Convert COLOR to an RGB vector #(R G B)."
  (let ((rgba (cl-matplotlib.colors:to-rgba color)))
    (vector (aref rgba 0) (aref rgba 1) (aref rgba 2))))

;;; ============================================================
;;; Lookup table creation (from segmentdata)
;;; ============================================================

(defun %create-lookup-table (n data &optional (gamma 1.0))
  "Create an N-element 1D lookup table from segment DATA.
DATA is a list of (x y0 y1) tuples defining a piecewise-linear mapping.
Returns a simple-vector of N double-floats."
  (cond
    ;; Callable data (function)
    ((functionp data)
     (let ((result (make-array n :element-type 'double-float :initial-element 0.0d0)))
       (dotimes (i n result)
         (let* ((frac (if (= n 1) 1.0d0 (/ (float i 1.0d0) (float (1- n) 1.0d0))))
                (x (expt frac (float gamma 1.0d0)))
                (val (float (funcall data x) 1.0d0)))
           (setf (aref result i) (max 0.0d0 (min 1.0d0 val)))))))
    ;; Segment data: list of (x y0 y1) tuples
    (t
     (let* ((adata (coerce data 'vector))
            (m (length adata)))
       (when (< m 2)
         (error "Segment data must have at least 2 rows"))
       ;; Extract columns
       (let ((xs (make-array m :element-type 'double-float))
             (y0s (make-array m :element-type 'double-float))
             (y1s (make-array m :element-type 'double-float)))
         (dotimes (i m)
           (let ((row (aref adata i)))
             (setf (aref xs i) (float (if (listp row) (first row) (aref row 0)) 1.0d0))
             (setf (aref y0s i) (float (if (listp row) (second row) (aref row 1)) 1.0d0))
             (setf (aref y1s i) (float (if (listp row) (third row) (aref row 2)) 1.0d0))))
         ;; Validate
         (unless (and (= (aref xs 0) 0.0d0) (= (aref xs (1- m)) 1.0d0))
           (error "Segment data must start with x=0 and end with x=1"))
         ;; Generate LUT
         (if (= n 1)
             ;; Convention: use y0 at x=1 for 1-element LUT
             (let ((result (make-array 1 :element-type 'double-float)))
               (setf (aref result 0) (aref y0s (1- m)))
               result)
             ;; General case
             (let ((result (make-array n :element-type 'double-float :initial-element 0.0d0)))
               ;; Scale x values by (N-1)
               (let ((scaled-xs (make-array m :element-type 'double-float)))
                 (dotimes (i m) (setf (aref scaled-xs i) (* (aref xs i) (float (1- n) 1.0d0))))
                 ;; First element
                 (setf (aref result 0) (aref y1s 0))
                 ;; Last element
                 (setf (aref result (1- n)) (aref y0s (1- m)))
                 ;; Interior elements
                 (let ((seg-idx 1))  ; current segment index (starts at 1)
                   (loop for i from 1 below (1- n)
                         for xind = (* (float (1- n) 1.0d0)
                                       (expt (/ (float i 1.0d0) (float (1- n) 1.0d0))
                                              (float gamma 1.0d0)))
                         do
                            ;; Advance segment index
                            (loop while (and (< seg-idx m) (<= (aref scaled-xs seg-idx) xind))
                                  do (incf seg-idx))
                            (when (>= seg-idx m) (setf seg-idx (1- m)))
                            ;; Interpolate
                            (let* ((x-left (aref scaled-xs (1- seg-idx)))
                                   (x-right (aref scaled-xs seg-idx))
                                   (dist (if (= x-right x-left) 0.0d0
                                             (/ (- xind x-left) (- x-right x-left))))
                                   (val (+ (aref y1s (1- seg-idx))
                                           (* dist (- (aref y0s seg-idx) (aref y1s (1- seg-idx)))))))
                              (setf (aref result i) (max 0.0d0 (min 1.0d0 val)))))))
               result)))))))

;;; ============================================================
;;; Colormap base class
;;; ============================================================

(defclass colormap ()
  ((name :initarg :name :accessor colormap-name :type string)
   (n :initarg :n :initform 256 :accessor colormap-n :type fixnum
      :documentation "Number of RGB quantization levels")
   (lut :accessor colormap-lut :initform nil
        :documentation "Lookup table: (N+3) x 4 array of RGBA doubles")
   (rgba-bad :initarg :bad :initform #(0.0d0 0.0d0 0.0d0 0.0d0)
             :accessor colormap-rgba-bad)
   (rgba-under :initarg :under :initform nil :accessor colormap-rgba-under)
   (rgba-over :initarg :over :initform nil :accessor colormap-rgba-over)
   (initialized-p :initform nil :accessor colormap-initialized-p))
  (:documentation "Base class for scalar to RGBA mappings."))

(defgeneric colormap-init (colormap)
  (:documentation "Generate the lookup table for this colormap."))

(defun %ensure-colormap-inited (cmap)
  "Ensure colormap LUT is initialized."
  (unless (colormap-initialized-p cmap)
    (colormap-init cmap)))

(defun %update-lut-extremes (cmap)
  "Set under/over/bad entries in the LUT."
  (let* ((n (colormap-n cmap))
         (lut (colormap-lut cmap))
         (i-under n)
         (i-over (1+ n))
         (i-bad (+ n 2)))
    ;; Under: use provided or first color
    (let ((under-rgba (or (colormap-rgba-under cmap)
                          (%lut-row lut 0))))
      (%set-lut-row lut i-under under-rgba))
    ;; Over: use provided or last color
    (let ((over-rgba (or (colormap-rgba-over cmap)
                         (%lut-row lut (1- n)))))
      (%set-lut-row lut i-over over-rgba))
    ;; Bad
    (%set-lut-row lut i-bad (colormap-rgba-bad cmap))))

(defun %make-lut (n)
  "Create an (N+3) x 4 LUT array initialized to ones."
  (make-array (list (+ n 3) 4) :element-type 'double-float :initial-element 1.0d0))

(defun %lut-row (lut row)
  "Extract row ROW from LUT as a 4-element vector."
  (vector (aref lut row 0) (aref lut row 1) (aref lut row 2) (aref lut row 3)))

(defun %set-lut-row (lut row rgba)
  "Set row ROW of LUT from an RGBA vector."
  (setf (aref lut row 0) (float (if (vectorp rgba) (aref rgba 0) (first rgba)) 1.0d0))
  (setf (aref lut row 1) (float (if (vectorp rgba) (aref rgba 1) (second rgba)) 1.0d0))
  (setf (aref lut row 2) (float (if (vectorp rgba) (aref rgba 2) (third rgba)) 1.0d0))
  (setf (aref lut row 3) (float (if (vectorp rgba) (aref rgba 3) (fourth rgba)) 1.0d0)))

(defmethod colormap-call ((cmap colormap) value &key alpha)
  "Map VALUE (float in [0,1]) to an RGBA vector.
For floats in [0,1], interpolates from the lookup table.
Returns an RGBA vector #(R G B A)."
  (%ensure-colormap-inited cmap)
  (let* ((n (colormap-n cmap))
         (lut (colormap-lut cmap))
         (i-under n)
         (i-over (1+ n))
         (i-bad (+ n 2)))
    (cond
      ;; NaN → bad color
      ((and (floatp value) (float-features:float-nan-p value))
       (let ((row (%lut-row lut i-bad)))
         (when alpha (setf (aref row 3) (float alpha 1.0d0)))
         row))
      ;; Float in [0,1] range
      ((and (numberp value) (realp value))
       (let* ((fval (float value 1.0d0))
              (idx (cond
                     ((< fval 0.0d0) i-under)
                     ((>= fval 1.0d0)
                      ;; Exactly 1.0 maps to last entry
                      (if (= fval 1.0d0)
                          (1- n)
                          i-over))
                     (t
                      (let ((scaled (floor (* fval n))))
                        (min scaled (1- n)))))))
         (let ((row (%lut-row lut idx)))
           (when alpha (setf (aref row 3) (float alpha 1.0d0)))
           row)))
      (t (error "Invalid colormap input: ~S" value)))))

;;; ============================================================
;;; LinearSegmentedColormap
;;; ============================================================

(defclass linear-segmented-colormap (colormap)
  ((segment-data :initarg :segment-data :accessor cmap-segment-data
                 :documentation "Dict-like plist (:red data :green data :blue data [:alpha data])")
   (gamma :initarg :gamma :initform 1.0 :accessor cmap-gamma))
  (:documentation "Colormap based on piecewise-linear segments."))

(defun make-linear-segmented-colormap (name segment-data &key (n 256) (gamma 1.0)
                                                              bad under over)
  "Create a LinearSegmentedColormap from segment data.
SEGMENT-DATA is a plist (:red data :green data :blue data [:alpha data])
where each data is a list of (x y0 y1) tuples."
  (make-instance 'linear-segmented-colormap
                 :name name
                 :segment-data segment-data
                 :n n
                 :gamma gamma
                 :bad (or bad #(0.0d0 0.0d0 0.0d0 0.0d0))
                 :under under
                 :over over))

(defmethod colormap-init ((cmap linear-segmented-colormap))
  (let* ((n (colormap-n cmap))
         (sd (cmap-segment-data cmap))
         (gamma (cmap-gamma cmap))
         (lut (%make-lut n)))
    ;; Red channel
    (let ((red-lut (%create-lookup-table n (getf sd :red) gamma)))
      (dotimes (i n) (setf (aref lut i 0) (aref red-lut i))))
    ;; Green channel
    (let ((green-lut (%create-lookup-table n (getf sd :green) gamma)))
      (dotimes (i n) (setf (aref lut i 1) (aref green-lut i))))
    ;; Blue channel
    (let ((blue-lut (%create-lookup-table n (getf sd :blue) gamma)))
      (dotimes (i n) (setf (aref lut i 2) (aref blue-lut i))))
    ;; Alpha channel (optional)
    (when (getf sd :alpha)
      (let ((alpha-lut (%create-lookup-table n (getf sd :alpha) 1.0)))
        (dotimes (i n) (setf (aref lut i 3) (aref alpha-lut i)))))
    (setf (colormap-lut cmap) lut)
    (setf (colormap-initialized-p cmap) t)
    (%update-lut-extremes cmap)))

(defun linear-segmented-colormap-from-list (name colors &key (n 256) (gamma 1.0)
                                                             bad under over)
  "Create a LinearSegmentedColormap from a list of colors.
COLORS is a list of color specs or (value color) pairs."
  (let* ((rgba-list (mapcar (lambda (c)
                              (if (and (listp c) (= (length c) 2) (numberp (first c)))
                                  ;; (value, color) pair
                                  c
                                  ;; plain color → convert to rgba
                                  (cl-matplotlib.colors:to-rgba c)))
                            colors))
         ;; Check if we have (value, color) pairs
         (has-values (and (listp (first rgba-list))
                          (= (length (first rgba-list)) 2)
                          (numberp (first (first rgba-list)))))
         (vals (if has-values
                   (mapcar #'first rgba-list)
                   (loop for i below (length colors)
                         collect (/ (float i 1.0d0) (float (1- (length colors)) 1.0d0)))))
         (rgbas (if has-values
                    (mapcar (lambda (vc) (cl-matplotlib.colors:to-rgba (second vc))) rgba-list)
                    (mapcar #'cl-matplotlib.colors:to-rgba colors))))
    ;; Build segment data
    (let ((red-data (mapcar (lambda (v rgba)
                              (list v (aref rgba 0) (aref rgba 0)))
                            vals rgbas))
          (green-data (mapcar (lambda (v rgba)
                                (list v (aref rgba 1) (aref rgba 1)))
                              vals rgbas))
          (blue-data (mapcar (lambda (v rgba)
                               (list v (aref rgba 2) (aref rgba 2)))
                             vals rgbas))
          (alpha-data (mapcar (lambda (v rgba)
                                (list v (aref rgba 3) (aref rgba 3)))
                              vals rgbas)))
      (make-linear-segmented-colormap
       name
       (list :red red-data :green green-data :blue blue-data :alpha alpha-data)
       :n n :gamma gamma :bad bad :under under :over over))))

;;; ============================================================
;;; ListedColormap
;;; ============================================================

(defclass listed-colormap (colormap)
  ((colors :initarg :colors :accessor listed-cmap-colors
           :documentation "List of color specs"))
  (:documentation "Colormap from a discrete list of colors."))

(defun make-listed-colormap (colors &key (name "unnamed") bad under over)
  "Create a ListedColormap from a list of color specifications."
  (make-instance 'listed-colormap
                 :name name
                 :colors (if (listp colors) colors (coerce colors 'list))
                 :n (length colors)
                 :bad (or bad #(0.0d0 0.0d0 0.0d0 0.0d0))
                 :under under
                 :over over))

(defmethod colormap-init ((cmap listed-colormap))
  (let* ((n (colormap-n cmap))
         (lut (%make-lut n))
         (colors (listed-cmap-colors cmap)))
    ;; Fill LUT from colors
    (loop for i below n
          for color in colors
          do (let ((rgba (if (and (vectorp color) (not (stringp color))
                                  (>= (length color) 3))
                             (if (= (length color) 4)
                                 color
                                 (vector (aref color 0) (aref color 1)
                                         (aref color 2) 1.0))
                             (cl-matplotlib.colors:to-rgba color))))
               (setf (aref lut i 0) (float (aref rgba 0) 1.0d0))
               (setf (aref lut i 1) (float (aref rgba 1) 1.0d0))
               (setf (aref lut i 2) (float (aref rgba 2) 1.0d0))
               (setf (aref lut i 3) (float (aref rgba 3) 1.0d0))))
    ;; Set alpha to 0 for remaining entries (N+3 total, but only N filled)
    (loop for i from n below (+ n 3)
          do (setf (aref lut i 0) 0.0d0
                   (aref lut i 1) 0.0d0
                   (aref lut i 2) 0.0d0
                   (aref lut i 3) 0.0d0))
    (setf (colormap-lut cmap) lut)
    (setf (colormap-initialized-p cmap) t)
    (%update-lut-extremes cmap)))

;;; ============================================================
;;; Normalize base class (linear normalization)
;;; ============================================================

(defclass normalize ()
  ((vmin :initarg :vmin :initform nil :accessor norm-vmin)
   (vmax :initarg :vmax :initform nil :accessor norm-vmax)
   (clip :initarg :clip :initform nil :accessor norm-clip))
  (:documentation "Linear normalization: maps [vmin,vmax] → [0,1]."))

(defun make-normalize (&key vmin vmax (clip nil))
  "Create a Normalize instance."
  (make-instance 'normalize :vmin (when vmin (float vmin 1.0d0))
                             :vmax (when vmax (float vmax 1.0d0))
                             :clip clip))

(defgeneric normalize-call (norm value)
  (:documentation "Normalize VALUE to [0,1] range."))

(defmethod normalize-call ((norm normalize) value)
  "Map VALUE through this normalization."
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm))
        (clip (norm-clip norm)))
    ;; Auto-set vmin/vmax from scalar
    (when (and (null vmin) (numberp value))
      (setf vmin (float value 1.0d0))
      (setf (norm-vmin norm) vmin))
    (when (and (null vmax) (numberp value))
      (setf vmax (float value 1.0d0))
      (setf (norm-vmax norm) vmax))
    (unless (and vmin vmax)
      (error "Both vmin and vmax must be set for normalization"))
    (let* ((fval (float value 1.0d0))
           (fmin (float vmin 1.0d0))
           (fmax (float vmax 1.0d0)))
      (cond
        ((= fmin fmax) 0.0d0)
        ((> fmin fmax) (error "vmin must be <= vmax"))
        (t
         (let ((result (/ (- fval fmin) (- fmax fmin))))
           (if clip
               (max 0.0d0 (min 1.0d0 result))
               result)))))))

(defgeneric normalize-inverse (norm value)
  (:documentation "Map normalized VALUE back to data space."))

(defmethod normalize-inverse ((norm normalize) value)
  "Inverse of normalization: maps [0,1] → [vmin,vmax]."
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm)))
    (unless (and vmin vmax)
      (error "Not invertible until both vmin and vmax are set"))
    (+ (float vmin 1.0d0) (* (float value 1.0d0)
                              (- (float vmax 1.0d0) (float vmin 1.0d0))))))

;;; ============================================================
;;; NoNorm — identity normalization
;;; ============================================================

(defclass no-norm (normalize) ()
  (:documentation "Identity normalization — values pass through unchanged."))

(defun make-no-norm ()
  "Create a NoNorm instance."
  (make-instance 'no-norm))

(defmethod normalize-call ((norm no-norm) value)
  value)

(defmethod normalize-inverse ((norm no-norm) value)
  value)

;;; ============================================================
;;; LogNorm — logarithmic normalization
;;; ============================================================

(defclass log-norm (normalize) ()
  (:documentation "Logarithmic normalization: maps [vmin,vmax] → [0,1] on log scale."))

(defun make-log-norm (&key vmin vmax (clip nil))
  "Create a LogNorm instance."
  (make-instance 'log-norm :vmin (when vmin (float vmin 1.0d0))
                            :vmax (when vmax (float vmax 1.0d0))
                            :clip clip))

(defmethod normalize-call ((norm log-norm) value)
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm))
        (clip (norm-clip norm)))
    (unless (and vmin vmax)
      (error "Both vmin and vmax must be set for LogNorm"))
    (let ((fval (float value 1.0d0))
          (fmin (float vmin 1.0d0))
          (fmax (float vmax 1.0d0)))
      (when (<= fmin 0.0d0)
        (error "LogNorm requires vmin > 0"))
      (when (<= fmax 0.0d0)
        (error "LogNorm requires vmax > 0"))
      (when (<= fval 0.0d0)
        ;; Mask non-positive values
        (return-from normalize-call 0.0d0))
      (let ((result (/ (- (log fval) (log fmin))
                       (- (log fmax) (log fmin)))))
        (if clip
            (max 0.0d0 (min 1.0d0 result))
            result)))))

(defmethod normalize-inverse ((norm log-norm) value)
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm)))
    (unless (and vmin vmax)
      (error "Not invertible until both vmin and vmax are set"))
    (let ((fmin (float vmin 1.0d0))
          (fmax (float vmax 1.0d0))
          (fval (float value 1.0d0)))
      (exp (+ (log fmin) (* fval (- (log fmax) (log fmin))))))))

;;; ============================================================
;;; SymLogNorm — symmetric logarithmic normalization
;;; ============================================================

(defclass sym-log-norm (normalize)
  ((linthresh :initarg :linthresh :accessor sym-log-norm-linthresh
              :documentation "Threshold for linear region")
   (linscale :initarg :linscale :initform 1.0d0 :accessor sym-log-norm-linscale)
   (base :initarg :base :initform 10.0d0 :accessor sym-log-norm-base))
  (:documentation "Symmetric log normalization: linear near zero, log for large values."))

(defun make-sym-log-norm (linthresh &key (linscale 1.0) (base 10.0) vmin vmax (clip nil))
  "Create a SymLogNorm instance."
  (make-instance 'sym-log-norm
                 :linthresh (float linthresh 1.0d0)
                 :linscale (float linscale 1.0d0)
                 :base (float base 1.0d0)
                 :vmin (when vmin (float vmin 1.0d0))
                 :vmax (when vmax (float vmax 1.0d0))
                 :clip clip))

(defun %symlog-transform (value linthresh linscale base)
  "Apply symmetric log transform to VALUE."
  (let ((lt (float linthresh 1.0d0))
        (ls (float linscale 1.0d0))
        (b (float base 1.0d0)))
    (let ((log-base (log b)))
      (declare (ignorable log-base))
      (let ((lin-range (* lt ls)))
        (cond
          ((<= (abs value) lt)
           ;; Linear region
           (* value ls))
          ((> value 0.0d0)
           ;; Positive log region
           (+ lin-range (* lt (/ (log (/ value lt)) log-base))))
          (t
           ;; Negative log region
           (- (- lin-range) (* lt (/ (log (/ (- value) lt)) log-base)))))))))

(defmethod normalize-call ((norm sym-log-norm) value)
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm))
        (clip (norm-clip norm))
        (lt (sym-log-norm-linthresh norm))
        (ls (sym-log-norm-linscale norm))
        (b (sym-log-norm-base norm)))
    (unless (and vmin vmax)
      (error "Both vmin and vmax must be set for SymLogNorm"))
    (let* ((t-val (%symlog-transform (float value 1.0d0) lt ls b))
           (t-min (%symlog-transform (float vmin 1.0d0) lt ls b))
           (t-max (%symlog-transform (float vmax 1.0d0) lt ls b))
           (result (if (= t-max t-min) 0.0d0
                       (/ (- t-val t-min) (- t-max t-min)))))
      (if clip
          (max 0.0d0 (min 1.0d0 result))
          result))))

;;; ============================================================
;;; PowerNorm — power-law normalization
;;; ============================================================

(defclass power-norm (normalize)
  ((gamma :initarg :gamma :accessor power-norm-gamma))
  (:documentation "Power-law normalization: ((x-vmin)/(vmax-vmin))^gamma."))

(defun make-power-norm (gamma &key vmin vmax (clip nil))
  "Create a PowerNorm instance."
  (make-instance 'power-norm
                 :gamma (float gamma 1.0d0)
                 :vmin (when vmin (float vmin 1.0d0))
                 :vmax (when vmax (float vmax 1.0d0))
                 :clip clip))

(defmethod normalize-call ((norm power-norm) value)
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm))
        (clip (norm-clip norm))
        (gamma (power-norm-gamma norm)))
    (unless (and vmin vmax)
      (error "Both vmin and vmax must be set for PowerNorm"))
    (let* ((fval (float value 1.0d0))
           (fmin (float vmin 1.0d0))
           (fmax (float vmax 1.0d0)))
      (cond
        ((= fmin fmax) 0.0d0)
        ((> fmin fmax) (error "vmin must be <= vmax"))
        (t
         (let* ((linear (/ (- fval fmin) (- fmax fmin)))
                (result (if (> linear 0.0d0)
                            (expt linear gamma)
                            linear)))  ; negative values pass through linearly
           (if clip
               (max 0.0d0 (min 1.0d0 result))
               result)))))))

(defmethod normalize-inverse ((norm power-norm) value)
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm))
        (gamma (power-norm-gamma norm)))
    (unless (and vmin vmax)
      (error "Not invertible until both vmin and vmax are set"))
    (let* ((fval (float value 1.0d0))
           (fmin (float vmin 1.0d0))
           (fmax (float vmax 1.0d0))
           (rescaled (if (> fval 0.0d0) (expt fval (/ 1.0d0 gamma)) fval)))
      (+ fmin (* rescaled (- fmax fmin))))))

;;; ============================================================
;;; TwoSlopeNorm — diverging normalization with center
;;; ============================================================

(defclass two-slope-norm (normalize)
  ((vcenter :initarg :vcenter :accessor two-slope-norm-vcenter))
  (:documentation "Normalize with different rates above/below center."))

(defun make-two-slope-norm (vcenter &key vmin vmax)
  "Create a TwoSlopeNorm instance."
  (when (and vmax (<= vmax vcenter))
    (error "vmin, vcenter, and vmax must be in ascending order"))
  (when (and vmin (>= vmin vcenter))
    (error "vmin, vcenter, and vmax must be in ascending order"))
  (make-instance 'two-slope-norm
                 :vcenter (float vcenter 1.0d0)
                 :vmin (when vmin (float vmin 1.0d0))
                 :vmax (when vmax (float vmax 1.0d0))))

(defmethod normalize-call ((norm two-slope-norm) value)
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm))
        (vc (two-slope-norm-vcenter norm))
        (fval (float value 1.0d0)))
    (unless (and vmin vmax)
      (error "Both vmin and vmax must be set for TwoSlopeNorm"))
    (unless (<= vmin vc vmax)
      (error "vmin, vcenter, vmax must increase monotonically"))
    ;; Piecewise linear interpolation
    (cond
      ((<= fval vmin) 0.0d0)
      ((>= fval vmax) 1.0d0)
      ((<= fval vc)
       ;; Left half: [vmin, vcenter] → [0, 0.5]
       (if (= vc vmin) 0.0d0
           (* 0.5d0 (/ (- fval vmin) (- vc vmin)))))
      (t
       ;; Right half: [vcenter, vmax] → [0.5, 1]
       (if (= vmax vc) 1.0d0
           (+ 0.5d0 (* 0.5d0 (/ (- fval vc) (- vmax vc)))))))))

(defmethod normalize-inverse ((norm two-slope-norm) value)
  (let ((vmin (norm-vmin norm))
        (vmax (norm-vmax norm))
        (vc (two-slope-norm-vcenter norm))
        (fval (float value 1.0d0)))
    (unless (and vmin vmax)
      (error "Not invertible until both vmin and vmax are set"))
    (if (<= fval 0.5d0)
        ;; [0, 0.5] → [vmin, vcenter]
        (+ vmin (* (/ fval 0.5d0) (- vc vmin)))
        ;; [0.5, 1] → [vcenter, vmax]
        (+ vc (* (/ (- fval 0.5d0) 0.5d0) (- vmax vc))))))

;;; ============================================================
;;; BoundaryNorm — discrete bin normalization
;;; ============================================================

(defclass boundary-norm (normalize)
  ((boundaries :initarg :boundaries :accessor boundary-norm-boundaries)
   (ncolors :initarg :ncolors :accessor boundary-norm-ncolors)
   (extend :initarg :extend :initform :neither :accessor boundary-norm-extend))
  (:documentation "Generate colormap index based on discrete intervals."))

(defun make-boundary-norm (boundaries ncolors &key (clip nil) (extend :neither))
  "Create a BoundaryNorm instance."
  (let* ((bvec (coerce boundaries 'vector))
         (nb (length bvec)))
    (when (< nb 2)
      (error "You must provide at least 2 boundaries"))
    (when (and clip (not (eq extend :neither)))
      (error "'clip=T' is not compatible with 'extend'"))
    (let* ((n-regions (1- nb))
           (offset 0))
      (when (member extend '(:min :both))
        (incf n-regions)
        (incf offset))
      (when (member extend '(:max :both))
        (incf n-regions))
      (when (> n-regions ncolors)
        (error "There are ~D color bins but ncolors = ~D" n-regions ncolors))
      (make-instance 'boundary-norm
                     :boundaries (map 'vector (lambda (x) (float x 1.0d0)) bvec)
                     :ncolors ncolors
                     :vmin (float (aref bvec 0) 1.0d0)
                     :vmax (float (aref bvec (1- nb)) 1.0d0)
                     :clip clip
                     :extend extend))))

(defmethod normalize-call ((norm boundary-norm) value)
  (let* ((bounds (boundary-norm-boundaries norm))
         (ncolors (boundary-norm-ncolors norm))
         (clip (norm-clip norm))
         (extend (boundary-norm-extend norm))
         (nb (length bounds))
         (n-regions (1- nb))
         (offset 0)
         (fval (float value 1.0d0))
         (vmin (aref bounds 0))
         (vmax (aref bounds (1- nb))))
    (when (member extend '(:min :both))
      (incf n-regions)
      (incf offset))
    (when (member extend '(:max :both))
      (incf n-regions))
    (when clip
      (setf fval (max vmin (min vmax fval))))
    ;; Find bin using binary search
    (let ((bin (1- (position-if (lambda (b) (> b fval)) bounds))))
      (when (null bin)
        ;; Value is >= all boundaries
        (setf bin (- nb 2)))  ; last bin
      (when (< bin 0) (setf bin 0))
      (let* ((iret (+ bin offset))
             (max-col (if clip (1- ncolors) ncolors)))
        ;; Remap if more colors than regions
        (when (> ncolors n-regions)
          (if (= n-regions 1)
              (setf iret (floor (1- ncolors) 2))
              (setf iret (round (* (/ (float (1- ncolors) 1.0d0)
                                      (float (1- n-regions) 1.0d0))
                                   iret)))))
        ;; Handle out-of-range
        (cond
          ((< fval vmin) (setf iret (if clip 0 -1)))
          ((>= fval vmax) (setf iret max-col)))
        iret))))

(defmethod normalize-inverse ((norm boundary-norm) value)
  (declare (ignore value))
  (error "BoundaryNorm is not invertible"))

;;; ============================================================
;;; ScalarMappable — combines Normalize + Colormap
;;; ============================================================

(defclass scalar-mappable ()
  ((norm :initarg :norm :initform nil :accessor sm-norm)
   (cmap :initarg :cmap :initform nil :accessor sm-cmap)
   (array-data :initform nil :accessor sm-array))
  (:documentation "Mixin that maps scalar data → RGBA via norm + colormap."))

(defun make-scalar-mappable (&key norm cmap)
  "Create a ScalarMappable combining NORM and CMAP."
  (make-instance 'scalar-mappable
                 :norm (or norm (make-normalize))
                 :cmap (or cmap (get-colormap :viridis))))

(defgeneric scalar-mappable-to-rgba (sm value &key alpha)
  (:documentation "Map VALUE through normalization and colormap to RGBA."))

(defmethod scalar-mappable-to-rgba ((sm scalar-mappable) value &key alpha)
  "Map VALUE through norm → [0,1] → colormap → RGBA."
  (let* ((norm (sm-norm sm))
         (cmap (sm-cmap sm))
         (normalized (normalize-call norm value)))
    (colormap-call cmap normalized :alpha alpha)))

(defmethod scalar-mappable-autoscale ((sm scalar-mappable) data)
  "Set norm vmin/vmax from DATA (a list or vector of numbers)."
  (let ((vals (if (listp data) data (coerce data 'list))))
    (setf (norm-vmin (sm-norm sm)) (float (apply #'min vals) 1.0d0))
    (setf (norm-vmax (sm-norm sm)) (float (apply #'max vals) 1.0d0))))
