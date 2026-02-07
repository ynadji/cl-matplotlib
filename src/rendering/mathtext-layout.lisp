;;;; mathtext-layout.lisp — Box layout engine for mathtext
;;;; Ported from matplotlib's _mathtext.py (Node, Box, Hlist, Vlist, Kern, Glue)
;;;; Implements TeX's box model for mathematical typesetting.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Node — Base class for all TeX box model elements
;;; ============================================================

(defclass mt-node ()
  ((size :initform 0 :accessor mt-node-size
         :documentation "Shrink level (0=normal, 1=script, 2=scriptscript)"))
  (:documentation "A node in the TeX box model."))

(defgeneric mt-node-shrink (node)
  (:documentation "Shrink node one level smaller (for sub/superscripts)."))

(defgeneric mt-node-render (node output x y)
  (:documentation "Render this node into OUTPUT at position (X, Y)."))

(defgeneric mt-node-get-kerning (node next)
  (:documentation "Return kerning distance between this node and NEXT."))

(defmethod mt-node-shrink ((node mt-node))
  (incf (mt-node-size node)))

(defmethod mt-node-render ((node mt-node) output x y)
  (declare (ignore output x y))
  nil)

(defmethod mt-node-get-kerning ((node mt-node) next)
  (declare (ignore next))
  0.0d0)

;;; ============================================================
;;; Box — A node with width, height, depth
;;; ============================================================

(defclass mt-box (mt-node)
  ((width  :initarg :width  :initform 0.0d0 :accessor mt-box-width)
   (height :initarg :height :initform 0.0d0 :accessor mt-box-height)
   (depth  :initarg :depth  :initform 0.0d0 :accessor mt-box-depth))
  (:documentation "A box with physical dimensions."))

(defmethod mt-node-shrink ((box mt-box))
  (call-next-method)
  (when (< (mt-node-size box) +num-size-levels+)
    (setf (mt-box-width box)  (* (mt-box-width box) +shrink-factor+)
          (mt-box-height box) (* (mt-box-height box) +shrink-factor+)
          (mt-box-depth box)  (* (mt-box-depth box) +shrink-factor+))))

;;; ============================================================
;;; Hbox — Box with only width (zero height and depth)
;;; ============================================================

(defclass mt-hbox (mt-box)
  ()
  (:documentation "A box with only width."))

