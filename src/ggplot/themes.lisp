;;;; themes.lisp — theme elements, merging, built-in themes

(in-package #:ggplot)

;;; ============================================================
;;; Theme elements
;;; ============================================================

(defstruct (element-blank (:constructor element-blank ()))
  "Draw nothing for this element.")

(defstruct (element-line (:constructor element-line
                             (&key color linewidth linetype)))
  color linewidth linetype)

(defstruct (element-rect (:constructor element-rect
                             (&key fill color linewidth)))
  fill color linewidth)

(defstruct (element-text (:constructor element-text
                             (&key size color weight style ha va)))
  size color weight style ha va)

;;; ============================================================
;;; Theme construction and merging
;;; ============================================================

(defparameter *theme-element-names*
  '(:panel-background :panel-border
    :panel-grid-major :panel-grid-minor
    :axis-line :axis-ticks :axis-ticks-length :axis-ticks-length-minor
    :axis-ticks-pad :axis-text :axis-text-x :axis-text-y
    :axis-title :axis-title-x :axis-title-y
    :plot-title :plot-background
    :legend-position :legend-background :legend-key
    :strip-background :strip-text
    :plot-margin-extra
    :base-size :base-family)
  "Recognized theme element names (grows with later slices).")

(defun theme (&rest pairs)
  "Construct a partial theme: (theme :panel-grid-minor (element-blank) ...).
Partial themes merge into the plot's theme; later values win."
  (let ((table (make-hash-table :test #'eq)))
    (loop for (name value) on pairs by #'cddr
          do (unless (member name *theme-element-names*)
               (error "Unknown theme element ~S. Known: ~{~S~^ ~}"
                      name *theme-element-names*))
             (setf (gethash name table) value))
    (make-instance 'ggtheme :elements table)))

(defun theme-element (theme name)
  (and theme (gethash name (theme-elements theme))))

(defun merge-themes (base overlay)
  "New theme with OVERLAY's elements taking precedence over BASE's."
  (cond ((null base) overlay)
        ((null overlay) base)
        (t (let ((table (make-hash-table :test #'eq)))
             (maphash (lambda (k v) (setf (gethash k table) v))
                      (theme-elements base))
             (maphash (lambda (k v) (setf (gethash k table) v))
                      (theme-elements overlay))
             (make-instance 'ggtheme :elements table)))))

;;; ============================================================
;;; Built-in themes
;;; ============================================================
;;; theme-gray is plotnine's default and the calibration target for the
;;; SSIM harness: panel #EBEBEB, white grid, no axis line, #333333 ticks,
;;; #4D4D4D axis text, base size 11.

(defun theme-gray (&key (base-size 11))
  (theme :base-size base-size
         :panel-background (element-rect :fill "#EBEBEB")
         :panel-grid-major (element-line :color "white" :linewidth 1.0)
         :panel-grid-minor (element-line :color "white" :linewidth 0.5)
         :axis-line (element-blank)
         :axis-ticks (element-line :color "#333333" :linewidth 1.0)
         :axis-text (element-text :size (* 0.8 base-size) :color "#4D4D4D")
         :axis-title (element-text :size base-size :color "black")
         :plot-title (element-text :size (* 1.2 base-size) :color "black")
         :plot-background (element-rect :fill "white")
         :legend-position :right))

(defun theme-grey (&key (base-size 11))
  (theme-gray :base-size base-size))

(defun theme-bw (&key (base-size 11))
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "white")
          :panel-border (element-rect :color "#333333" :linewidth 1.0)
          :panel-grid-major (element-line :color "#D9D9D9" :linewidth 0.8)
          :panel-grid-minor (element-line :color "#E5E5E5" :linewidth 0.4))))

(defun theme-minimal (&key (base-size 11))
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-blank)
          :panel-border (element-blank)
          :axis-ticks (element-blank)
          :panel-grid-major (element-line :color "#D9D9D9" :linewidth 0.8)
          :panel-grid-minor (element-line :color "#E5E5E5" :linewidth 0.4))))

(defvar *default-theme* nil
  "Theme used when a plot specifies none. NIL means (theme-gray).")

(defun theme-set (theme)
  "Set the default theme; returns the previous one."
  (prog1 *default-theme* (setf *default-theme* theme)))

(defun theme-get ()
  (or *default-theme* (theme-gray)))

;;; ============================================================
;;; Theme -> rc parameter mapping (stage 1 of application)
;;; ============================================================

(defun %element-color (element default)
  (typecase element
    (element-line (or (element-line-color element) default))
    (element-rect (or (element-rect-fill element) default))
    (element-text (or (element-text-color element) default))
    (t default)))

(defun theme-rc-alist (theme)
  "Translate THEME into an alist of rc parameter overrides applied around
figure creation. Elements rc can't express are handled per-axes in render."
  (let ((alist '())
        (base-size (or (theme-element theme :base-size) 11)))
    (flet ((add (key value) (when value (push (cons key value) alist))))
      (let ((panel (theme-element theme :panel-background)))
        (typecase panel
          (element-rect (add "axes.facecolor" (element-rect-fill panel)))
          (element-blank (add "axes.facecolor" "white"))))
      (let ((grid (theme-element theme :panel-grid-major)))
        (typecase grid
          (element-line
           (add "grid.color" (element-line-color grid))
           (add "grid.linewidth" (element-line-linewidth grid)))
          (element-blank (add "axes.grid" nil))))
      (let ((ticks (theme-element theme :axis-ticks)))
        (typecase ticks
          (element-line
           (add "xtick.color" (element-line-color ticks))
           (add "ytick.color" (element-line-color ticks)))))
      (let ((text (theme-element theme :axis-text)))
        (typecase text
          (element-text
           (add "xtick.labelsize" (element-text-size text))
           (add "ytick.labelsize" (element-text-size text)))))
      (add "font.size" base-size)
      (add "figure.facecolor"
           (%element-color (theme-element theme :plot-background) "white")))
    (nreverse alist)))

;;; ============================================================
;;; More built-in themes
;;; ============================================================

(defun theme-classic (&key (base-size 11))
  "White panel, black axis lines, no grid."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "white")
          :panel-grid-major (element-blank)
          :panel-grid-minor (element-blank)
          :axis-line (element-line :color "black" :linewidth 1.0))))

(defun theme-dark (&key (base-size 11))
  "Dark panel for thin colored lines to pop."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "#7F7F7F")
          :panel-grid-major (element-line :color "#666666" :linewidth 1.0)
          :panel-grid-minor (element-line :color "#737373" :linewidth 0.5))))

(defun theme-void (&key (base-size 11))
  "Nothing but the data layers."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-blank)
          :panel-grid-major (element-blank)
          :panel-grid-minor (element-blank)
          :axis-line (element-blank)
          :axis-ticks (element-blank)
          :axis-text (element-blank)
          :axis-title (element-blank))))

