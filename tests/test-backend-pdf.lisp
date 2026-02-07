;;;; test-backend-pdf.lisp — Tests for cl-pdf PDF backend
;;;; Phase 3c — FiveAM test suite

(defpackage #:cl-matplotlib.tests.backend-pdf
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.backends
                ;; Protocol
                #:draw-path #:draw-image #:draw-text #:draw-markers
                #:draw-gouraud-triangles
                #:get-canvas-width-height #:points-to-pixels
                #:renderer-clear #:get-renderer #:print-pdf #:canvas-draw
                ;; Classes
                #:renderer-base #:renderer-pdf #:renderer-width #:renderer-height #:renderer-dpi
                #:canvas-pdf #:canvas-width #:canvas-height #:canvas-dpi
                #:canvas-render-fn-pdf
                ;; Helpers
                #:make-graphics-context #:render-to-pdf)
  (:export #:run-pdf-backend-tests))

(in-package #:cl-matplotlib.tests.backend-pdf)

(def-suite backend-pdf-suite :description "cl-pdf PDF backend test suite")
(in-suite backend-pdf-suite)

;;; ============================================================
;;; Helper: temporary file path
;;; ============================================================

(defun tmp-pdf-path (name)
  "Create a temporary PDF file path."
  (format nil "/tmp/cl-mpl-test-~A.pdf" name))

(defun file-exists-and-valid-p (path &optional (min-size 100))
  "Check that PATH exists and is larger than MIN-SIZE bytes."
  (and (probe-file path)
       (> (with-open-file (s path :element-type '(unsigned-byte 8))
            (file-length s))
          min-size)))

(defun pdf-header-valid-p (path)
  "Check that the file at PATH starts with the PDF magic bytes (%PDF)."
  (when (probe-file path)
    (with-open-file (s path :element-type '(unsigned-byte 8))
      (and (= (read-byte s) (char-code #\%))   ; %
           (= (read-byte s) (char-code #\P))   ; P
           (= (read-byte s) (char-code #\D))   ; D
           (= (read-byte s) (char-code #\F)))))) ; F

;;; ============================================================
;;; Canvas creation tests
;;; ============================================================

(test pdf-canvas-creation-default
  "PDF canvas can be created with default parameters."
  (let ((canvas (make-instance 'canvas-pdf)))
    (is (= 640 (canvas-width canvas)))
    (is (= 480 (canvas-height canvas)))
    (is (= 100.0 (canvas-dpi canvas)))))

(test pdf-canvas-creation-custom
  "PDF canvas can be created with custom parameters."
  (let ((canvas (make-instance 'canvas-pdf :width 800 :height 600 :dpi 150)))
    (is (= 800 (canvas-width canvas)))
    (is (= 600 (canvas-height canvas)))
    (is (= 150 (canvas-dpi canvas)))))

;;; ============================================================
;;; Renderer access tests
;;; ============================================================

(test pdf-get-renderer-creates-renderer
  "get-renderer returns a renderer-pdf instance."
  (let* ((canvas (make-instance 'canvas-pdf :width 320 :height 240 :dpi 72))
         (renderer (get-renderer canvas)))
    (is (typep renderer 'renderer-pdf))
    (is (= 320 (renderer-width renderer)))
    (is (= 240 (renderer-height renderer)))
    (is (= 72 (renderer-dpi renderer)))))

(test pdf-get-renderer-caches
  "get-renderer returns the same instance on repeated calls."
  (let ((canvas (make-instance 'canvas-pdf)))
    (let ((r1 (get-renderer canvas))
          (r2 (get-renderer canvas)))
      (is (eq r1 r2)))))

(test pdf-get-canvas-width-height-values
  "get-canvas-width-height returns correct values."
  (let* ((canvas (make-instance 'canvas-pdf :width 400 :height 300))
         (renderer (get-renderer canvas)))
    (multiple-value-bind (w h) (get-canvas-width-height renderer)
      (is (= 400 w))
      (is (= 300 h)))))

;;; ============================================================
;;; Points to pixels conversion
;;; ============================================================

(test pdf-points-to-pixels-72dpi
  "At 72 DPI, 1 point = 1 pixel."
  (let* ((canvas (make-instance 'canvas-pdf :dpi 72))
         (renderer (get-renderer canvas)))
    (is (= 1.0 (points-to-pixels renderer 1.0)))
    (is (= 12.0 (points-to-pixels renderer 12.0)))))

(test pdf-points-to-pixels-100dpi
  "At 100 DPI, 72 points = 100 pixels."
  (let* ((canvas (make-instance 'canvas-pdf :dpi 100))
         (renderer (get-renderer canvas)))
    (is (< (abs (- (points-to-pixels renderer 72.0) 100.0)) 0.01))))

;;; ============================================================
;;; Path drawing tests (inside print-pdf context)
;;; ============================================================

(test pdf-draw-path-line
  "Draw a simple line path and save to PDF."
  (let* ((output (tmp-pdf-path "draw-line"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 10.0) (190.0 190.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red")))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))
    (is (pdf-header-valid-p output))))

(test pdf-draw-path-filled-rect
  "Draw a filled rectangle path and save to PDF."
  (let* ((output (tmp-pdf-path "draw-rect"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 50.0) (150.0 50.0) (150.0 150.0) (50.0 150.0) (50.0 50.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor "blue" :edgecolor "black" :linewidth 1.0)))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))
    (is (pdf-header-valid-p output))))

(test pdf-draw-path-stroke-only
  "Draw a path with stroke only (no fill)."
  (let* ((output (tmp-pdf-path "stroke-only"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 100.0) (180.0 100.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 3.0 :edgecolor "green")))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

(test pdf-draw-path-fill-only
  "Draw a path with fill only (no stroke)."
  (let* ((output (tmp-pdf-path "fill-only"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 50.0) (150.0 50.0) (100.0 150.0) (50.0 50.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor "orange")))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Graphics context tests
;;; ============================================================

(test pdf-make-graphics-context-defaults
  "make-graphics-context creates a valid gc with defaults."
  (let ((gc (make-graphics-context)))
    (is (= 1.0 (mpl.rendering:gc-linewidth gc)))
    (is (= 1.0 (mpl.rendering:gc-alpha gc)))
    (is (eq :solid (mpl.rendering:gc-linestyle gc)))
    (is (eq :butt (mpl.rendering:gc-capstyle gc)))
    (is (eq :miter (mpl.rendering:gc-joinstyle gc)))))

(test pdf-make-graphics-context-with-colors
  "make-graphics-context resolves color names."
  (let ((gc (make-graphics-context :edgecolor "red" :facecolor "blue")))
    (is (not (null (mpl.rendering:gc-foreground gc))))
    (is (not (null (mpl.rendering:gc-background gc))))))

;;; ============================================================
;;; Dashed line tests
;;; ============================================================

(test pdf-draw-dashed-line
  "Draw a dashed line and verify PDF output."
  (let* ((output (tmp-pdf-path "dashed-line"))
         (canvas (make-instance 'canvas-pdf :width 400 :height 300 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 150.0) (350.0 150.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 3.0 :edgecolor "black" :dashes '(5.0 3.0))))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))
    (is (pdf-header-valid-p output))))

(test pdf-draw-named-linestyle-dashed
  "Draw with :dashed linestyle."
  (let* ((output (tmp-pdf-path "named-dashed"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 50.0) (190.0 50.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "blue" :linestyle :dashed)))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

(test pdf-draw-named-linestyle-dotted
  "Draw with :dotted linestyle."
  (let* ((output (tmp-pdf-path "named-dotted"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 50.0) (190.0 50.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "blue" :linestyle :dotted)))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Alpha transparency tests
;;; ============================================================

(test pdf-draw-with-alpha
  "Draw overlapping shapes with alpha transparency."
  (let* ((output (tmp-pdf-path "alpha-test"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            ;; Red rectangle
            (let ((path (mpl.primitives:make-path
                         :vertices '((30.0 30.0) (130.0 30.0) (130.0 130.0) (30.0 130.0) (30.0 30.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor '(1.0 0.0 0.0 0.5))))
              (draw-path renderer gc path nil))
            ;; Blue rectangle overlapping
            (let ((path (mpl.primitives:make-path
                         :vertices '((70.0 70.0) (170.0 70.0) (170.0 170.0) (70.0 170.0) (70.0 70.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor '(0.0 0.0 1.0 0.5))))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Bezier curve tests
;;; ============================================================

(test pdf-draw-cubic-bezier
  "Draw a cubic Bézier curve."
  (let* ((output (tmp-pdf-path "cubic-bezier"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 180.0) (20.0 20.0) (180.0 20.0) (180.0 180.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+curve4+
                                      mpl.primitives:+curve4+
                                      mpl.primitives:+curve4+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "purple")))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Text rendering tests
;;; ============================================================

(test pdf-draw-text-basic
  "Draw text string to PDF."
  (let* ((output (tmp-pdf-path "text-basic"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 16.0)))
              (draw-text renderer gc 20.0 50.0 "Hello PDF" nil 0))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))
    (is (pdf-header-valid-p output))))

(test pdf-draw-text-rotated
  "Draw rotated text to PDF."
  (let* ((output (tmp-pdf-path "text-rotated"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((gc (make-graphics-context :edgecolor "blue" :linewidth 14.0)))
              (draw-text renderer gc 100.0 100.0 "Rotated" nil 45.0))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Image embedding tests
;;; ============================================================

(test pdf-draw-image-placeholder
  "Draw an image placeholder into PDF."
  (let* ((output (tmp-pdf-path "image-placeholder"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let* ((w 32) (h 32)
                   (data (make-array (* w h 4) :element-type '(unsigned-byte 8)
                                                :initial-element 128)))
              (draw-image renderer nil 50 50
                          (list :data data :width w :height h)))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Circle path test
;;; ============================================================

(test pdf-draw-circle-path
  "Draw a circle using path-circle Bézier approximation."
  (let* ((output (tmp-pdf-path "circle"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:path-circle :center '(100.0 100.0) :radius 50.0d0))
                  (gc (make-graphics-context :facecolor "yellow" :edgecolor "black" :linewidth 2.0)))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Empty canvas test
;;; ============================================================

(test pdf-empty-canvas
  "An empty canvas (white background) produces valid PDF."
  (let* ((output (tmp-pdf-path "empty-canvas"))
         (canvas (make-instance 'canvas-pdf :width 100 :height 100 :dpi 100)))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))
    (is (pdf-header-valid-p output))))

;;; ============================================================
;;; Transform application test
;;; ============================================================

(test pdf-draw-path-with-transform
  "Draw a path with an affine transform applied."
  (let* ((output (tmp-pdf-path "transformed"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((0.0 0.0) (1.0 1.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red"))
                  (transform (mpl.primitives:make-affine-2d :scale '(100.0 100.0)
                                                             :translate '(50.0 50.0))))
              (draw-path renderer gc path transform))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Multiple paths in one render
;;; ============================================================

(test pdf-draw-multiple-paths
  "Draw multiple paths in a single render."
  (let* ((output (tmp-pdf-path "multi-path"))
         (canvas (make-instance 'canvas-pdf :width 300 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (dotimes (i 5)
              (let ((y (+ 20.0 (* i 35.0))))
                (let ((path (mpl.primitives:make-path
                             :vertices (list (list 20.0 y) (list 280.0 y))
                             :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                      (gc (make-graphics-context :linewidth 2.0
                                                  :edgecolor (case i
                                                               (0 "red") (1 "green") (2 "blue")
                                                               (3 "orange") (4 "purple")))))
                  (draw-path renderer gc path nil))))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Line cap and join tests
;;; ============================================================

(test pdf-draw-line-caps
  "Draw lines with different cap styles."
  (let* ((output (tmp-pdf-path "line-caps"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (dolist (cap-and-y '((:butt . 50.0) (:round . 100.0) (:projecting . 150.0)))
              (let ((path (mpl.primitives:make-path
                           :vertices (list (list 30.0 (cdr cap-and-y)) (list 170.0 (cdr cap-and-y)))
                           :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                    (gc (make-graphics-context :linewidth 10.0 :edgecolor "black"
                                               :capstyle (car cap-and-y))))
                (draw-path renderer gc path nil)))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

(test pdf-draw-line-joins
  "Draw polylines with different join styles."
  (let* ((output (tmp-pdf-path "line-joins"))
         (canvas (make-instance 'canvas-pdf :width 300 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            (dolist (join-and-offset '((:miter . 0.0) (:round . 80.0) (:bevel . 160.0)))
              (let* ((dx (cdr join-and-offset))
                     (path (mpl.primitives:make-path
                            :vertices (list (list (+ 20.0 dx) 180.0)
                                            (list (+ 50.0 dx) 20.0)
                                            (list (+ 80.0 dx) 180.0))
                            :codes (list mpl.primitives:+moveto+
                                         mpl.primitives:+lineto+
                                         mpl.primitives:+lineto+)))
                     (gc (make-graphics-context :linewidth 8.0 :edgecolor "black"
                                                 :joinstyle (car join-and-offset))))
                (draw-path renderer gc path nil)))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Render-to-pdf convenience function test
;;; ============================================================

(test pdf-render-to-pdf-convenience
  "render-to-pdf convenience function works."
  (let ((output (tmp-pdf-path "convenience")))
    (render-to-pdf output
                   :width 100 :height 100
                   :draw-fn (lambda (renderer)
                              (let ((path (mpl.primitives:make-path
                                           :vertices '((10.0 10.0) (90.0 90.0))
                                           :codes (list mpl.primitives:+moveto+
                                                        mpl.primitives:+lineto+)))
                                    (gc (make-graphics-context :linewidth 1.0 :edgecolor "black")))
                                (draw-path renderer gc path nil))))
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Gouraud triangles test
;;; ============================================================

(test pdf-draw-gouraud-triangles
  "Draw Gouraud-shaded triangles to PDF."
  (let* ((output (tmp-pdf-path "gouraud"))
         (canvas (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            ;; 2 triangles
            (let ((triangles (make-array '(2 3 2) :element-type 'single-float
                                                   :initial-contents
                                                   '(((20.0 20.0) (100.0 180.0) (180.0 20.0))
                                                     ((20.0 180.0) (100.0 20.0) (180.0 180.0)))))
                  (colors (make-array '(2 3 4) :element-type 'single-float
                                                :initial-contents
                                                '(((1.0 0.0 0.0 1.0) (0.0 1.0 0.0 1.0) (0.0 0.0 1.0 1.0))
                                                  ((1.0 1.0 0.0 1.0) (0.0 1.0 1.0 1.0) (1.0 0.0 1.0 1.0)))))
                  (gc (make-graphics-context)))
              (draw-gouraud-triangles renderer gc triangles colors nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Multiple pages test (basic)
;;; ============================================================

(test pdf-multiple-pages
  "Create a PDF with multiple pages by calling print-pdf twice."
  (let* ((output1 (tmp-pdf-path "page1"))
         (output2 (tmp-pdf-path "page2"))
         (canvas1 (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100))
         (canvas2 (make-instance 'canvas-pdf :width 200 :height 200 :dpi 100)))
    ;; Page 1: red line
    (setf (canvas-render-fn-pdf canvas1)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 10.0) (190.0 190.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red")))
              (draw-path renderer gc path nil))))
    (print-pdf canvas1 output1)
    ;; Page 2: blue rect
    (setf (canvas-render-fn-pdf canvas2)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 50.0) (150.0 50.0) (150.0 150.0) (50.0 150.0) (50.0 50.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor "blue")))
              (draw-path renderer gc path nil))))
    (print-pdf canvas2 output2)
    (is (file-exists-and-valid-p output1))
    (is (file-exists-and-valid-p output2))
    (is (pdf-header-valid-p output1))
    (is (pdf-header-valid-p output2))))

;;; ============================================================
;;; Acceptance scenario: Red line + blue rect (evidence)
;;; ============================================================

(test pdf-acceptance-scenario-backend-renders-path
  "Acceptance: Create canvas, draw red line + blue rect, save to PDF."
  (let* ((output (tmp-pdf-path "acceptance-s1"))
         (canvas (make-instance 'canvas-pdf :width 640 :height 480 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            ;; Draw a red line path from (100,100) to (500,400)
            (let ((path (mpl.primitives:make-path
                         :vertices '((100.0 100.0) (500.0 400.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red")))
              (draw-path renderer gc path nil))
            ;; Draw a blue filled rectangle at (200,200) to (300,300)
            (let ((path (mpl.primitives:make-path
                         :vertices '((200.0 200.0) (300.0 200.0) (300.0 300.0) (200.0 300.0) (200.0 200.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor "blue")))
              (draw-path renderer gc path nil))
            ;; Draw text
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 18.0)))
              (draw-text renderer gc 100.0 440.0 "cl-matplotlib PDF Backend" nil 0))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output 1000))
    (is (pdf-header-valid-p output))
    ;; Copy to evidence
    (let ((evidence-path ".sisyphus/evidence/phase3c-pdf-render.pdf"))
      (ensure-directories-exist evidence-path)
      (uiop:copy-file output evidence-path))))

;;; ============================================================
;;; Graphics state changes test
;;; ============================================================

(test pdf-graphics-state-changes
  "Graphics state changes (linewidth, color, dash) work correctly."
  (let* ((output (tmp-pdf-path "gc-state"))
         (canvas (make-instance 'canvas-pdf :width 300 :height 200 :dpi 100)))
    (setf (canvas-render-fn-pdf canvas)
          (lambda (renderer)
            ;; Thin solid red line
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 30.0) (280.0 30.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 1.0 :edgecolor "red")))
              (draw-path renderer gc path nil))
            ;; Thick dashed blue line
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 80.0) (280.0 80.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 4.0 :edgecolor "blue" :dashes '(8.0 4.0))))
              (draw-path renderer gc path nil))
            ;; Medium dotted green line
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 130.0) (280.0 130.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "green" :linestyle :dotted)))
              (draw-path renderer gc path nil))
            ;; Filled rect with alpha
            (let ((path (mpl.primitives:make-path
                         :vertices '((100.0 150.0) (200.0 150.0) (200.0 190.0) (100.0 190.0) (100.0 150.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor "purple" :alpha 0.5)))
              (draw-path renderer gc path nil))))
    (print-pdf canvas output)
    (is (file-exists-and-valid-p output))
    (is (pdf-header-valid-p output))))

;;; ============================================================
;;; Renderer type check
;;; ============================================================

(test pdf-renderer-is-renderer-base
  "renderer-pdf is a subclass of renderer-base."
  (let* ((canvas (make-instance 'canvas-pdf))
         (renderer (get-renderer canvas)))
    (is (typep renderer 'renderer-base))
    (is (typep renderer 'renderer-pdf))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-pdf-backend-tests ()
  "Run all backend-pdf tests and return results."
  (let ((results (run 'backend-pdf-suite)))
    (explain! results)
    results))
