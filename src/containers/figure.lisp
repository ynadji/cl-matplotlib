;;;; figure.lisp — Figure class, FigureCanvas, and savefig pipeline
;;;; Ported from matplotlib's figure.py
;;;; Connects Figure → Canvas → Renderer → Backend pipeline.

(in-package #:cl-matplotlib.containers)

;;; ============================================================
;;; Figure class — top-level container for all plot elements
;;; ============================================================

(defclass mpl-figure (mpl.rendering:artist)
  ((figsize :initarg :figsize
            :initform '(6.4d0 4.8d0)
            :accessor figure-figsize
            :documentation "Figure size as (width height) in inches.")
   (dpi :initarg :dpi
        :initform 100.0d0
        :accessor figure-dpi
        :type double-float
        :documentation "Dots per inch for the figure.")
   (facecolor :initarg :facecolor
              :initform "white"
              :accessor figure-facecolor
              :documentation "Background face color of the figure rectangle.")
   (edgecolor :initarg :edgecolor
              :initform "white"
              :accessor figure-edgecolor
              :documentation "Edge color of the figure rectangle.")
   (linewidth-val :initarg :linewidth
                  :initform 0.0d0
                  :accessor figure-linewidth
                  :documentation "Line width of the figure frame.")
   (frameon :initarg :frameon
            :initform t
            :accessor figure-frameon-p
            :type boolean
            :documentation "Whether to draw the figure background.")
   (fig-axes :initform nil
             :accessor figure-axes
             :documentation "List of Axes objects in this figure.")
   (fig-artists :initform nil
                :accessor figure-artists
                :documentation "List of extra artists added to the figure.")
   (fig-lines :initform nil
              :accessor figure-lines
              :documentation "List of Line2D artists.")
   (fig-patches :initform nil
                :accessor figure-patches
                :documentation "List of Patch artists.")
   (fig-texts :initform nil
              :accessor figure-texts
              :documentation "List of Text artists.")
   (fig-images :initform nil
               :accessor figure-images
               :documentation "List of image artists.")
   (fig-legends :initform nil
                :accessor figure-legends
                :documentation "List of legend artists.")
   (subfigs :initform nil
            :accessor figure-subfigs
            :documentation "List of SubFigure instances.")
   (canvas :initform nil
           :accessor figure-canvas
           :documentation "The FigureCanvas attached to this figure.")
   (layout-engine :initform nil
                  :accessor figure-layout-engine
                  :documentation "Layout engine instance (or nil).")
   (subplot-params :initform nil
                   :accessor figure-subplot-params
                   :documentation "Subplot adjustment parameters plist: left right top bottom wspace hspace.")
   (suptitle :initform nil
             :accessor figure-suptitle-artist
             :documentation "Text artist for the figure super title.")
   (patch :initform nil
          :accessor figure-patch
          :documentation "Rectangle patch for the figure background."))
  (:documentation "Top level container for all plot elements.
Ported from matplotlib.figure.Figure. Holds axes, artists, patches, etc.
The figure connects to a canvas which connects to a renderer for output."))

;;; ============================================================
;;; Figure initialization
;;; ============================================================

(defun make-figure (&key (figsize '(6.4d0 4.8d0)) (dpi 100) (facecolor "white")
                         (edgecolor "white") (linewidth 0.0) (frameon t)
                         layout)
  "Create a new figure with the given parameters.

FIGSIZE — (width height) in inches, default (6.4 4.8).
DPI — dots per inch, default 100.
FACECOLOR — background color, default white.
EDGECOLOR — frame edge color, default white.
LINEWIDTH — frame line width, default 0.
FRAMEON — whether to draw background, default T.
LAYOUT — layout engine: :tight, :none, or a layout-engine instance."
  (let* ((w (coerce (first figsize) 'double-float))
         (h (coerce (second figsize) 'double-float))
         (dpi-val (coerce dpi 'double-float))
         (fig (make-instance 'mpl-figure
                             :figsize (list w h)
                             :dpi dpi-val
                             :facecolor facecolor
                             :edgecolor edgecolor
                             :linewidth (coerce linewidth 'double-float)
                             :frameon frameon)))
    ;; Create the background patch (a rectangle covering the whole figure)
    (setf (figure-patch fig)
          (make-instance 'mpl.rendering:rectangle
                         :x0 0.0d0 :y0 0.0d0
                         :width 1.0d0 :height 1.0d0
                         :facecolor facecolor
                         :edgecolor edgecolor
                         :linewidth linewidth))
    ;; Set visible based on frameon
    (setf (mpl.rendering:artist-visible (figure-patch fig)) frameon)
    ;; Default subplot params
    (setf (figure-subplot-params fig)
          (list :left 0.125d0 :right 0.9d0 :bottom 0.11d0 :top 0.88d0
                :wspace 0.2d0 :hspace 0.2d0))
    ;; Set layout engine if requested
    (when layout
      (figure-set-layout-engine fig layout))
    ;; Set the artist's figure reference to self
    (setf (mpl.rendering:artist-figure fig) fig)
    fig))

(defmethod initialize-instance :after ((fig mpl-figure) &key)
  "Initialize figure-specific state."
  (values))

;;; ============================================================
;;; Figure properties
;;; ============================================================

(defun figure-width-inches (figure)
  "Return figure width in inches."
  (first (figure-figsize figure)))

(defun figure-height-inches (figure)
  "Return figure height in inches."
  (second (figure-figsize figure)))

(defun figure-width-px (figure)
  "Return figure width in pixels (width_inches * dpi)."
  (round (* (figure-width-inches figure) (figure-dpi figure))))

(defun figure-height-px (figure)
  "Return figure height in pixels (height_inches * dpi)."
  (round (* (figure-height-inches figure) (figure-dpi figure))))

(defun figure-size-px (figure)
  "Return figure size as (values width-px height-px)."
  (values (figure-width-px figure) (figure-height-px figure)))

(defun figure-set-size-inches (figure width height)
  "Set figure size in inches."
  (setf (figure-figsize figure)
        (list (coerce width 'double-float)
              (coerce height 'double-float)))
  (setf (mpl.rendering:artist-stale figure) t))

(defun figure-get-size-inches (figure)
  "Return (values width height) in inches."
  (values (figure-width-inches figure) (figure-height-inches figure)))

;;; ============================================================
;;; Layout engine management
;;; ============================================================

(defun figure-set-layout-engine (figure layout)
  "Set the layout engine on FIGURE.
LAYOUT can be :tight, :none, NIL, or a layout-engine instance."
  (cond
    ((null layout)
     (setf (figure-layout-engine figure) nil))
    ((eq layout :tight)
     (setf (figure-layout-engine figure)
           (make-tight-layout-engine)))
    ((eq layout :none)
     (if (figure-layout-engine figure)
         (setf (figure-layout-engine figure)
               (make-placeholder-layout-engine
                :adjust-compatible (layout-engine-adjust-compatible-p
                                   (figure-layout-engine figure))
                :colorbar-gridspec (layout-engine-colorbar-gridspec-p
                                   (figure-layout-engine figure))))
         (setf (figure-layout-engine figure) nil)))
    ((typep layout 'layout-engine)
     (setf (figure-layout-engine figure) layout))
    (t (error "Invalid layout engine: ~S" layout))))

(defun figure-get-layout-engine (figure)
  "Return the current layout engine or NIL."
  (figure-layout-engine figure))

;;; ============================================================
;;; Artist management
;;; ============================================================

(defun figure-add-artist (figure artist)
  "Add an artist to the figure's artist list."
  (push artist (figure-artists figure))
  (setf (mpl.rendering:artist-figure artist) figure)
  (setf (mpl.rendering:artist-stale figure) t)
  artist)

(defun figure-remove-artist (figure artist)
  "Remove an artist from the figure."
  (setf (figure-artists figure)
        (remove artist (figure-artists figure)))
  (setf (mpl.rendering:artist-stale figure) t))

(defun figure-get-children (figure)
  "Return a list of all child artists in the figure."
  (append (when (figure-patch figure) (list (figure-patch figure)))
          (figure-artists figure)
          (figure-axes figure)
          (figure-lines figure)
          (figure-patches figure)
          (figure-texts figure)
          (figure-images figure)
          (figure-legends figure)
          (figure-subfigs figure)))

;;; ============================================================
;;; Subplot parameter adjustment
;;; ============================================================

(defun figure-subplots-adjust (figure &key left right bottom top wspace hspace)
  "Adjust subplot parameters on the figure.
Only non-nil values are updated."
  (let ((params (figure-subplot-params figure)))
    (when left (setf (getf params :left) (coerce left 'double-float)))
    (when right (setf (getf params :right) (coerce right 'double-float)))
    (when bottom (setf (getf params :bottom) (coerce bottom 'double-float)))
    (when top (setf (getf params :top) (coerce top 'double-float)))
    (when wspace (setf (getf params :wspace) (coerce wspace 'double-float)))
    (when hspace (setf (getf params :hspace) (coerce hspace 'double-float)))
    (setf (figure-subplot-params figure) params)
    (setf (mpl.rendering:artist-stale figure) t)))

;;; ============================================================
;;; Figure-level title and axis labels
;;; ============================================================

(defun suptitle (fig text &key (fontsize 12.0) (color "black") (alpha nil)
                                (x 0.5) (y 0.98) (ha :center) (va :top))
  "Set the figure super-title — centered text above all subplots.
FIG — the mpl-figure instance.
TEXT — the title string.
FONTSIZE — font size in points (default 12.0).
X, Y — figure coordinates (0-1 fraction). Default: (0.5, 0.98) = top center.
HA — horizontal alignment (default :center).
VA — vertical alignment (default :top).
Returns the created text-artist."
  (let* ((w (figure-width-px fig))
         (h (figure-height-px fig))
         (transform (mpl.primitives:make-affine-2d :scale (list (float w 1.0d0) (float h 1.0d0))))
         (txt (make-instance 'mpl.rendering:text-artist
                             :x (float x 1.0d0)
                             :y (float y 1.0d0)
                             :text text
                             :fontsize (float fontsize 1.0d0)
                             :color color
                             :horizontalalignment ha
                             :verticalalignment va
                             :zorder 5)))
    (when alpha (setf (mpl.rendering:artist-alpha txt) (float alpha 1.0d0)))
    (setf (mpl.rendering:artist-transform txt) transform)
    ;; Store in figure slot and add to fig-texts for rendering
    (setf (figure-suptitle-artist fig) txt)
    (push txt (figure-texts fig))
    txt))

(defun supxlabel (fig text &key (fontsize 12.0) (color "black") (alpha nil)
                                 (x 0.5) (y 0.01) (ha :center) (va :bottom))
  "Set the figure super-xlabel — centered text at the bottom of the figure.
FIG — the mpl-figure instance.
TEXT — the label string.
FONTSIZE — font size in points (default 12.0).
X, Y — figure coordinates (0-1 fraction). Default: (0.5, 0.01) = bottom center.
HA — horizontal alignment (default :center).
VA — vertical alignment (default :bottom).
Returns the created text-artist."
  (let* ((w (figure-width-px fig))
         (h (figure-height-px fig))
         (transform (mpl.primitives:make-affine-2d :scale (list (float w 1.0d0) (float h 1.0d0))))
         (txt (make-instance 'mpl.rendering:text-artist
                             :x (float x 1.0d0)
                             :y (float y 1.0d0)
                             :text text
                             :fontsize (float fontsize 1.0d0)
                             :color color
                             :horizontalalignment ha
                             :verticalalignment va
                             :zorder 5)))
    (when alpha (setf (mpl.rendering:artist-alpha txt) (float alpha 1.0d0)))
    (setf (mpl.rendering:artist-transform txt) transform)
    (push txt (figure-texts fig))
    txt))

(defun supylabel (fig text &key (fontsize 12.0) (color "black") (alpha nil)
                                 (x 0.02) (y 0.5) (ha :center) (va :center)
                                 (rotation 90.0))
  "Set the figure super-ylabel — rotated text at the left of the figure.
FIG — the mpl-figure instance.
TEXT — the label string.
FONTSIZE — font size in points (default 12.0).
X, Y — figure coordinates (0-1 fraction). Default: (0.02, 0.5) = left center.
HA — horizontal alignment (default :center).
VA — vertical alignment (default :center).
ROTATION — text rotation in degrees (default 90.0).
Returns the created text-artist."
  (let* ((w (figure-width-px fig))
         (h (figure-height-px fig))
         (transform (mpl.primitives:make-affine-2d :scale (list (float w 1.0d0) (float h 1.0d0))))
         (txt (make-instance 'mpl.rendering:text-artist
                             :x (float x 1.0d0)
                             :y (float y 1.0d0)
                             :text text
                             :fontsize (float fontsize 1.0d0)
                             :color color
                             :horizontalalignment ha
                             :verticalalignment va
                             :rotation (float rotation 1.0d0)
                             :zorder 5)))
    (when alpha (setf (mpl.rendering:artist-alpha txt) (float alpha 1.0d0)))
    (setf (mpl.rendering:artist-transform txt) transform)
    (push txt (figure-texts fig))
    txt))

;;; ============================================================
;;; Figure draw method
;;; ============================================================

(defmethod mpl.rendering:draw ((fig mpl-figure) renderer)
  "Draw the figure: background patch, then all children in z-order.
This is the core render pipeline entry point for figures."
  (when (not (mpl.rendering:artist-visible fig))
    (return-from mpl.rendering:draw (values)))
  ;; Execute layout engine if we have axes
  (when (and (figure-axes fig) (figure-layout-engine fig))
    (handler-case
        (layout-engine-execute (figure-layout-engine fig) fig)
      (error () nil)))  ; Swallow layout errors like matplotlib does
  ;; Draw background patch
  (when (figure-patch fig)
    (draw-figure-background fig renderer))
  ;; Collect all children, sort by z-order, and draw
  (let ((artists (figure-get-children fig)))
    ;; Remove the patch (we already drew it)
    (when (figure-patch fig)
      (setf artists (remove (figure-patch fig) artists)))
    ;; Sort by z-order
    (setf artists (sort (copy-list artists) #'<
                        :key (lambda (a)
                               (if (typep a 'mpl.rendering:artist)
                                   (mpl.rendering:artist-zorder a)
                                   0))))
    ;; Draw each artist
    (dolist (artist artists)
      (when (and (typep artist 'mpl.rendering:artist)
                 (mpl.rendering:artist-visible artist))
        (mpl.rendering:draw artist renderer))))
  ;; Mark as not stale
  (setf (mpl.rendering:artist-stale fig) nil))

(defun draw-figure-background (figure renderer)
  "Draw the figure background as a filled rectangle.
Uses the figure's facecolor and edgecolor.
Only draws when renderer supports the backends draw-path protocol."
  (when (typep renderer 'mpl.backends:renderer-base)
    (let* ((width-px (figure-width-px figure))
           (height-px (figure-height-px figure))
           (fc (figure-facecolor figure))
           (ec (figure-edgecolor figure))
           (lw (figure-linewidth figure))
           (rgba-face (if (stringp fc)
                           (let ((rgba (mpl.colors:to-rgba fc)))
                             (list (elt rgba 0) (elt rgba 1) (elt rgba 2) (elt rgba 3)))
                           (list 1.0 1.0 1.0 1.0)))
           (rgba-edge (if (stringp ec)
                           (let ((rgba (mpl.colors:to-rgba ec)))
                             (list (elt rgba 0) (elt rgba 1) (elt rgba 2) (elt rgba 3)))
                           (list 1.0 1.0 1.0 1.0)))
           (rgba-edge (if (stringp ec)
                          (multiple-value-list (mpl.colors:to-rgba ec))
                          (list 1.0 1.0 1.0 1.0))))
      ;; Create a rectangle path covering the entire figure
      (let ((path (mpl.primitives:path-unit-rectangle))
            (transform (mpl.primitives:make-affine-2d
                        :scale (list (float width-px 1.0d0)
                                     (float height-px 1.0d0))))
            (gc (mpl.backends:make-graphics-context
                 :facecolor rgba-face
                 :edgecolor rgba-edge
                 :linewidth lw)))
        (mpl.backends:draw-path renderer gc path transform rgba-face)))))

;;; ============================================================
;;; Format detection for savefig
;;; ============================================================

(defun detect-format (filename)
  "Detect output format from FILENAME extension.
Returns a keyword: :png, :pdf, :svg, or :unknown."
  (let* ((name (if (pathnamep filename)
                   (namestring filename)
                   (string filename)))
         (dot-pos (position #\. name :from-end t)))
    (if dot-pos
        (let ((ext (string-downcase (subseq name (1+ dot-pos)))))
          (cond
            ((string= ext "png") :png)
            ((string= ext "pdf") :pdf)
            ((string= ext "svg") :svg)
            ((string= ext "jpg") :jpg)
            ((string= ext "jpeg") :jpg)
            (t :unknown)))
        :unknown)))

;;; ============================================================
;;; FigureCanvas — connects figure to renderer
;;; ============================================================
;;; Note: We build on the existing canvas-base in backends.
;;; The figure-canvas is a thin wrapper that manages the
;;; Figure → Canvas → Renderer connection.

(defun figure-ensure-canvas (figure &key format)
  "Ensure figure has an appropriate canvas for FORMAT.
Creates a canvas-vecto for :png (or default).
Returns the canvas."
  (let* ((fmt (or format :png))
         (w (figure-width-px figure))
         (h (figure-height-px figure))
         (dpi (figure-dpi figure)))
    (case fmt
      (:png
       (let ((canvas (make-instance 'mpl.backends:canvas-vecto
                                    :width w :height h
                                    :dpi dpi
                                    :figure figure)))
         (setf (figure-canvas figure) canvas)
         canvas))
      (otherwise
       ;; Default to PNG canvas for unsupported formats
       (let ((canvas (make-instance 'mpl.backends:canvas-vecto
                                    :width w :height h
                                    :dpi dpi
                                    :figure figure)))
         (setf (figure-canvas figure) canvas)
         canvas)))))

;;; ============================================================
;;; print-figure — the format-dispatch + render flow
;;; ============================================================

(defgeneric print-figure (canvas filename &key dpi facecolor edgecolor)
  (:documentation "Render the figure attached to CANVAS and save to FILENAME.
This is the core of the savefig pipeline."))

(defmethod print-figure ((canvas mpl.backends:canvas-vecto) filename
                         &key dpi facecolor edgecolor)
  "Render figure via Vecto canvas and save as PNG."
  (declare (ignore dpi facecolor edgecolor))
  ;; Use the existing print-png method which handles:
  ;; 1. Creating vecto:with-canvas context
  ;; 2. Drawing white background
  ;; 3. Calling figure.draw(renderer) if figure is set
  ;; 4. Saving to PNG
  (mpl.backends:print-png canvas filename))

;;; ============================================================
;;; savefig — main user entry point
;;; ============================================================

(defun savefig (figure filename &key (dpi nil) (format nil)
                                     (facecolor nil) (edgecolor nil)
                                     (transparent nil))
  "Save FIGURE to FILENAME.

Detects format from file extension unless FORMAT is specified.
Creates an appropriate canvas, renders the figure, and saves.

FIGURE — an mpl-figure instance.
FILENAME — output file path (string or pathname).
DPI — resolution override (defaults to figure DPI).
FORMAT — output format keyword (:png, :pdf, etc.) or NIL for auto-detect.
FACECOLOR — override figure facecolor for save.
EDGECOLOR — override figure edgecolor for save.
TRANSPARENT — if T, use transparent background."
  (let* ((fmt (or format (detect-format filename)))
         (save-dpi (or dpi (figure-dpi figure)))
         ;; Temporarily override figure properties for saving
         (orig-facecolor (figure-facecolor figure))
         (orig-edgecolor (figure-edgecolor figure))
         (orig-dpi (figure-dpi figure)))
    ;; Apply save-time overrides
    (when facecolor (setf (figure-facecolor figure) facecolor))
    (when edgecolor (setf (figure-edgecolor figure) edgecolor))
    (when transparent
      (setf (figure-facecolor figure) "none")
      (setf (figure-edgecolor figure) "none"))
    (when (and save-dpi (/= save-dpi orig-dpi))
      (setf (figure-dpi figure) (coerce save-dpi 'double-float)))
    (unwind-protect
         (let* ((w (figure-width-px figure))
                (h (figure-height-px figure))
                (canvas (case fmt
                          (:pdf (make-instance 'mpl.backends:canvas-pdf
                                               :width w :height h
                                               :dpi (figure-dpi figure)
                                               :figure figure))
                          (:svg (make-instance 'mpl.backends:canvas-svg
                                               :width w :height h
                                               :dpi (figure-dpi figure)
                                               :figure figure))
                          (otherwise (make-instance 'mpl.backends:canvas-vecto
                                                    :width w :height h
                                                    :dpi (figure-dpi figure)
                                                    :figure figure)))))
           (case fmt
             (:png
              (mpl.backends:print-png canvas (namestring (pathname filename))))
             (:pdf
              (mpl.backends:print-pdf canvas (namestring (pathname filename))))
             (:svg
              (mpl.backends:print-svg canvas (namestring (pathname filename))))
             (otherwise
              (warn "Format ~A not yet supported, falling back to PNG." fmt)
              (mpl.backends:print-png canvas (namestring (pathname filename))))))
      ;; Restore original properties
      (setf (figure-facecolor figure) orig-facecolor)
      (setf (figure-edgecolor figure) orig-edgecolor)
      (setf (figure-dpi figure) orig-dpi)))
  filename)

;;; ============================================================
;;; SubFigure — logical figure inside a figure
;;; ============================================================

(defclass sub-figure (mpl-figure)
  ((parent :initarg :parent
           :accessor subfigure-parent
           :documentation "Parent figure or subfigure.")
   (position :initarg :position
             :initform '(0.0d0 0.0d0 1.0d0 1.0d0)
             :accessor subfigure-position
             :documentation "Position (left bottom width height) in parent coordinates."))
  (:documentation "A logical figure inside another figure.
Supports nesting for complex layouts."))

(defun make-subfigure (parent &key (position '(0.0d0 0.0d0 1.0d0 1.0d0)))
  "Create a SubFigure within PARENT figure.
POSITION is (left bottom width height) in normalized parent coordinates."
  (let ((subfig (make-instance 'sub-figure
                               :parent parent
                               :position position
                               :figsize (figure-figsize parent)
                               :dpi (figure-dpi parent)
                               :facecolor "none"
                               :edgecolor "none")))
    (push subfig (figure-subfigs parent))
    (setf (mpl.rendering:artist-figure subfig) parent)
    subfig))

;;; ============================================================
;;; Convenience: figure description
;;; ============================================================

(defmethod print-object ((fig mpl-figure) stream)
  "Print a readable representation of the figure."
  (print-unreadable-object (fig stream :type t)
    (format stream "~Gx~G @ ~G dpi, ~D axes"
            (figure-width-inches fig)
            (figure-height-inches fig)
            (figure-dpi fig)
            (length (figure-axes fig)))))
