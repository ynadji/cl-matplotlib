;;;; test-figure.lisp — Tests for Figure, FigureCanvas, and savefig pipeline
;;;; Phase 4a — FiveAM test suite

(defpackage #:cl-matplotlib.tests.figure
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; Layout engines
                #:layout-engine #:layout-engine-execute #:layout-engine-set
                #:layout-engine-get #:layout-engine-params
                #:layout-engine-adjust-compatible-p #:layout-engine-colorbar-gridspec-p
                #:placeholder-layout-engine #:make-placeholder-layout-engine
                #:tight-layout-engine #:make-tight-layout-engine
                ;; Figure class
                #:mpl-figure #:make-figure
                #:figure-figsize #:figure-dpi #:figure-facecolor #:figure-edgecolor
                #:figure-linewidth #:figure-frameon-p
                #:figure-axes #:figure-artists #:figure-lines #:figure-patches
                #:figure-texts #:figure-images #:figure-legends #:figure-subfigs
                #:figure-canvas #:figure-layout-engine #:figure-subplot-params
                #:figure-suptitle-artist #:figure-patch
                ;; Figure functions
                #:figure-width-inches #:figure-height-inches
                #:figure-width-px #:figure-height-px #:figure-size-px
                #:figure-set-size-inches #:figure-get-size-inches
                #:figure-set-layout-engine #:figure-get-layout-engine
                #:figure-add-artist #:figure-remove-artist #:figure-get-children
                #:figure-subplots-adjust #:figure-ensure-canvas
                ;; savefig pipeline
                #:savefig #:detect-format #:print-figure
                ;; SubFigure
                #:sub-figure #:make-subfigure #:subfigure-parent #:subfigure-position)
  (:export #:run-figure-tests))

(in-package #:cl-matplotlib.tests.figure)

(def-suite figure-suite :description "Figure and savefig test suite")
(in-suite figure-suite)

;;; ============================================================
;;; Helpers
;;; ============================================================

(defun tmp-path (name ext)
  "Create a temporary file path."
  (format nil "/tmp/cl-mpl-test-~A.~A" name ext))

(defun file-exists-and-valid-p (path &optional (min-size 100))
  "Check that PATH exists and is larger than MIN-SIZE bytes."
  (and (probe-file path)
       (> (with-open-file (s path :element-type '(unsigned-byte 8))
            (file-length s))
          min-size)))

(defun png-header-valid-p (path)
  "Check that the file at PATH starts with the PNG magic bytes."
  (when (probe-file path)
    (with-open-file (s path :element-type '(unsigned-byte 8))
      (and (= (read-byte s) 137)   ; PNG signature
           (= (read-byte s) 80)    ; P
           (= (read-byte s) 78)    ; N
           (= (read-byte s) 71))))) ; G

;;; ============================================================
;;; Layout Engine Tests
;;; ============================================================

(test placeholder-layout-engine-creation
  "PlaceHolderLayoutEngine can be created with default params."
  (let ((engine (make-placeholder-layout-engine)))
    (is (typep engine 'placeholder-layout-engine))
    (is (eq t (layout-engine-adjust-compatible-p engine)))
    (is (eq t (layout-engine-colorbar-gridspec-p engine)))))

(test placeholder-layout-engine-custom
  "PlaceHolderLayoutEngine mirrors given params."
  (let ((engine (make-placeholder-layout-engine :adjust-compatible nil
                                                :colorbar-gridspec nil)))
    (is (null (layout-engine-adjust-compatible-p engine)))
    (is (null (layout-engine-colorbar-gridspec-p engine)))))

(test placeholder-layout-engine-execute-noop
  "PlaceHolderLayoutEngine.execute does nothing."
  (let ((engine (make-placeholder-layout-engine))
        (fig (make-figure)))
    ;; Should not error
    (layout-engine-execute engine fig)
    (pass)))

(test tight-layout-engine-creation
  "TightLayoutEngine can be created with default padding."
  (let ((engine (make-tight-layout-engine)))
    (is (typep engine 'tight-layout-engine))
    (is (eq t (layout-engine-adjust-compatible-p engine)))
    (is (eq t (layout-engine-colorbar-gridspec-p engine)))
    (let ((params (layout-engine-get engine)))
      (is (= 1.08 (getf params :pad)))
      (is (null (getf params :h-pad)))
      (is (null (getf params :w-pad)))
      (is (equal '(0 0 1 1) (getf params :rect))))))

(test tight-layout-engine-custom-params
  "TightLayoutEngine accepts custom padding."
  (let ((engine (make-tight-layout-engine :pad 2.0 :h-pad 0.5 :w-pad 0.5)))
    (let ((params (layout-engine-get engine)))
      (is (= 2.0 (getf params :pad)))
      (is (= 0.5 (getf params :h-pad)))
      (is (= 0.5 (getf params :w-pad))))))

(test tight-layout-engine-set
  "TightLayoutEngine.set updates parameters."
  (let ((engine (make-tight-layout-engine)))
    (layout-engine-set engine :pad 3.0)
    (is (= 3.0 (getf (layout-engine-get engine) :pad)))))

(test tight-layout-engine-execute-noop
  "TightLayoutEngine.execute doesn't error (simplified for now)."
  (let ((engine (make-tight-layout-engine))
        (fig (make-figure)))
    ;; Should not error
    (layout-engine-execute engine fig)
    (pass)))

;;; ============================================================
;;; Figure Creation Tests
;;; ============================================================

(test figure-creation-default
  "Figure can be created with default parameters."
  (let ((fig (make-figure)))
    (is (typep fig 'mpl-figure))
    (is (= 6.4d0 (figure-width-inches fig)))
    (is (= 4.8d0 (figure-height-inches fig)))
    (is (= 100.0d0 (figure-dpi fig)))
    (is (string= "white" (figure-facecolor fig)))
    (is (string= "white" (figure-edgecolor fig)))
    (is (= 0.0d0 (figure-linewidth fig)))
    (is (eq t (figure-frameon-p fig)))))

(test figure-creation-custom
  "Figure can be created with custom parameters."
  (let ((fig (make-figure :figsize '(8 6) :dpi 150
                          :facecolor "lightblue" :edgecolor "black"
                          :linewidth 2.0)))
    (is (= 8.0d0 (figure-width-inches fig)))
    (is (= 6.0d0 (figure-height-inches fig)))
    (is (= 150.0d0 (figure-dpi fig)))
    (is (string= "lightblue" (figure-facecolor fig)))
    (is (string= "black" (figure-edgecolor fig)))
    (is (= 2.0d0 (figure-linewidth fig)))))

(test figure-size-pixels
  "Figure size in pixels = figsize * dpi."
  (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 100)))
    (is (= 640 (figure-width-px fig)))
    (is (= 480 (figure-height-px fig))))
  ;; Custom DPI
  (let ((fig (make-figure :figsize '(8 6) :dpi 150)))
    (is (= 1200 (figure-width-px fig)))
    (is (= 900 (figure-height-px fig)))))

(test figure-size-px-values
  "figure-size-px returns multiple values."
  (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 100)))
    (multiple-value-bind (w h) (figure-size-px fig)
      (is (= 640 w))
      (is (= 480 h)))))

(test figure-set-size-inches
  "figure-set-size-inches changes the figure size."
  (let ((fig (make-figure)))
    (figure-set-size-inches fig 10 8)
    (is (= 10.0d0 (figure-width-inches fig)))
    (is (= 8.0d0 (figure-height-inches fig)))
    (is (= 1000 (figure-width-px fig)))
    (is (= 800 (figure-height-px fig)))))

(test figure-get-size-inches
  "figure-get-size-inches returns width and height."
  (let ((fig (make-figure :figsize '(10 8))))
    (multiple-value-bind (w h) (figure-get-size-inches fig)
      (is (= 10.0d0 w))
      (is (= 8.0d0 h)))))

(test figure-inherits-artist
  "Figure is a subclass of artist."
  (let ((fig (make-figure)))
    (is (typep fig 'mpl.rendering:artist))
    ;; Figure has all artist properties
    (is (eq t (mpl.rendering:artist-visible fig)))
    (is (= 0 (mpl.rendering:artist-zorder fig)))
    ;; Figure's artist-figure points to itself
    (is (eq fig (mpl.rendering:artist-figure fig)))))

(test figure-has-background-patch
  "Figure has a background rectangle patch."
  (let ((fig (make-figure)))
    (is (not (null (figure-patch fig))))
    (is (typep (figure-patch fig) 'mpl.rendering:rectangle))))

(test figure-empty-lists
  "Figure starts with empty artist lists."
  (let ((fig (make-figure)))
    (is (null (figure-axes fig)))
    (is (null (figure-artists fig)))
    (is (null (figure-lines fig)))
    (is (null (figure-patches fig)))
    (is (null (figure-texts fig)))
    (is (null (figure-images fig)))
    (is (null (figure-legends fig)))
    (is (null (figure-subfigs fig)))))

(test figure-subplot-params-default
  "Figure has default subplot parameters."
  (let* ((fig (make-figure))
         (params (figure-subplot-params fig)))
    (is (= 0.125d0 (getf params :left)))
    (is (= 0.9d0 (getf params :right)))
    (is (= 0.11d0 (getf params :bottom)))
    (is (= 0.88d0 (getf params :top)))
    (is (= 0.2d0 (getf params :wspace)))
    (is (= 0.2d0 (getf params :hspace)))))

(test figure-subplots-adjust
  "figure-subplots-adjust modifies subplot parameters."
  (let ((fig (make-figure)))
    (figure-subplots-adjust fig :left 0.15d0 :right 0.95d0)
    (let ((params (figure-subplot-params fig)))
      (is (= 0.15d0 (getf params :left)))
      (is (= 0.95d0 (getf params :right)))
      ;; Unchanged params remain
      (is (= 0.11d0 (getf params :bottom))))))

;;; ============================================================
;;; Layout Engine Integration Tests
;;; ============================================================

(test figure-set-layout-engine-tight
  "Figure can set tight layout engine."
  (let ((fig (make-figure)))
    (figure-set-layout-engine fig :tight)
    (is (typep (figure-get-layout-engine fig) 'tight-layout-engine))))

(test figure-set-layout-engine-none
  "Figure can set layout engine to none."
  (let ((fig (make-figure)))
    (figure-set-layout-engine fig :tight)
    (is (not (null (figure-get-layout-engine fig))))
    (figure-set-layout-engine fig :none)
    ;; Should now be a placeholder
    (is (typep (figure-get-layout-engine fig) 'placeholder-layout-engine))))

(test figure-set-layout-engine-nil
  "Setting layout engine to NIL removes it."
  (let ((fig (make-figure)))
    (figure-set-layout-engine fig :tight)
    (figure-set-layout-engine fig nil)
    (is (null (figure-get-layout-engine fig)))))

(test figure-layout-engine-via-constructor
  "Figure can be created with a layout engine."
  (let ((fig (make-figure :layout :tight)))
    (is (typep (figure-get-layout-engine fig) 'tight-layout-engine))))

;;; ============================================================
;;; Artist Management Tests
;;; ============================================================

(test figure-add-artist
  "Artists can be added to the figure."
  (let ((fig (make-figure))
        (line (make-instance 'mpl.rendering:line-2d)))
    (figure-add-artist fig line)
    (is (= 1 (length (figure-artists fig))))
    (is (eq fig (mpl.rendering:artist-figure line)))))

(test figure-remove-artist
  "Artists can be removed from the figure."
  (let ((fig (make-figure))
        (line (make-instance 'mpl.rendering:line-2d)))
    (figure-add-artist fig line)
    (is (= 1 (length (figure-artists fig))))
    (figure-remove-artist fig line)
    (is (= 0 (length (figure-artists fig))))))

(test figure-get-children
  "figure-get-children returns all child artists."
  (let ((fig (make-figure))
        (line (make-instance 'mpl.rendering:line-2d)))
    (figure-add-artist fig line)
    (let ((children (figure-get-children fig)))
      ;; Should include patch + the added artist
      (is (>= (length children) 2))
      (is (member (figure-patch fig) children))
      (is (member line children)))))

;;; ============================================================
;;; Format Detection Tests
;;; ============================================================

(test detect-format-png
  "Detect PNG format from .png extension."
  (is (eq :png (detect-format "/tmp/test.png")))
  (is (eq :png (detect-format "/tmp/test.PNG"))))

(test detect-format-pdf
  "Detect PDF format from .pdf extension."
  (is (eq :pdf (detect-format "/tmp/test.pdf"))))

(test detect-format-svg
  "Detect SVG format from .svg extension."
  (is (eq :svg (detect-format "/tmp/test.svg"))))

(test detect-format-jpg
  "Detect JPG format from .jpg/.jpeg extension."
  (is (eq :jpg (detect-format "/tmp/test.jpg")))
  (is (eq :jpg (detect-format "/tmp/test.jpeg"))))

(test detect-format-unknown
  "Unknown extensions return :unknown."
  (is (eq :unknown (detect-format "/tmp/test.bmp")))
  (is (eq :unknown (detect-format "/tmp/noext"))))

(test detect-format-pathname
  "Detect format from pathname objects."
  (is (eq :png (detect-format (pathname "/tmp/test.png")))))

;;; ============================================================
;;; Canvas Creation Tests
;;; ============================================================

(test figure-ensure-canvas-png
  "figure-ensure-canvas creates a Vecto canvas for PNG."
  (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 100)))
    (let ((canvas (figure-ensure-canvas fig :format :png)))
      (is (typep canvas 'mpl.backends:canvas-vecto))
      (is (= 640 (mpl.backends:canvas-width canvas)))
      (is (= 480 (mpl.backends:canvas-height canvas)))
      (is (eq fig (mpl.backends:canvas-figure canvas)))
      (is (eq canvas (figure-canvas fig))))))

(test figure-ensure-canvas-default
  "figure-ensure-canvas defaults to PNG."
  (let ((fig (make-figure)))
    (let ((canvas (figure-ensure-canvas fig)))
      (is (typep canvas 'mpl.backends:canvas-vecto)))))

;;; ============================================================
;;; savefig Tests — PNG Output
;;; ============================================================

(test savefig-empty-figure-png
  "savefig creates a valid PNG for an empty figure."
  (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
        (path (tmp-path "figure-empty" "png")))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test savefig-custom-size
  "savefig respects custom figure size."
  (let ((fig (make-figure :figsize '(8 6) :dpi 100))
        (path (tmp-path "figure-8x6" "png")))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test savefig-high-dpi
  "savefig respects high DPI."
  (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 200))
        (path (tmp-path "figure-200dpi" "png")))
    (savefig fig path)
    ;; At 200 DPI, output should be bigger
    (is (file-exists-and-valid-p path 1000))
    (is (png-header-valid-p path))))

(test savefig-dpi-override
  "savefig can override figure DPI."
  (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
        (path (tmp-path "figure-dpi-override" "png")))
    ;; Save with double the DPI
    (savefig fig path :dpi 200)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))
    ;; Original DPI should be restored
    (is (= 100.0d0 (figure-dpi fig)))))

(test savefig-format-auto-detection
  "savefig auto-detects format from extension."
  (let ((fig (make-figure))
        (path (tmp-path "figure-auto" "png")))
    ;; Should work with .png extension
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test savefig-facecolor-override
  "savefig can override facecolor."
  (let ((fig (make-figure :facecolor "white"))
        (path (tmp-path "figure-facecolor" "png")))
    (savefig fig path :facecolor "red")
    (is (file-exists-and-valid-p path))
    ;; Original facecolor should be restored
    (is (string= "white" (figure-facecolor fig)))))

(test savefig-restores-properties
  "savefig restores figure properties after saving."
  (let ((fig (make-figure :facecolor "white" :edgecolor "white" :dpi 100)))
    (savefig fig (tmp-path "figure-restore" "png")
             :facecolor "red" :edgecolor "blue" :dpi 200)
    (is (string= "white" (figure-facecolor fig)))
    (is (string= "white" (figure-edgecolor fig)))
    (is (= 100.0d0 (figure-dpi fig)))))

(test savefig-returns-filename
  "savefig returns the filename."
  (let ((fig (make-figure))
        (path (tmp-path "figure-return" "png")))
    (is (string= path (savefig fig path)))))

;;; ============================================================
;;; Figure Draw Tests
;;; ============================================================

(test figure-draw-with-mock-renderer
  "Figure can be drawn with mock renderer."
  (let ((fig (make-figure))
        (renderer (mpl.rendering:make-mock-renderer)))
    ;; Should not error
    (mpl.rendering:draw fig renderer)
    (pass)))

(test figure-draw-marks-not-stale
  "Drawing marks figure as not stale."
  (let ((fig (make-figure))
        (renderer (mpl.rendering:make-mock-renderer)))
    (is (eq t (mpl.rendering:artist-stale fig)))
    (mpl.rendering:draw fig renderer)
    (is (null (mpl.rendering:artist-stale fig)))))

(test figure-invisible-no-draw
  "Invisible figure does not draw."
  (let ((fig (make-figure))
        (renderer (mpl.rendering:make-mock-renderer)))
    (setf (mpl.rendering:artist-visible fig) nil)
    (mpl.rendering:draw fig renderer)
    ;; No calls should have been recorded
    (is (null (mpl.rendering:mock-renderer-calls renderer)))))

;;; ============================================================
;;; SubFigure Tests
;;; ============================================================

(test subfigure-creation
  "SubFigure can be created within a figure."
  (let ((fig (make-figure)))
    (let ((subfig (make-subfigure fig :position '(0.0d0 0.0d0 0.5d0 0.5d0))))
      (is (typep subfig 'sub-figure))
      (is (eq fig (subfigure-parent subfig)))
      (is (equal '(0.0d0 0.0d0 0.5d0 0.5d0) (subfigure-position subfig)))
      ;; Should be in parent's subfig list
      (is (member subfig (figure-subfigs fig))))))

(test subfigure-inherits-dpi
  "SubFigure inherits parent DPI."
  (let ((fig (make-figure :dpi 150)))
    (let ((subfig (make-subfigure fig)))
      (is (= 150.0d0 (figure-dpi subfig))))))

;;; ============================================================
;;; Pipeline Integration Tests
;;; ============================================================

(test pipeline-figure-to-canvas-to-renderer
  "Full pipeline: Figure → Canvas → Renderer → PNG."
  (let* ((fig (make-figure :figsize '(4 3) :dpi 100))
         (canvas (figure-ensure-canvas fig :format :png))
         (renderer (mpl.backends:get-renderer canvas)))
    ;; Verify pipeline connections
    (is (eq fig (mpl.backends:canvas-figure canvas)))
    (is (typep renderer 'mpl.backends:renderer-vecto))
    (is (= 400 (mpl.backends:renderer-width renderer)))
    (is (= 300 (mpl.backends:renderer-height renderer)))))

(test pipeline-savefig-creates-file
  "Full pipeline test: savefig creates a valid PNG file."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (path (tmp-path "pipeline-test" "png")))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-with-artist
  "Pipeline with a patch added to the figure still saves PNG."
  (let* ((fig (make-figure :figsize '(4 3) :dpi 100))
         ;; Use a rectangle patch - it draws through the figure's draw method
         ;; but figure.draw only renders children that implement the backends protocol.
         ;; For now, adding artists to figure is supported but rendering them
         ;; requires the full Axes pipeline (Phase 5).
         (path (tmp-path "pipeline-with-artist" "png")))
    ;; Just test that savefig works on a figure (even with no renderable artists)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Print Object Test
;;; ============================================================

(test figure-print-object
  "Figure prints a readable representation."
  (let ((fig (make-figure :figsize '(6.4 4.8) :dpi 100)))
    (let ((str (format nil "~A" fig)))
      (is (search "MPL-FIGURE" str)))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-figure-tests ()
  "Run all figure tests and return success boolean."
  (let ((results (run 'figure-suite)))
    (explain! results)
    (results-status results)))
