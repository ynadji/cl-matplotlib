;;;; gridspec.lisp — GridSpec, SubplotSpec, GridSpecFromSubplotSpec
;;;; Ported from matplotlib's gridspec.py
;;;; Enables flexible subplot layouts for multi-axes figures.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; SubplotSpec — position of a subplot within a GridSpec
;;; ============================================================

(defclass subplot-spec ()
  ((gridspec :initarg :gridspec
             :accessor subplotspec-gridspec
             :documentation "Parent GridSpec.")
   (num1 :initarg :num1
          :accessor subplotspec-num1
          :type integer
          :documentation "Start cell index (0-based, row-major).")
   (num2 :initarg :num2
          :accessor subplotspec-num2
          :type integer
          :documentation "End cell index (0-based, row-major). Same as num1 for single cell."))
  (:documentation "The location of a subplot in a GridSpec.
NUM1 and NUM2 are 0-based flat indices (row-major) into the grid.
For a single cell, NUM1 = NUM2. For spanning, NUM2 > NUM1."))

(defun make-subplot-spec (gridspec num1 &optional (num2 nil))
  "Create a SubplotSpec for cells NUM1 to NUM2 in GRIDSPEC.
If NUM2 is NIL, defaults to NUM1 (single cell)."
  (make-instance 'subplot-spec
                 :gridspec gridspec
                 :num1 num1
                 :num2 (or num2 num1)))

(defun subplotspec-get-gridspec (ss)
  "Return the parent GridSpec of SUBPLOT-SPEC."
  (subplotspec-gridspec ss))

(defun subplotspec-get-rows-columns (ss)
  "Return (values row1 row2 col1 col2) for the subplot spec.
Rows/cols are 0-based. row1/col1 are start, row2/col2 are end (inclusive)."
  (let* ((gs (subplotspec-gridspec ss))
         (ncols (gridspec-ncols gs))
         (num1 (subplotspec-num1 ss))
         (num2 (subplotspec-num2 ss))
         (row1 (floor num1 ncols))
         (col1 (mod num1 ncols))
         (row2 (floor num2 ncols))
         (col2 (mod num2 ncols)))
    ;; Sort columns in case num2 refers to a column to the left of num1
    (when (> col1 col2)
      (rotatef col1 col2))
    (values row1 row2 col1 col2)))

(defun subplotspec-rowspan (ss)
  "Return (values start stop) for the rows spanned (stop exclusive)."
  (let* ((ncols (gridspec-ncols (subplotspec-gridspec ss)))
         (row1 (floor (subplotspec-num1 ss) ncols))
         (row2 (floor (subplotspec-num2 ss) ncols)))
    (values row1 (1+ row2))))

(defun subplotspec-colspan (ss)
  "Return (values start stop) for the columns spanned (stop exclusive)."
  (let* ((ncols (gridspec-ncols (subplotspec-gridspec ss)))
         (c1 (mod (subplotspec-num1 ss) ncols))
         (c2 (mod (subplotspec-num2 ss) ncols)))
    (when (> c1 c2) (rotatef c1 c2))
    (values c1 (1+ c2))))

(defun subplotspec-get-position (ss figure)
  "Return (left bottom width height) in figure coordinates for this SubplotSpec."
  (let ((gs (subplotspec-gridspec ss)))
    (multiple-value-bind (bottoms tops lefts rights)
        (gridspec-get-grid-positions gs figure)
      (multiple-value-bind (row1 row2 col1 col2)
          (subplotspec-get-rows-columns ss)
        (let ((fig-left (reduce #'min (subseq lefts col1 (1+ col2))))
              (fig-right (reduce #'max (subseq rights col1 (1+ col2))))
              (fig-bottom (reduce #'min (subseq bottoms row1 (1+ row2))))
              (fig-top (reduce #'max (subseq tops row1 (1+ row2)))))
          (list fig-left fig-bottom
                (- fig-right fig-left)
                (- fig-top fig-bottom)))))))

(defmethod print-object ((ss subplot-spec) stream)
  (print-unreadable-object (ss stream :type t)
    (multiple-value-bind (r1 r2 c1 c2)
        (subplotspec-get-rows-columns ss)
      (format stream "rows=~D:~D cols=~D:~D" r1 r2 c1 c2))))

;;; ============================================================
;;; GridSpec — grid layout for subplots
;;; ============================================================

(defclass gridspec-base ()
  ((nrows :initarg :nrows
          :accessor gridspec-nrows
          :type integer
          :documentation "Number of rows in the grid.")
   (ncols :initarg :ncols
          :accessor gridspec-ncols
          :type integer
          :documentation "Number of columns in the grid.")
   (height-ratios :initarg :height-ratios
                  :accessor gridspec-height-ratios
                  :documentation "Relative heights of rows (list of numbers).")
   (width-ratios :initarg :width-ratios
                 :accessor gridspec-width-ratios
                 :documentation "Relative widths of columns (list of numbers)."))
  (:documentation "Base class for GridSpec — specifies grid geometry."))

(defclass gridspec (gridspec-base)
  ((figure :initarg :figure
           :initform nil
           :accessor gridspec-figure
           :documentation "Parent figure.")
   (gs-left :initarg :left
            :initform nil
            :accessor gridspec-left
            :documentation "Left extent (fraction of figure width), or NIL for default.")
   (gs-right :initarg :right
             :initform nil
             :accessor gridspec-right
             :documentation "Right extent.")
   (gs-top :initarg :top
           :initform nil
           :accessor gridspec-top
           :documentation "Top extent.")
   (gs-bottom :initarg :bottom
              :initform nil
              :accessor gridspec-bottom
              :documentation "Bottom extent.")
   (gs-wspace :initarg :wspace
              :initform nil
              :accessor gridspec-wspace
              :documentation "Width spacing between subplots (fraction of avg axis width).")
   (gs-hspace :initarg :hspace
              :initform nil
              :accessor gridspec-hspace
              :documentation "Height spacing between subplots (fraction of avg axis height)."))
  (:documentation "A grid layout to place subplots within a figure.
Indexing returns SubplotSpec instances."))

(defmethod initialize-instance :after ((gs gridspec-base) &key)
  "Validate and set default ratios."
  (unless (and (integerp (gridspec-nrows gs)) (> (gridspec-nrows gs) 0))
    (error "Number of rows must be a positive integer, not ~S" (gridspec-nrows gs)))
  (unless (and (integerp (gridspec-ncols gs)) (> (gridspec-ncols gs) 0))
    (error "Number of columns must be a positive integer, not ~S" (gridspec-ncols gs)))
  ;; Default ratios: all equal
  (unless (slot-boundp gs 'height-ratios)
    (setf (gridspec-height-ratios gs) nil))
  (when (null (gridspec-height-ratios gs))
    (setf (gridspec-height-ratios gs)
          (make-list (gridspec-nrows gs) :initial-element 1.0d0)))
  (unless (slot-boundp gs 'width-ratios)
    (setf (gridspec-width-ratios gs) nil))
  (when (null (gridspec-width-ratios gs))
    (setf (gridspec-width-ratios gs)
          (make-list (gridspec-ncols gs) :initial-element 1.0d0)))
  ;; Validate ratio lengths
  (unless (= (length (gridspec-height-ratios gs)) (gridspec-nrows gs))
    (error "Height ratios length (~D) must match nrows (~D)"
           (length (gridspec-height-ratios gs)) (gridspec-nrows gs)))
  (unless (= (length (gridspec-width-ratios gs)) (gridspec-ncols gs))
    (error "Width ratios length (~D) must match ncols (~D)"
           (length (gridspec-width-ratios gs)) (gridspec-ncols gs))))

(defun make-gridspec (nrows ncols &key figure left right top bottom wspace hspace
                                       width-ratios height-ratios)
  "Create a GridSpec with NROWS x NCOLS grid.

FIGURE — parent figure (optional).
LEFT, RIGHT, TOP, BOTTOM — subplot extents as fraction of figure size.
WSPACE, HSPACE — spacing between subplots as fraction of avg axis size.
WIDTH-RATIOS — list of relative column widths.
HEIGHT-RATIOS — list of relative row heights."
  (make-instance 'gridspec
                 :nrows nrows :ncols ncols
                 :figure figure
                 :left left :right right :top top :bottom bottom
                 :wspace wspace :hspace hspace
                 :width-ratios width-ratios
                 :height-ratios height-ratios))

(defun gridspec-get-geometry (gs)
  "Return (values nrows ncols) for the grid."
  (values (gridspec-nrows gs) (gridspec-ncols gs)))

(defgeneric gridspec-get-subplot-params (gs &optional figure)
  (:documentation "Return subplot params as plist (:left :right :top :bottom :wspace :hspace)."))

(defmethod gridspec-get-subplot-params ((gs gridspec) &optional figure)
  "Merges GridSpec overrides with figure defaults."
  (let* ((fig (or figure (gridspec-figure gs)))
         (defaults (if fig
                       (copy-list (figure-subplot-params fig))
                       (list :left 0.125d0 :right 0.9d0
                             :bottom 0.11d0 :top 0.88d0
                             :wspace 0.2d0 :hspace 0.2d0))))
    ;; Apply GridSpec overrides (only if non-nil)
    (when (gridspec-left gs)
      (setf (getf defaults :left) (coerce (gridspec-left gs) 'double-float)))
    (when (gridspec-right gs)
      (setf (getf defaults :right) (coerce (gridspec-right gs) 'double-float)))
    (when (gridspec-top gs)
      (setf (getf defaults :top) (coerce (gridspec-top gs) 'double-float)))
    (when (gridspec-bottom gs)
      (setf (getf defaults :bottom) (coerce (gridspec-bottom gs) 'double-float)))
    (when (gridspec-wspace gs)
      (setf (getf defaults :wspace) (coerce (gridspec-wspace gs) 'double-float)))
    (when (gridspec-hspace gs)
      (setf (getf defaults :hspace) (coerce (gridspec-hspace gs) 'double-float)))
    defaults))

(defun gridspec-get-grid-positions (gs figure)
  "Return (values bottoms tops lefts rights) as vectors of positions.
Each vector has NROWS (or NCOLS) elements giving cell boundaries in figure coords.

This ports matplotlib's GridSpecBase.get_grid_positions with height/width ratio support."
  (let* ((nrows (gridspec-nrows gs))
         (ncols (gridspec-ncols gs))
         (params (gridspec-get-subplot-params gs figure))
         (left (getf params :left))
         (right (getf params :right))
         (bottom (getf params :bottom))
         (top (getf params :top))
         (wspace (getf params :wspace))
         (hspace (getf params :hspace))
         (tot-width (- right left))
         (tot-height (- top bottom)))
    ;; Compute cell heights with ratios (matplotlib algorithm)
    ;; cell_h = tot_height / (nrows + hspace*(nrows-1))
    ;; sep_h = hspace * cell_h
    (let* ((cell-h (/ tot-height (+ nrows (* hspace (1- nrows)))))
           (sep-h (* hspace cell-h))
           (height-ratio-sum (reduce #'+ (gridspec-height-ratios gs)))
           (h-norm (/ (* cell-h nrows) height-ratio-sum))
           (cell-heights (mapcar (lambda (r) (* r h-norm))
                                 (gridspec-height-ratios gs)))
           ;; Compute cumulative: [0, h0, sep, h1, sep, h2, ...]
           ;; Then reshape to get (bottom, top) pairs
           (bottoms (make-array nrows :element-type 'double-float))
           (tops (make-array nrows :element-type 'double-float))
           ;; Compute cell widths with ratios
           (cell-w (/ tot-width (+ ncols (* wspace (1- ncols)))))
           (sep-w (* wspace cell-w))
           (width-ratio-sum (reduce #'+ (gridspec-width-ratios gs)))
           (w-norm (/ (* cell-w ncols) width-ratio-sum))
           (cell-widths (mapcar (lambda (r) (* r w-norm))
                                (gridspec-width-ratios gs)))
           (lefts-vec (make-array ncols :element-type 'double-float))
           (rights-vec (make-array ncols :element-type 'double-float)))
      ;; Build row positions: top-down (row 0 = top)
      ;; Cumulative accumulation matching matplotlib's get_grid_positions
      (let ((cum 0.0d0))
        (dotimes (i nrows)
          ;; Add separator (0 for first row)
          (when (> i 0)
            (incf cum sep-h))
          ;; Row top = figure-top - cumulative
          (setf (aref tops i) (- top cum))
          ;; Row bottom = top - cell_height
          (incf cum (nth i cell-heights))
          (setf (aref bottoms i) (- top cum))))
      ;; Build column positions: left-to-right
      (let ((cum 0.0d0))
        (dotimes (j ncols)
          (when (> j 0)
            (incf cum sep-w))
          (setf (aref lefts-vec j) (+ left cum))
          (incf cum (nth j cell-widths))
          (setf (aref rights-vec j) (+ left cum))))
      (values (coerce bottoms 'list)
              (coerce tops 'list)
              (coerce lefts-vec 'list)
              (coerce rights-vec 'list)))))

(defun gridspec-subplotspec (gs row col &key (rowspan 1) (colspan 1))
  "Create a SubplotSpec for the cell at ROW, COL (0-based).
ROWSPAN and COLSPAN specify how many rows/cols to span."
  (let* ((ncols (gridspec-ncols gs))
         (num1 (+ (* row ncols) col))
         (num2 (+ (* (+ row rowspan -1) ncols) (+ col colspan -1))))
    (make-subplot-spec gs num1 num2)))

(defmethod print-object ((gs gridspec) stream)
  (print-unreadable-object (gs stream :type t)
    (format stream "~Dx~D" (gridspec-nrows gs) (gridspec-ncols gs))))

;;; ============================================================
;;; GridSpecFromSubplotSpec — nested grid within a SubplotSpec cell
;;; ============================================================

(defclass gridspec-from-subplot-spec (gridspec-base)
  ((parent-subplot-spec :initarg :subplot-spec
                        :accessor gridspec-from-ss-parent
                        :documentation "Parent SubplotSpec that this grid lives within.")
   (nested-wspace :initarg :wspace
                  :initform nil
                  :accessor gridspec-from-ss-wspace
                  :documentation "Width spacing override.")
   (nested-hspace :initarg :hspace
                  :initform nil
                  :accessor gridspec-from-ss-hspace
                  :documentation "Height spacing override."))
  (:documentation "GridSpec whose layout parameters come from a parent SubplotSpec.
Used for creating sub-grids within individual subplot cells."))

(defun make-gridspec-from-subplot-spec (nrows ncols subplot-spec
                                        &key wspace hspace
                                             width-ratios height-ratios)
  "Create a nested GridSpec within SUBPLOT-SPEC.
The grid boundaries are determined by the parent SubplotSpec's position."
  (make-instance 'gridspec-from-subplot-spec
                 :nrows nrows :ncols ncols
                 :subplot-spec subplot-spec
                 :wspace wspace :hspace hspace
                 :width-ratios width-ratios
                 :height-ratios height-ratios))

(defmethod gridspec-get-subplot-params ((gs gridspec-from-subplot-spec) &optional figure)
  "Return subplot params derived from the parent SubplotSpec's position."
  (let* ((ss (gridspec-from-ss-parent gs))
         (parent-gs (subplotspec-gridspec ss))
         (fig (or figure
                  (when (typep parent-gs 'gridspec) (gridspec-figure parent-gs)))))
    ;; Get the position of the parent subplot spec in figure coords
    (let* ((pos (subplotspec-get-position ss fig))
           (pos-left (first pos))
           (pos-bottom (second pos))
           (pos-width (third pos))
           (pos-height (fourth pos))
           ;; Determine spacing
           (default-params (if fig
                               (figure-subplot-params fig)
                               (list :wspace 0.2d0 :hspace 0.2d0)))
           (ws (or (gridspec-from-ss-wspace gs)
                   (getf default-params :wspace)
                   0.2d0))
           (hs (or (gridspec-from-ss-hspace gs)
                   (getf default-params :hspace)
                   0.2d0)))
      (list :left (coerce pos-left 'double-float)
            :right (coerce (+ pos-left pos-width) 'double-float)
            :bottom (coerce pos-bottom 'double-float)
            :top (coerce (+ pos-bottom pos-height) 'double-float)
            :wspace (coerce ws 'double-float)
            :hspace (coerce hs 'double-float)))))

(defun gridspec-from-ss-get-topmost-subplotspec (gs)
  "Return the topmost SubplotSpec in the nesting chain."
  (let* ((ss (gridspec-from-ss-parent gs))
         (parent-gs (subplotspec-gridspec ss)))
    (if (typep parent-gs 'gridspec-from-subplot-spec)
        (gridspec-from-ss-get-topmost-subplotspec parent-gs)
        ss)))

;;; ============================================================
;;; subplots — create figure with NxM axes grid
;;; ============================================================

(defun subplots (figure nrows ncols &key (sharex nil) (sharey nil)
                                         (squeeze t) subplot-kw gridspec-kw
                                         (projection nil))
   "Create a grid of NROWSxNCOLS axes in FIGURE.

SHAREX — axis sharing for X: :all, :row, :col, :none, T (=:all), NIL (=:none).
SHAREY — axis sharing for Y: :all, :row, :col, :none, T (=:all), NIL (=:none).
SQUEEZE — if T, remove dimensions of size 1. If 1x1, return single axes.
SUBPLOT-KW — plist of extra args for axes creation.
GRIDSPEC-KW — plist of extra args for GridSpec creation.
PROJECTION — axes projection type (:polar for polar axes, NIL for rectangular).

Returns a 2D array of axes (or squeezed version)."
  (declare (ignore subplot-kw gridspec-kw))
  ;; Normalize sharex/sharey
  (let* ((sx (cond ((eq sharex t) :all)
                   ((eq sharex nil) :none)
                   ((member sharex '(:all :row :col :none)) sharex)
                   (t :none)))
         (sy (cond ((eq sharey t) :all)
                   ((eq sharey nil) :none)
                   ((member sharey '(:all :row :col :none)) sharey)
                   (t :none)))
         (gs (make-gridspec nrows ncols :figure figure))
         (axarr (make-array (list nrows ncols) :initial-element nil)))
    ;; Create axes for each cell
    (dotimes (row nrows)
      (dotimes (col ncols)
         (let* ((ss (gridspec-subplotspec gs row col))
                (pos (subplotspec-get-position ss figure))
                (ax (case projection
                      (:polar (make-instance 'polar-axes
                                             :figure figure
                                             :position pos
                                             :facecolor "white"
                                             :frameon t
                                             :zorder 0))
                      (otherwise (make-instance 'mpl-axes
                                                :figure figure
                                                :position pos
                                                :facecolor "white"
                                                :frameon t
                                                :zorder 0)))))
           ;; Add to figure
           (push ax (figure-axes figure))
           (setf (mpl.rendering:artist-figure ax) figure)
           (setf (mpl.rendering:artist-axes ax) ax)
           ;; Store in array
           (setf (aref axarr row col) ax))))
    ;; Set up shared axes
    (when (not (eq sx :none))
      (dotimes (row nrows)
        (dotimes (col ncols)
          (let ((ax (aref axarr row col))
                (share-target
                  (case sx
                    (:all (aref axarr 0 0))
                    (:row (aref axarr row 0))
                    (:col (aref axarr 0 col)))))
            (when (and share-target (not (eq ax share-target)))
              (axes-share-x ax share-target)))))
      ;; Suppress x-axis tick labels on non-bottom rows (label_outer behavior)
      (dotimes (row nrows)
        (dotimes (col ncols)
          (let ((ax (aref axarr row col)))
            (when (< row (1- nrows))
              ;; Not the bottom row: hide x-axis tick labels
              (setf (axis-tick-labels-visible-p
                     (axes-base-xaxis ax)) nil))))))
    (when (not (eq sy :none))
      (dotimes (row nrows)
        (dotimes (col ncols)
          (let ((ax (aref axarr row col))
                (share-target
                  (case sy
                    (:all (aref axarr 0 0))
                    (:row (aref axarr row 0))
                    (:col (aref axarr 0 col)))))
            (when (and share-target (not (eq ax share-target)))
              (axes-share-y ax share-target)))))
      ;; Suppress y-axis tick labels on non-left columns (label_outer behavior)
      (dotimes (row nrows)
        (dotimes (col ncols)
          (let ((ax (aref axarr row col)))
            (when (> col 0)
              ;; Not the leftmost column: hide y-axis tick labels
              (setf (axis-tick-labels-visible-p
                     (axes-base-yaxis ax)) nil))))))
    ;; Squeeze if requested
    (if squeeze
        (cond ((and (= nrows 1) (= ncols 1))
               (aref axarr 0 0))
              ((= nrows 1)
               ;; Return 1D array of ncols
               (let ((result (make-array ncols)))
                 (dotimes (j ncols) (setf (aref result j) (aref axarr 0 j)))
                 result))
              ((= ncols 1)
               ;; Return 1D array of nrows
               (let ((result (make-array nrows)))
                 (dotimes (i nrows) (setf (aref result i) (aref axarr i 0)))
                 result))
              (t axarr))
        axarr)))

;;; ============================================================
;;; subplot-mosaic — named layout from string/list pattern
;;; ============================================================

(defun subplot-mosaic (figure layout)
  "Create named subplot layout from LAYOUT specification.

LAYOUT is a vector of strings (or list of strings/lists).
Each unique character/name maps to one axes.
Repeated adjacent characters indicate spanning.

Example:
  #(\"AB\" \"CD\") → 2x2 grid with axes A, B, C, D
  #(\"AA\" \"BC\") → A spans top row, B and C in bottom
  '(\"AAB\" \"CDB\") → A spans cols 0-1 row 0, B spans col 2 rows 0-1, etc.

Returns a hash-table mapping name (character) → axes."
  (let* ((rows (coerce layout 'list))
         (nrows (length rows))
         (ncols (length (first rows)))
         (gs (make-gridspec nrows ncols :figure figure))
         (name-cells (make-hash-table :test 'equal))
         (result (make-hash-table :test 'equal)))
    ;; Parse layout to find cells for each name
    (dotimes (r nrows)
      (let ((row-spec (nth r rows)))
        (dotimes (c ncols)
          (let ((ch (string (char row-spec c))))
            (unless (string= ch ".")  ; "." means empty
              (push (cons r c) (gethash ch name-cells nil)))))))
    ;; For each name, compute the bounding rectangle and create axes
    (maphash
     (lambda (name cells)
       (let* ((rows-list (mapcar #'car cells))
              (cols-list (mapcar #'cdr cells))
              (min-row (reduce #'min rows-list))
              (max-row (reduce #'max rows-list))
              (min-col (reduce #'min cols-list))
              (max-col (reduce #'max cols-list))
              (rowspan (1+ (- max-row min-row)))
              (colspan (1+ (- max-col min-col)))
              (ss (gridspec-subplotspec gs min-row min-col
                                        :rowspan rowspan :colspan colspan))
              (pos (subplotspec-get-position ss figure))
              (ax (make-instance 'mpl-axes
                                 :figure figure
                                 :position pos
                                 :facecolor "white"
                                 :frameon t
                                 :zorder 0)))
         (push ax (figure-axes figure))
         (setf (mpl.rendering:artist-figure ax) figure)
         (setf (mpl.rendering:artist-axes ax) ax)
         (setf (gethash name result) ax)))
     name-cells)
    result))