;;; ============================================================
;;; plotnine parity themes (element values from plotnine's themeable
;;; properties + pixel measurements of its renders)
;;; ============================================================

(defun theme-538 (&key (base-size 11))
  "FiveThirtyEight: everything #F0F0F0, strong gray grid, no ticks."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "#F0F0F0")
          :plot-background (element-rect :fill "#F0F0F0")
          :panel-grid-major (element-line :color "#D5D5D5" :linewidth 1.0)
          :panel-grid-minor (element-blank)
          :axis-ticks (element-blank))))

(defun theme-light (&key (base-size 11))
  "White panel with a light gray border and grid."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "white")
          :panel-border (element-rect :color "#B3B3B3" :linewidth 1.0)
          :panel-grid-major (element-line :color "#D9D9D9" :linewidth 0.5)
          :panel-grid-minor (element-line :color "#EDEDED" :linewidth 0.25)
          :axis-ticks (element-line :color "#B3B3B3" :linewidth 0.5))))

(defun theme-linedraw (&key (base-size 11))
  "Black-and-white line drawing: black border, hairline black grid."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "white")
          :panel-border (element-rect :color "black" :linewidth 1.0)
          :panel-grid-major (element-line :color "black" :linewidth 0.1)
          :panel-grid-minor (element-line :color "black" :linewidth 0.02)
          :axis-ticks (element-line :color "black" :linewidth 0.5)
          :axis-text (element-text :size (* 0.8 base-size) :color "black"))))

(defun theme-matplotlib (&key (base-size 10))
  "matplotlib's default look: white panel, black box, no grid; matplotlib
text sizes (base 10) and tick geometry (3.5px ticks, 3.5px pad). The
margin extras are measured against plotnine's render - its matplotlib
theme follows mpl's layout, not the gg base-size scaling."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "white")
          :panel-border (element-rect :color "black" :linewidth 0.8)
          :panel-grid-major (element-blank)
          :panel-grid-minor (element-blank)
          :axis-ticks-length 3.5d0
          :axis-ticks-pad 3.5d0
          :plot-margin-extra '(:left 1.5d0 :top 3.0d0 :bottom 4.5d0)
          :axis-text (element-text :size base-size :color "black"))))

(defun theme-seaborn (&key (base-size 12))
  "Seaborn darkgrid: #EAEAF2 panel, white grid, seaborn's longer tick
marks (major 6px, minor 3px, pad 7) and base text size 12."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-rect :fill "#EAEAF2")
          :panel-grid-major (element-line :color "white" :linewidth 1.0)
          :panel-grid-minor (element-line :color "white" :linewidth 0.5)
          :axis-ticks (element-line :color "#262626" :linewidth 1.0)
          :axis-ticks-length 6.0d0
          :axis-ticks-length-minor 3.0d0
          :axis-ticks-pad 7.0d0
          :axis-text (element-text :size (* 0.8 base-size)
                                   :color "#262626"))))

(defun theme-tufte (&key (base-size 11))
  "Maximal data-ink: no panel, no grid, no border; ticks only."
  (merge-themes
   (theme-gray :base-size base-size)
   (theme :panel-background (element-blank)
          :plot-background (element-rect :fill "white")
          :panel-grid-major (element-blank)
          :panel-grid-minor (element-blank)
          :axis-ticks (element-line :color "#333333" :linewidth 1.0))))