(defun make-mt-hbox (width)
  (make-instance 'mt-hbox :width (float width 1.0d0) :height 0.0d0 :depth 0.0d0))

;;; ============================================================
;;; Vbox — Box with only height (zero width)
;;; ============================================================

(defclass mt-vbox (mt-box)
  ()
  (:documentation "A box with only height."))

(defun make-mt-vbox (height depth)
  (make-instance 'mt-vbox :width 0.0d0 :height (float height 1.0d0) :depth (float depth 1.0d0)))

;;; ============================================================
;;; Kern — Fixed spacing node
;;; ============================================================

(defclass mt-kern (mt-node)
  ((width :initarg :width :initform 0.0d0 :accessor mt-kern-width))
  (:documentation "Fixed horizontal or vertical spacing."))

(defun make-mt-kern (width)
  (make-instance 'mt-kern :width (float width 1.0d0)))

(defmethod mt-node-shrink ((kern mt-kern))
  (call-next-method)
  (when (< (mt-node-size kern) +num-size-levels+)
    (setf (mt-kern-width kern) (* (mt-kern-width kern) +shrink-factor+))))

;;; ============================================================
;;; Glue — Stretchable/shrinkable spacing
;;; ============================================================

(defstruct (glue-spec (:constructor make-glue-spec (width stretch stretch-order shrink shrink-order)))
  "Specification for glue dimensions."
  (width         0.0d0 :type double-float)
  (stretch       0.0d0 :type double-float)
  (stretch-order 0     :type fixnum)
  (shrink        0.0d0 :type double-float)
  (shrink-order  0     :type fixnum))

(defvar *named-glue-specs*
  (let ((ht (make-hash-table :test 'eq)))
    (setf (gethash :fil ht)       (make-glue-spec 0.0d0 1.0d0 1 0.0d0 0)
          (gethash :fill ht)      (make-glue-spec 0.0d0 1.0d0 2 0.0d0 0)
          (gethash :filll ht)     (make-glue-spec 0.0d0 1.0d0 3 0.0d0 0)
          (gethash :neg-fil ht)   (make-glue-spec 0.0d0 0.0d0 0 1.0d0 1)
          (gethash :neg-fill ht)  (make-glue-spec 0.0d0 0.0d0 0 1.0d0 2)
          (gethash :neg-filll ht) (make-glue-spec 0.0d0 0.0d0 0 1.0d0 3)
          (gethash :empty ht)     (make-glue-spec 0.0d0 0.0d0 0 0.0d0 0)
          (gethash :ss ht)        (make-glue-spec 0.0d0 1.0d0 1 -1.0d0 1))
    ht)
  "Named glue specifications matching TeX's built-in glue types.")

(defclass mt-glue (mt-node)
  ((glue-spec :initarg :glue-spec :accessor mt-glue-spec))
  (:documentation "Stretchable/shrinkable spacing."))

(defun make-mt-glue (glue-type)
  "Create a glue node. GLUE-TYPE can be a keyword (:fil, :fill, :ss, etc.)
or a glue-spec struct."
  (let ((spec (if (keywordp glue-type)
                  (or (gethash glue-type *named-glue-specs*)
                      (error "Unknown glue type: ~A" glue-type))
                  glue-type)))
    (make-instance 'mt-glue :glue-spec spec)))

(defmethod mt-node-shrink ((glue mt-glue))
  (call-next-method)
  (when (< (mt-node-size glue) +num-size-levels+)
    (let ((g (mt-glue-spec glue)))
      (setf (mt-glue-spec glue)
            (make-glue-spec (* (glue-spec-width g) +shrink-factor+)
                            (glue-spec-stretch g)
                            (glue-spec-stretch-order g)
                            (glue-spec-shrink g)
                            (glue-spec-shrink-order g))))))

;;; ============================================================
;;; List — Base for Hlist and Vlist
;;; ============================================================

(defclass mt-list (mt-box)
  ((shift-amount :initform 0.0d0 :accessor mt-list-shift-amount
                 :documentation "Vertical offset from baseline.")
   (children     :initarg :children :initform nil :accessor mt-list-children
                 :documentation "Child nodes.")
   (glue-set     :initform 0.0d0 :accessor mt-list-glue-set)
   (glue-sign    :initform 0     :accessor mt-list-glue-sign
                 :documentation "0=normal, -1=shrinking, 1=stretching.")
   (glue-order   :initform 0     :accessor mt-list-glue-order))
  (:documentation "A list of nodes."))

(defun %set-glue (list-node x sign totals)
  "Compute glue settings for LIST-NODE with excess X."
  (let ((o (loop for i from (1- (length totals)) downto 0
                 when (/= (nth i totals) 0.0d0)
                 return i
                 finally (return 0))))
    (setf (mt-list-glue-order list-node) o
          (mt-list-glue-sign list-node) sign)
    (if (/= (nth o totals) 0.0d0)
        (setf (mt-list-glue-set list-node) (/ x (nth o totals)))
        (setf (mt-list-glue-sign list-node) 0))))

(defmethod mt-node-shrink ((lst mt-list))
  (dolist (child (mt-list-children lst))
    (mt-node-shrink child))
  (call-next-method)
  (when (< (mt-node-size lst) +num-size-levels+)
    (setf (mt-list-shift-amount lst) (* (mt-list-shift-amount lst) +shrink-factor+)
          (mt-list-glue-set lst)     (* (mt-list-glue-set lst) +shrink-factor+))))

;;; ============================================================
;;; Char — A single character with font info
;;; ============================================================

(defclass mt-char (mt-node)
  ((c          :initarg :c          :accessor mt-char-c
               :documentation "The character or TeX symbol string.")
   (font-loader :initarg :font-loader :accessor mt-char-font-loader
                :documentation "zpb-ttf font-loader for this character.")
   (fontsize    :initarg :fontsize    :accessor mt-char-fontsize
                :documentation "Font size in points.")
   (width       :initform 0.0d0 :accessor mt-char-width)
   (height      :initform 0.0d0 :accessor mt-char-height)
   (depth       :initform 0.0d0 :accessor mt-char-depth)
   (advance     :initform 0.0d0 :accessor mt-char-advance)
   (italic-p    :initform nil   :accessor mt-char-italic-p
                :documentation "Whether this character should be slanted."))
  (:documentation "A single character node with font metrics."))

(defun %update-char-metrics (char-node)
  "Compute width/height/depth for a character node using zpb-ttf."
  (let* ((font-loader (mt-char-font-loader char-node))
         (fontsize (mt-char-fontsize char-node))
         (c (mt-char-c char-node))
         (units-per-em (zpb-ttf:units/em font-loader))
         (scale (/ fontsize (float units-per-em 1.0d0)))
         (char-code (if (characterp c)
                        (char-code c)
                        ;; For TeX symbols, look up unicode
                        (or (gethash (if (and (stringp c) (> (length c) 0)
                                             (char= (char c 0) #\\))
                                        (subseq c 1) c)
                                     *tex2uni*)
                            (if (and (stringp c) (= (length c) 1))
                                (char-code (char c 0))
                                (char-code #\?)))))
         (glyph (zpb-ttf:find-glyph char-code font-loader)))
    (if glyph
        (let* ((bbox (zpb-ttf:bounding-box glyph))
               (ymin (* (float (zpb-ttf:ymin bbox) 1.0d0) scale))
               (ymax (* (float (zpb-ttf:ymax bbox) 1.0d0) scale))
               (adv (* (float (zpb-ttf:advance-width glyph) 1.0d0) scale))
               (w (* (float (- (zpb-ttf:xmax bbox) (zpb-ttf:xmin bbox)) 1.0d0) scale)))
          (setf (mt-char-width char-node) (max w adv)
                (mt-char-height char-node) (max 0.0d0 ymax)
                (mt-char-depth char-node) (max 0.0d0 (- ymin))
                (mt-char-advance char-node) adv))
        ;; Fallback for missing glyphs — use space-like dimensions
        (let ((adv (* 0.5d0 fontsize)))
          (setf (mt-char-width char-node) adv
                (mt-char-height char-node) (* 0.7d0 fontsize)
                (mt-char-depth char-node) 0.0d0
                (mt-char-advance char-node) adv)))))

(defun make-mt-char (c font-loader fontsize &key italic-p)
  "Create a character node for character/symbol C."
  (let ((node (make-instance 'mt-char
                             :c c
                             :font-loader font-loader
                             :fontsize (float fontsize 1.0d0))))
    (setf (mt-char-italic-p node) italic-p)
    (%update-char-metrics node)
    node))

(defmethod mt-node-get-kerning ((char mt-char) next)
  (let ((advance-kern (- (mt-char-advance char) (mt-char-width char))))
    (if (typep next 'mt-char)
        ;; Attempt kerning between consecutive chars
        (let* ((fl (mt-char-font-loader char))
               (c1 (mt-char-c char))
               (c2 (mt-char-c next))
               (g1 (when (characterp c1) (zpb-ttf:find-glyph (char-code c1) fl)))
               (g2 (when (characterp c2) (zpb-ttf:find-glyph (char-code c2) fl)))
               (kern (if (and g1 g2)
                         (let ((k (zpb-ttf:kerning-offset g1 g2 fl)))
                           (if k
                               (let* ((units-per-em (zpb-ttf:units/em fl))
                                      (scale (/ (mt-char-fontsize char)
                                                (float units-per-em 1.0d0))))
                                 (* (float k 1.0d0) scale))
                               0.0d0))
                         0.0d0)))
          (+ advance-kern kern))
        advance-kern)))

(defmethod mt-node-shrink ((char mt-char))
  (call-next-method)
  (when (< (mt-node-size char) +num-size-levels+)
    (setf (mt-char-fontsize char) (* (mt-char-fontsize char) +shrink-factor+)
          (mt-char-width char)    (* (mt-char-width char) +shrink-factor+)
          (mt-char-height char)   (* (mt-char-height char) +shrink-factor+)
          (mt-char-depth char)    (* (mt-char-depth char) +shrink-factor+)
          (mt-char-advance char)  (* (mt-char-advance char) +shrink-factor+))))

(defmethod mt-node-render ((char mt-char) output x y)
  "Render a character by adding it to the output glyph list."
  (push (list :glyph
              :x x :y y
              :char (mt-char-c char)
              :font-loader (mt-char-font-loader char)
              :fontsize (mt-char-fontsize char))
        (gethash :glyphs output)))

;;; ============================================================
;;; Rule — A solid black rectangle (fraction bar, sqrt bar)
;;; ============================================================

(defclass mt-rule (mt-box)
  ()
  (:documentation "A solid black rectangle used for fraction bars, etc."))

(defun make-mt-rule (width height depth)
  "Create a rule (filled rectangle)."
  (make-instance 'mt-rule
                 :width (float width 1.0d0)
                 :height (float height 1.0d0)
                 :depth (float depth 1.0d0)))

(defmethod mt-node-render ((rule mt-rule) output x y)
  "Render a rule by adding a rectangle to the output."
  (let ((w (mt-box-width rule))
        (h (mt-box-height rule))
        (d (mt-box-depth rule)))
    (when (and (> w 0.0d0) (> (+ h d) 0.0d0))
      (push (list :rect :x x :y (- y d) :width w :height (+ h d))
            (gethash :rects output)))))

;;; ============================================================
;;; Hrule — Horizontal rule (fraction bar)
;;; ============================================================

(defun make-mt-hrule (fontsize &optional thickness)
  "Create a horizontal rule at the given fontsize."
  (let ((th (or thickness (* fontsize +fraction-rule-thickness+))))
    ;; Width is infinite — will be set by containing hlist
    (make-mt-rule most-positive-double-float (* th 0.5d0) (* th 0.5d0))))

;;; ============================================================
;;; Hlist — Horizontal list of boxes
;;; ============================================================

(defclass mt-hlist (mt-list)
  ()
  (:documentation "A horizontal list of boxes."))

(defun %kern-hlist (hlist)
  "Insert kern nodes between consecutive chars for kerning."
  (let ((new-children nil))
    (loop for (elem0 elem1) on (mt-list-children hlist)
          do (push elem0 new-children)
             (let ((kern-dist (mt-node-get-kerning elem0 elem1)))
               (when (/= kern-dist 0.0d0)
                 (push (make-mt-kern kern-dist) new-children))))
    (setf (mt-list-children hlist) (nreverse new-children))))

(defun %hpack (hlist &key (w 0.0d0) (m :additional))
  "Compute dimensions of an Hlist, adjusting glue as needed.
W is additional or exact width. M is :additional or :exactly."
  (let ((h 0.0d0)
        (d 0.0d0)
        (x 0.0d0)
        (total-stretch (list 0.0d0 0.0d0 0.0d0 0.0d0))
        (total-shrink (list 0.0d0 0.0d0 0.0d0 0.0d0)))
    (dolist (p (mt-list-children hlist))
      (typecase p
        (mt-char
         (incf x (mt-char-width p))
         (setf h (max h (mt-char-height p)))
         (setf d (max d (mt-char-depth p))))
        (mt-list
         (incf x (mt-box-width p))
         (let ((s (mt-list-shift-amount p)))
           (setf h (max h (- (mt-box-height p) s)))
           (setf d (max d (+ (mt-box-depth p) s)))))
        (mt-box
         (incf x (mt-box-width p))
         (setf h (max h (mt-box-height p)))
         (setf d (max d (mt-box-depth p))))
        (mt-glue
         (let ((gs (mt-glue-spec p)))
           (incf x (glue-spec-width gs))
           (incf (nth (glue-spec-stretch-order gs) total-stretch)
                 (glue-spec-stretch gs))
           (incf (nth (glue-spec-shrink-order gs) total-shrink)
                 (glue-spec-shrink gs))))
        (mt-kern
         (incf x (mt-kern-width p)))))
    (setf (mt-box-height hlist) h
          (mt-box-depth hlist) d)
    (when (eq m :additional)
      (incf w x))
    (setf (mt-box-width hlist) w)
    (let ((excess (- w x)))
      (cond
        ((= excess 0.0d0)
         (setf (mt-list-glue-sign hlist) 0
               (mt-list-glue-order hlist) 0
               (mt-list-glue-set hlist) 0.0d0))
        ((> excess 0.0d0)
         (%set-glue hlist excess 1 total-stretch))
        (t
         (%set-glue hlist excess -1 total-shrink))))))

(defun make-mt-hlist (elements &key (w 0.0d0) (m :additional) (do-kern t))
  "Create a horizontal list of elements."
  (let ((hlist (make-instance 'mt-hlist :children (copy-list elements))))
    (when do-kern
      (%kern-hlist hlist))
    (%hpack hlist :w w :m m)
    hlist))

;;; ============================================================
;;; Vlist — Vertical list of boxes
;;; ============================================================

(defclass mt-vlist (mt-list)
  ()
  (:documentation "A vertical list of boxes."))

(defun %vpack (vlist &key (h 0.0d0) (m :additional))
  "Compute dimensions of a Vlist."
  (let ((w 0.0d0)
        (d 0.0d0)
        (x 0.0d0)
        (total-stretch (list 0.0d0 0.0d0 0.0d0 0.0d0))
        (total-shrink (list 0.0d0 0.0d0 0.0d0 0.0d0)))
    (dolist (p (mt-list-children vlist))
      (typecase p
        (mt-list
         (incf x (+ d (mt-box-height p)))
         (setf d (mt-box-depth p))
         (let ((s (mt-list-shift-amount p)))
           (setf w (max w (+ (mt-box-width p) s)))))
        (mt-box
         (incf x (+ d (mt-box-height p)))
         (setf d (mt-box-depth p))
         (setf w (max w (mt-box-width p))))
        (mt-glue
         (incf x d)
         (setf d 0.0d0)
         (let ((gs (mt-glue-spec p)))
           (incf x (glue-spec-width gs))
           (incf (nth (glue-spec-stretch-order gs) total-stretch)
                 (glue-spec-stretch gs))
           (incf (nth (glue-spec-shrink-order gs) total-shrink)
                 (glue-spec-shrink gs))))
        (mt-kern
         (incf x (+ d (mt-kern-width p)))
         (setf d 0.0d0))))
    (setf (mt-box-width vlist) w
          (mt-box-depth vlist) d)
    (when (eq m :additional)
      (incf h x))
    (setf (mt-box-height vlist) h)
    (let ((excess (- h x)))
      (cond
        ((= excess 0.0d0)
         (setf (mt-list-glue-sign vlist) 0
               (mt-list-glue-order vlist) 0
               (mt-list-glue-set vlist) 0.0d0))
        ((> excess 0.0d0)
         (%set-glue vlist excess 1 total-stretch))
        (t
         (%set-glue vlist excess -1 total-shrink))))))

(defun make-mt-vlist (elements &key (h 0.0d0) (m :additional))
  "Create a vertical list of elements."
  (let ((vlist (make-instance 'mt-vlist :children (copy-list elements))))
    (%vpack vlist :h h :m m)
    vlist))

;;; ============================================================
;;; HCentered — Horizontally centered content
;;; ============================================================

(defun make-mt-hcentered (elements)
  "Create an hlist with centered contents."
  (make-mt-hlist (append (list (make-mt-glue :ss))
                         elements
                         (list (make-mt-glue :ss)))
                 :do-kern nil))

;;; ============================================================
;;; ship — Convert box tree to positioned glyphs and rects
;;; ============================================================

(defun mt-ship (box &key (ox 0.0d0) (oy 0.0d0))
  "Ship out BOX, converting it to positioned glyphs and rectangles.
Returns a hash-table with :glyphs and :rects keys containing lists."
  (let ((output (make-hash-table :test 'eq))
        (cur-v 0.0d0)
        (cur-h 0.0d0)
        (off-h ox)
        (off-v (+ oy (if (typep box 'mt-box) (mt-box-height box) 0.0d0))))
    (setf (gethash :glyphs output) nil
          (gethash :rects output) nil
          (gethash :width output) (if (typep box 'mt-box) (mt-box-width box) 0.0d0)
          (gethash :height output) (if (typep box 'mt-box) (mt-box-height box) 0.0d0)
          (gethash :depth output) (if (typep box 'mt-box) (mt-box-depth box) 0.0d0))
    (labels
        ((clamp-val (v)
           (cond ((< v -1.0d9) -1.0d9)
                 ((> v 1.0d9) 1.0d9)
                 (t v)))
         (hlist-out (box)
           (let ((cur-g 0)
                 (cur-glue 0.0d0)
                 (glue-order (mt-list-glue-order box))
                 (glue-sign (mt-list-glue-sign box))
                 (base-line cur-v))
             (dolist (p (mt-list-children box))
               (typecase p
                 (mt-char
                  (mt-node-render p output (+ cur-h off-h) (+ cur-v off-v))
                  (incf cur-h (mt-char-width p)))
                 (mt-kern
                  (incf cur-h (mt-kern-width p)))
                 (mt-list
                  (if (null (mt-list-children p))
                      (incf cur-h (mt-box-width p))
                      (let ((edge cur-h))
                        (setf cur-v (+ base-line (mt-list-shift-amount p)))
                        (if (typep p 'mt-hlist)
                            (hlist-out p)
                            (vlist-out p))
                        (setf cur-h (+ edge (mt-box-width p))
                              cur-v base-line))))
                 (mt-rule
                  (let ((rw (mt-box-width p))
                        (rh (mt-box-height p))
                        (rd (mt-box-depth p)))
                    ;; Handle infinite dimensions
                    (when (> rw 1.0d8)
                      (setf rw (mt-box-width box)))
                    (when (> rh 1.0d8)
                      (setf rh (mt-box-height box)))
                    (when (> rd 1.0d8)
                      (setf rd (mt-box-depth box)))
                    (when (and (> rh 0.0d0) (> rw 0.0d0))
                      (let ((ry (+ base-line rd)))
                        (mt-node-render p output (+ cur-h off-h) (+ ry off-v))))
                    (incf cur-h rw)))
                 (mt-box
                  (let ((rw (mt-box-width p))
                        (rh (mt-box-height p))
                        (rd (mt-box-depth p)))
                    (when (> rw 1.0d8)
                      (setf rw (mt-box-width box)))
                    (when (> rh 1.0d8)
                      (setf rh (mt-box-height box)))
                    (when (> rd 1.0d8)
                      (setf rd (mt-box-depth box)))
                    (when (and (> rh 0.0d0) (> rw 0.0d0))
                      (let ((ry (+ base-line rd)))
                        (push (list :rect :x (+ cur-h off-h) :y (+ ry off-v)
                                    :width rw :height (+ rh rd))
                              (gethash :rects output))))
                    (incf cur-h rw)))
                 (mt-glue
                  (let* ((gs (mt-glue-spec p))
                         (rule-width (- (glue-spec-width gs) cur-g)))
                    (when (/= glue-sign 0)
                      (cond
                        ((and (= glue-sign 1)
                              (= (glue-spec-stretch-order gs) glue-order))
                         (incf cur-glue (glue-spec-stretch gs))
                         (setf cur-g (round (clamp-val
                                             (* (mt-list-glue-set box) cur-glue)))))
                        ((and (= glue-sign -1)
                              (= (glue-spec-shrink-order gs) glue-order))
                         (incf cur-glue (glue-spec-shrink gs))
                         (setf cur-g (round (clamp-val
                                             (* (mt-list-glue-set box) cur-glue)))))))
                    (incf rule-width cur-g)
                    (incf cur-h rule-width)))))))
         (vlist-out (box)
           (let ((cur-g 0)
                 (cur-glue 0.0d0)
                 (glue-order (mt-list-glue-order box))
                 (glue-sign (mt-list-glue-sign box))
                 (left-edge cur-h))
             (decf cur-v (mt-box-height box))
             (dolist (p (mt-list-children box))
               (typecase p
                 (mt-kern
                  (incf cur-v (mt-kern-width p)))
                 (mt-list
                  (if (null (mt-list-children p))
                      (incf cur-v (+ (mt-box-height p) (mt-box-depth p)))
                      (progn
                        (incf cur-v (mt-box-height p))
                        (setf cur-h (+ left-edge (mt-list-shift-amount p)))
                        (let ((save-v cur-v))
                          (setf (mt-box-width p) (mt-box-width box))
                          (if (typep p 'mt-hlist)
                              (hlist-out p)
                              (vlist-out p))
                          (setf cur-v (+ save-v (mt-box-depth p))
                                cur-h left-edge)))))
                 (mt-box
                  (let ((rh (mt-box-height p))
                        (rd (mt-box-depth p))
                        (rw (mt-box-width p)))
                    (when (> rw 1.0d8)
                      (setf rw (mt-box-width box)))
                    (incf cur-v (+ rh rd))
                    (when (and (> rh 0.0d0) (> rd 0.0d0))
                      (push (list :rect :x (+ cur-h off-h) :y (+ cur-v off-v)
                                  :width rw :height (+ rh rd))
                            (gethash :rects output)))))
                 (mt-glue
                  (let* ((gs (mt-glue-spec p))
                         (rule-height (- (glue-spec-width gs) cur-g)))
                    (when (/= glue-sign 0)
                      (cond
                        ((and (= glue-sign 1)
                              (= (glue-spec-stretch-order gs) glue-order))
                         (incf cur-glue (glue-spec-stretch gs))
                         (setf cur-g (round (clamp-val
                                             (* (mt-list-glue-set box) cur-glue)))))
                        ((and (= glue-sign -1)
                              (= (glue-spec-shrink-order gs) glue-order))
                         (incf cur-glue (glue-spec-shrink gs))
                         (setf cur-g (round (clamp-val
                                             (* (mt-list-glue-set box) cur-glue)))))))
                    (incf rule-height cur-g)
                    (incf cur-v rule-height))))))))
      ;; Ship the top-level box
      (when (typep box 'mt-hlist)
        (hlist-out box))
      (when (typep box 'mt-vlist)
        (vlist-out box)))
    ;; Reverse to get correct order
    (setf (gethash :glyphs output) (nreverse (gethash :glyphs output))
          (gethash :rects output) (nreverse (gethash :rects output)))
    output))
