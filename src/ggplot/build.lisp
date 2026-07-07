;;;; build.lisp — ggbuild: spec -> computed layer data + trained scales
;;;;
;;;; Stage order follows ggplot2's ggplot_build: evaluate aes -> transform
;;;; (continuous) -> stats -> train+map discrete/non-positional scales ->
;;;; fixed aesthetics -> geom setup -> positions -> train positional
;;;; scales -> panel params -> coord.

(in-package #:ggplot)

(defstruct (ggbuilt (:constructor %make-ggbuilt))
  plot          ; the original ggplot spec
  layer-tables  ; list of (layer . gtable) with final aesthetic columns
  scales        ; alist of aesthetic -> scale
  layout        ; facet layout entries (:index :row :col :label :key)
  nrow          ; facet grid rows
  ncol          ; facet grid cols
  panels        ; list of panel plists
  legends       ; list of legend specs (plist :aesthetic :title :labels
                ;   :values :geom)
  theme
  labs)

(defparameter *x-aesthetics* '(:x :xmin :xmax :xend :xintercept))
;; :ymin-final/:ymax-final are stat outputs (boxplot) that extend the
;; trained range to cover outliers without moving the whiskers, like
;; plotnine's ymin_final/ymax_final.
(defparameter *y-aesthetics* '(:y :ymin :ymax :yend :yintercept
                               :ymin-final :ymax-final))
(defparameter *non-positional-aesthetics* '(:color :fill :shape :size :alpha :linetype))

(defun %plot-effective-layers (plot)
  (or (plot-layers plot)
      (list (geom-blank))))

(defun %layer-table (plot layer)
  (let ((data (or (layer-data layer) (plot-data plot))))
    (unless data
      (error "Layer has no data: neither the layer nor the plot supplies any"))
    (coerce-ggdata data)))

(defun %layer-mapping (plot layer)
  (if (layer-inherit-aes layer)
      (merge-aes (plot-mapping plot) (layer-mapping layer))
      (layer-mapping layer)))

(defun %evaluate-layer-aes (plot layer table)
  "Evaluate the merged aesthetic mapping against TABLE; returns a gtable
keyed by aesthetic. after-stat refs are left for the stat step."
  (let ((mapping (%layer-mapping plot layer)))
    (unless mapping
      (error "No aesthetic mapping: supply (aes ...) on the plot or the layer"))
    (let ((result (make-gtable)))
      (setf (gtable-nrows result) (gtable-nrows table))
      (loop for (aesthetic . ref) in (aes-alist mapping)
            for value = (eval-aesthetic ref table)
            when (and value (not (after-stat-ref-p value)))
              do (setf result (gtable-set-column result aesthetic value)))
      result)))

(defun %compute-group (table)
  "Add a :group column: the interaction of all discrete aesthetic columns
including discrete x/y (or the explicit :group mapping) — ggplot2
semantics: a discrete x splits stats into per-category groups."
  (if (gtable-column table :group)
      table
      (let ((discrete-cols
              (loop for aes in (list* :x :y *non-positional-aesthetics*)
                    for col = (gtable-column table aes)
                    when (and col (some #'discrete-value-p col))
                      collect col)))
        (if (null discrete-cols)
            (gtable-set-column table :group
                               (make-array (gtable-nrows table)
                                           :initial-element 0))
            (gtable-set-column
             table :group
             (loop with n = (gtable-nrows table)
                   with out = (make-array n)
                   for i from 0 below n
                   do (setf (aref out i)
                            (format nil "~{~A~^|~}"
                                    (mapcar (lambda (c) (svref c i))
                                            discrete-cols)))
                   finally (return out)))))))

(defun %resolve-after-stat (plot layer table)
  "Fill aesthetics mapped to (after-stat NAME) from the stat's output."
  (let ((mapping (%layer-mapping plot layer))
        (result table))
    (when mapping
      (loop for (aesthetic . ref) in (aes-alist mapping)
            when (after-stat-ref-p ref)
              do (let* ((name-or-fn (after-stat-ref-name ref))
                        (col (if (functionp name-or-fn)
                                 (let ((v (coerce (funcall name-or-fn table)
                                                  'simple-vector)))
                                   (unless (= (length v) (gtable-nrows table))
                                     (error "after-stat function returned ~D ~
                                             values for ~D stat rows"
                                            (length v) (gtable-nrows table)))
                                   v)
                                 (gtable-column table name-or-fn))))
                   (unless col
                     (error "after-stat: the stat produced no ~S column"
                            name-or-fn))
                   (setf result (gtable-set-column result aesthetic col)))))
    result))

(defun %apply-stat-default-aes (layer table)
  "Map the stat's default aesthetics (e.g. stat-count: :y = count) for
aesthetics the user didn't map."
  (let ((result table))
    (loop for (aesthetic ref) on (stat-default-aes (layer-stat layer)) by #'cddr
          when (and (null (gtable-column result aesthetic))
                    (after-stat-ref-p ref))
            do (let ((col (gtable-column table (after-stat-ref-name ref))))
                 (when col
                   (setf result (gtable-set-column result aesthetic col)))))
    result))

(defun %apply-fixed-aesthetics (layer table)
  "Fill unmapped aesthetic columns from layer params (first priority) and
the geom's default aesthetics. Fixed values bypass scales (ggplot2
semantics: (geom-point :color \"red\") is literal red)."
  (let ((n (gtable-nrows table))
        (result table))
    (loop for (k v) on (append (layer-params layer)
                               (geom-default-aes (layer-geom layer)))
          by #'cddr
          do (when (and (member k *known-aesthetics*)
                        (null (gtable-column result k)))
               (setf result
                     (gtable-set-column result k
                                        (make-array n :initial-element v)))))
    result))

;;; ============================================================
;;; Scales
;;; ============================================================

(defun %ensure-scales (plot layer-tables)
  "Alist aesthetic -> scale for every aesthetic present in any layer;
explicit plot scales win, others are inferred from the data."
  (labels ((explicit (aesthetic)
             (find-if (lambda (s) (member aesthetic (scale-aesthetics s)))
                      (plot-scales plot)))
           (sample (aesthetics)
             (loop for (nil . table) in layer-tables
                   append (loop for aes in aesthetics
                                for col = (gtable-column table aes)
                                when col append (coerce col 'list)))))
    (let ((scales '()))
      (let ((x-sample (sample *x-aesthetics*))
            (y-sample (sample *y-aesthetics*)))
        (when x-sample
          (push (cons :x (or (explicit :x) (find-default-scale :x x-sample)))
                scales))
        (when y-sample
          (push (cons :y (or (explicit :y) (find-default-scale :y y-sample)))
                scales)))
      (dolist (aes *non-positional-aesthetics*)
        (let ((vals (sample (list aes))))
          (when vals
            (let ((scale (or (explicit aes) (find-default-scale aes vals))))
              (when scale (push (cons aes scale) scales))))))
      (nreverse scales))))

(defun %scale-for (scales aesthetic)
  (cdr (assoc aesthetic scales)))

(defun %positional-scale-for-aes (scales aesthetic)
  (cond ((member aesthetic *x-aesthetics*) (%scale-for scales :x))
        ((member aesthetic *y-aesthetics*) (%scale-for scales :y))
        (t nil)))

(defun %train-discrete-and-nonpositional (scales layer-tables)
  (loop for (nil . table) in layer-tables do
    ;; Discrete positional
    (dolist (aes (append *x-aesthetics* *y-aesthetics*))
      (let ((scale (%positional-scale-for-aes scales aes))
            (col (gtable-column table aes)))
        (when (and col scale (typep scale 'scale-discrete))
          (scale-train scale col))))
    ;; Non-positional
    (dolist (aes *non-positional-aesthetics*)
      (let ((scale (%scale-for scales aes))
            (col (gtable-column table aes)))
        (when (and col scale)
          (scale-train scale col))))))

(defun %map-scales (scales table)
  "Replace mapped-aesthetic columns with their scale-mapped values."
  (let ((result table))
    ;; Discrete positional -> numeric positions
    (dolist (aes (append *x-aesthetics* *y-aesthetics*))
      (let ((scale (%positional-scale-for-aes scales aes))
            (col (gtable-column result aes)))
        (when (and col scale (typep scale 'scale-discrete))
          (setf result (gtable-set-column result aes (scale-map scale col))))))
    ;; Non-positional -> palette values
    (dolist (aes *non-positional-aesthetics*)
      (let ((scale (%scale-for scales aes))
            (col (gtable-column result aes)))
        (when (and col scale)
          (setf result (gtable-set-column result aes (scale-map scale col))))))
    result))

(defun %train-positional-scales (scales layer-tables)
  (let ((x-scale (%scale-for scales :x))
        (y-scale (%scale-for scales :y)))
    (loop for (nil . table) in layer-tables do
      (dolist (aes *x-aesthetics*)
        (let ((col (gtable-column table aes)))
          (when (and col x-scale (typep x-scale 'scale-continuous))
            (scale-train x-scale col))))
      (dolist (aes *y-aesthetics*)
        (let ((col (gtable-column table aes)))
          (when (and col y-scale (typep y-scale 'scale-continuous))
            (scale-train y-scale col)))))))

(defun %fresh-panel-scale (scale)
  "A copy of positional SCALE with fresh (untrained) range state, for
per-panel training under free facet scales."
  (unless (typep scale 'scale-continuous)
    (error "free facet scales require continuous positional scales"))
  (make-instance (class-of scale)
                 :aesthetics (scale-aesthetics scale)
                 :name (scale-name scale)
                 :breaks (scale-user-breaks scale)
                 :labels (scale-user-labels scale)
                 :expand (scale-user-expand scale)))

(defun %panel-scale-params (scale aesthetics layer-tables panel-index prefix)
  "Panel-local range/breaks plist (:x-range :x-breaks :x-labels :x-minor
or the y equivalents) from a fresh scale trained on the panel's rows."
  (let ((local (%fresh-panel-scale scale)))
    (loop for (nil . table) in layer-tables
          for subset = (%gtable-panel-subset table panel-index)
          do (dolist (aes aesthetics)
               (let ((col (gtable-column subset aes)))
                 (when col (scale-train local col)))))
    (let* ((range (scale-expanded-range local))
           (breaks (remove-if-not
                    (lambda (b) (<= (first range) b (second range)))
                    (scale-breaks local))))
      (list (intern (format nil "~A-RANGE" prefix) :keyword) range
            (intern (format nil "~A-BREAKS" prefix) :keyword) breaks
            (intern (format nil "~A-LABELS" prefix) :keyword)
            (scale-break-labels local breaks)
            (intern (format nil "~A-MINOR" prefix) :keyword)
            (scale-minor-breaks local breaks range)))))

(defun %panel-params (scales &key flipped)
  (let* ((x-scale (%scale-for scales :x))
         (y-scale (%scale-for scales :y))
         (x-range (scale-expanded-range x-scale))
         (y-range (scale-expanded-range y-scale))
         (x-breaks (remove-if-not (lambda (b) (<= (first x-range) b (second x-range)))
                                  (scale-breaks x-scale)))
         (y-breaks (remove-if-not (lambda (b) (<= (first y-range) b (second y-range)))
                                  (scale-breaks y-scale)))
         (params (list :index 0
                       :x-range x-range
                       :y-range y-range
                       :x-breaks x-breaks
                       :x-labels (scale-break-labels x-scale x-breaks)
                       :x-minor (scale-minor-breaks x-scale x-breaks x-range)
                       :y-breaks y-breaks
                       :y-labels (scale-break-labels y-scale y-breaks)
                       :y-minor (scale-minor-breaks y-scale y-breaks
                                                    y-range))))
    (if flipped
        (list :index 0
              :x-range (getf params :y-range)
              :y-range (getf params :x-range)
              :x-breaks (getf params :y-breaks)
              :x-labels (getf params :y-labels)
              :x-minor (getf params :y-minor)
              :y-breaks (getf params :x-breaks)
              :y-labels (getf params :x-labels)
              :y-minor (getf params :x-minor))
        params)))

;;; ============================================================
;;; Legends
;;; ============================================================

(defun %collect-legends (plot scales layer-tables)
  "Legend specs for discrete non-positional scales with visible guides."
  (let ((legends '()))
    (dolist (aes '(:color :fill :shape))
      (let ((scale (%scale-for scales aes)))
        (when (and scale
                   (typep scale 'scale-discrete-palette)
                   (not (eq (scale-guide scale) :none))
                   (scale-levels scale))
          (let* ((levels (scale-levels scale))
                 (values (funcall (scale-palette scale) (length levels)))
                 ;; the first layer whose mapping uses this aesthetic
                 ;; supplies the legend key artists
                 (layer (loop for (l . nil) in layer-tables
                              for m = (%layer-mapping plot l)
                              when (and m (aes-ref m aes)) return l))
                 (title (or (scale-name scale)
                            (let* ((m (and layer (%layer-mapping plot layer)))
                                   (ref (and m (aes-ref m aes))))
                              (typecase ref
                                (string ref)
                                (symbol (string-downcase (symbol-name ref)))
                                (t (string-downcase (symbol-name aes))))))))
            (when layer
              (push (list :aesthetic aes
                          :title title
                          :labels (mapcar #'princ-to-string levels)
                          :values values
                          :geom (layer-geom layer)
                          :params (layer-params layer))
                    legends))))))
    (nreverse legends)))

;;; ============================================================
;;; ggbuild
;;; ============================================================

(defgeneric ggbuild (plot)
  (:documentation "Run the grammar pipeline over PLOT, returning a ggbuilt."))

(defmethod ggbuild ((plot ggplot))
  (let* ((layers (%plot-effective-layers plot))
         (flipped (typep (plot-coord plot) 'coord-flip-obj))
         (facet (or (plot-facet plot) (make-instance 'facet-null-obj)))
         (raw-tables (mapcar (lambda (layer) (%layer-table plot layer)) layers)))
    (multiple-value-bind (layout nrow ncol) (facet-layout facet raw-tables)
      (let ((layer-tables
              ;; 1. resolve data + evaluate aes + group + panel assignment
              (mapcar (lambda (layer raw)
                        (let ((aes-table (%evaluate-layer-aes plot layer raw)))
                          (cons layer
                                (gtable-set-column
                                 (%compute-group aes-table)
                                 :panel
                                 (facet-assign-panels facet layout raw)))))
                      layers raw-tables)))
    ;; 1.5 explicit-scale forward transforms (log10 etc.) happen BEFORE
    ;; stats, like plotnine: densities/bins operate on transformed data
    (setf layer-tables
          (mapcar (lambda (entry)
                    (destructuring-bind (layer . table) entry
                      (let ((result table))
                        (dolist (spec (list (cons :x *x-aesthetics*)
                                            (cons :y *y-aesthetics*)))
                          (let ((scale (find-if
                                        (lambda (sc)
                                          (member (car spec)
                                                  (scale-aesthetics sc)))
                                        (plot-scales plot))))
                            (when scale
                              (dolist (aes (cdr spec))
                                (let ((col (gtable-column result aes)))
                                  (when col
                                    (setf result
                                          (gtable-set-column
                                           result aes
                                           (scale-transform scale col)))))))))
                        (cons layer result))))
                  layer-tables))
    ;; 2. stats (per layer), then after-stat resolution. Stats run before
    ;; scale inference: stat-count creates the y column a bar plot's y
    ;; scale is inferred from.
    (setf layer-tables
          (mapcar (lambda (entry)
                    (destructuring-bind (layer . table) entry
                      (cons layer
                            (%map-table-panels
                             table
                             (lambda (sub)
                               (%apply-stat-default-aes
                                layer
                                (%resolve-after-stat
                                 plot layer
                                 (stat-compute-panel
                                  (layer-stat layer) sub '()))))))))
                  layer-tables))
    ;; 3. scales for everything present in the stat output
    (let ((scales (%ensure-scales plot layer-tables)))
    ;; 4. train discrete positional + non-positional, then map
    (%train-discrete-and-nonpositional scales layer-tables)
    (setf layer-tables
          (mapcar (lambda (entry)
                    (destructuring-bind (layer . table) entry
                      (cons layer (%map-scales scales table))))
                  layer-tables))
    ;; 5. fixed aesthetics, geom setup, positions
    (setf layer-tables
          (mapcar (lambda (entry)
                    (destructuring-bind (layer . table) entry
                      (cons layer
                            (%map-table-panels
                             (geom-setup-data
                              (layer-geom layer)
                              (%apply-fixed-aesthetics layer table))
                             (lambda (sub)
                               (position-adjust (layer-position layer) sub))))))
                  layer-tables))
    ;; 6. train continuous positional scales on the final geometry
    (%train-positional-scales scales layer-tables)
    ;; 7. coord-flip: swap aesthetic columns; panel params swap ranges
    (when flipped
      (setf layer-tables
            (mapcar (lambda (entry)
                      (destructuring-bind (layer . table) entry
                        (cons layer (%flip-table table))))
                    layer-tables)))
    (%make-ggbuilt
     :plot plot
     :layer-tables layer-tables
     :scales scales
     :layout layout
     :nrow nrow
     :ncol ncol
     :panels (let ((base (%panel-params scales :flipped flipped))
                   (free-x (facet-free-x-p facet))
                   (free-y (facet-free-y-p facet)))
               (when (and flipped (or free-x free-y))
                 (error "free facet scales with coord-flip are not supported"))
               (loop for entry in layout
                     for idx = (getf entry :index)
                     collect
                     (append entry
                             ;; free dims override the shared params with
                             ;; panel-locally trained ranges/breaks
                             (when free-x
                               (%panel-scale-params
                                (%scale-for scales :x) *x-aesthetics*
                                layer-tables idx "X"))
                             (when free-y
                               (%panel-scale-params
                                (%scale-for scales :y) *y-aesthetics*
                                layer-tables idx "Y"))
                             (copy-list base))))
     :legends (%collect-legends plot scales layer-tables)
     :theme (merge-themes (theme-get) (plot-theme plot))
     :labs (if flipped
               ;; flip swaps which label belongs to which axis
               (let ((labs (plot-labs plot)))
                 (mapcar (lambda (e)
                           (case (car e)
                             (:x (cons :y (cdr e)))
                             (:y (cons :x (cdr e)))
                             (t e)))
                         labs))
               (plot-labs plot))))))))
