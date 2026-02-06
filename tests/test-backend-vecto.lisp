;;;; test-backend-vecto.lisp — Tests for Vecto PNG backend
;;;; Phase 3b — FiveAM test suite

(defpackage #:cl-matplotlib.tests.backend-vecto
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.backends
                ;; Protocol
                #:draw-path #:draw-image #:draw-text #:draw-markers
                #:get-canvas-width-height #:points-to-pixels
                #:renderer-clear #:get-renderer #:print-png #:canvas-draw
                ;; Classes
                #:renderer-base #:renderer-vecto #:renderer-width #:renderer-height #:renderer-dpi
                #:canvas-vecto #:canvas-width #:canvas-height #:canvas-dpi
                #:canvas-render-fn
                ;; Helpers
                #:make-graphics-context #:render-to-png
                #:*default-font-path*)
  (:export #:run-backend-tests))

(in-package #:cl-matplotlib.tests.backend-vecto)

(def-suite backend-vecto-suite :description "Vecto backend test suite")
(in-suite backend-vecto-suite)

;;; ============================================================
;;; Helper: temporary file path
;;; ============================================================

(defun tmp-path (name)
  "Create a temporary file path."
  (format nil "/tmp/cl-mpl-test-~A.png" name))

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
;;; Canvas creation tests
;;; ============================================================

(test canvas-creation-default
  "Canvas can be created with default parameters."
  (let ((canvas (make-instance 'canvas-vecto)))
    (is (= 640 (canvas-width canvas)))
    (is (= 480 (canvas-height canvas)))
    (is (= 100.0 (canvas-dpi canvas)))))

(test canvas-creation-custom
  "Canvas can be created with custom parameters."
  (let ((canvas (make-instance 'canvas-vecto :width 800 :height 600 :dpi 150)))
    (is (= 800 (canvas-width canvas)))
    (is (= 600 (canvas-height canvas)))
    (is (= 150 (canvas-dpi canvas)))))

;;; ============================================================
;;; Renderer access tests
;;; ============================================================

(test get-renderer-creates-renderer
  "get-renderer returns a renderer-vecto instance."
  (let* ((canvas (make-instance 'canvas-vecto :width 320 :height 240 :dpi 72))
         (renderer (get-renderer canvas)))
    (is (typep renderer 'renderer-vecto))
    (is (= 320 (renderer-width renderer)))
    (is (= 240 (renderer-height renderer)))
    (is (= 72 (renderer-dpi renderer)))))

(test get-renderer-caches
  "get-renderer returns the same instance on repeated calls."
  (let ((canvas (make-instance 'canvas-vecto)))
    (let ((r1 (get-renderer canvas))
          (r2 (get-renderer canvas)))
      (is (eq r1 r2)))))

(test get-canvas-width-height-values
  "get-canvas-width-height returns correct values."
  (let* ((canvas (make-instance 'canvas-vecto :width 400 :height 300))
         (renderer (get-renderer canvas)))
    (multiple-value-bind (w h) (get-canvas-width-height renderer)
      (is (= 400 w))
      (is (= 300 h)))))

;;; ============================================================
;;; Points to pixels conversion
;;; ============================================================

(test points-to-pixels-72dpi
  "At 72 DPI, 1 point = 1 pixel."
  (let* ((canvas (make-instance 'canvas-vecto :dpi 72))
         (renderer (get-renderer canvas)))
    (is (= 1.0 (points-to-pixels renderer 1.0)))
    (is (= 12.0 (points-to-pixels renderer 12.0)))))

(test points-to-pixels-100dpi
  "At 100 DPI, 72 points = 100 pixels."
  (let* ((canvas (make-instance 'canvas-vecto :dpi 100))
         (renderer (get-renderer canvas)))
    (is (< (abs (- (points-to-pixels renderer 72.0) 100.0)) 0.01))
    (is (< (abs (- (points-to-pixels renderer 1.0) (/ 100.0 72.0))) 0.01))))

(test points-to-pixels-300dpi
  "At 300 DPI, 72 points = 300 pixels."
  (let* ((canvas (make-instance 'canvas-vecto :dpi 300))
         (renderer (get-renderer canvas)))
    (is (< (abs (- (points-to-pixels renderer 72.0) 300.0)) 0.01))))

;;; ============================================================
;;; Path drawing tests (inside print-png context)
;;; ============================================================

(test draw-path-line-to-png
  "Draw a simple line path and save to PNG."
  (let* ((output (tmp-path "draw-line"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 10.0) (190.0 190.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red")))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))
    (is (png-header-valid-p output))))

(test draw-path-filled-rect-to-png
  "Draw a filled rectangle path and save to PNG."
  (let* ((output (tmp-path "draw-rect"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
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
    (print-png canvas output)
    (is (file-exists-and-valid-p output))
    (is (png-header-valid-p output))))

(test draw-path-stroke-only
  "Draw a path with stroke only (no fill)."
  (let* ((output (tmp-path "stroke-only"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 100.0) (180.0 100.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 3.0 :edgecolor "green")))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

(test draw-path-fill-only
  "Draw a path with fill only (no stroke)."
  (let* ((output (tmp-path "fill-only"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 50.0) (150.0 50.0) (100.0 150.0) (50.0 50.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+lineto+
                                      mpl.primitives:+closepoly+)))
                  (gc (make-graphics-context :facecolor "orange")))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Graphics context tests
;;; ============================================================

(test make-graphics-context-defaults
  "make-graphics-context creates a valid gc with defaults."
  (let ((gc (make-graphics-context)))
    (is (= 1.0 (mpl.rendering:gc-linewidth gc)))
    (is (= 1.0 (mpl.rendering:gc-alpha gc)))
    (is (eq :solid (mpl.rendering:gc-linestyle gc)))
    (is (eq :butt (mpl.rendering:gc-capstyle gc)))
    (is (eq :miter (mpl.rendering:gc-joinstyle gc)))))

(test make-graphics-context-with-colors
  "make-graphics-context resolves color names."
  (let ((gc (make-graphics-context :edgecolor "red" :facecolor "blue")))
    (is (not (null (mpl.rendering:gc-foreground gc))))
    (is (not (null (mpl.rendering:gc-background gc))))))

(test make-graphics-context-dashes
  "make-graphics-context accepts dash patterns."
  (let ((gc (make-graphics-context :dashes '(5.0 3.0))))
    (is (equal '(5.0 3.0) (mpl.rendering:gc-dashes gc)))))

;;; ============================================================
;;; Dashed line tests
;;; ============================================================

(test draw-dashed-line-to-png
  "Draw a dashed line and verify PNG output."
  (let* ((output (tmp-path "dashed-line"))
         (canvas (make-instance 'canvas-vecto :width 400 :height 300 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 150.0) (350.0 150.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 3.0 :edgecolor "black" :dashes '(5.0 3.0))))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))
    (is (png-header-valid-p output))))

(test draw-named-linestyle-dashed
  "Draw with :dashed linestyle."
  (let* ((output (tmp-path "named-dashed"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 50.0) (190.0 50.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "blue" :linestyle :dashed)))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

(test draw-named-linestyle-dotted
  "Draw with :dotted linestyle."
  (let* ((output (tmp-path "named-dotted"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 50.0) (190.0 50.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "blue" :linestyle :dotted)))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Alpha transparency tests
;;; ============================================================

(test draw-with-alpha
  "Draw overlapping shapes with alpha transparency."
  (let* ((output (tmp-path "alpha-test"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
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
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Bezier curve tests
;;; ============================================================

(test draw-cubic-bezier
  "Draw a cubic Bézier curve."
  (let* ((output (tmp-path "cubic-bezier"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 180.0) (20.0 20.0) (180.0 20.0) (180.0 180.0))
                         :codes (list mpl.primitives:+moveto+
                                      mpl.primitives:+curve4+
                                      mpl.primitives:+curve4+
                                      mpl.primitives:+curve4+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "purple")))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Image blitting tests
;;; ============================================================

(test draw-image-blit
  "Draw an RGBA image (checkerboard) into canvas."
  (let* ((output (tmp-path "image-blit"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            ;; Create 32x32 red image data
            (let* ((w 32) (h 32)
                   (data (make-array (* w h 4) :element-type '(unsigned-byte 8)
                                                :initial-element 0)))
              (dotimes (y h)
                (dotimes (x w)
                  (let ((i (* 4 (+ x (* y w)))))
                    (if (evenp (+ (floor x 8) (floor y 8)))
                        (setf (aref data i) 255       ; R
                              (aref data (+ i 1)) 0   ; G
                              (aref data (+ i 2)) 0   ; B
                              (aref data (+ i 3)) 255) ; A
                        (setf (aref data i) 0
                              (aref data (+ i 1)) 0
                              (aref data (+ i 2)) 255
                              (aref data (+ i 3)) 255)))))
              (draw-image renderer nil 50 50
                          (list :data data :width w :height h)))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Text rendering tests
;;; ============================================================

(test draw-text-basic
  "Draw text string to PNG."
  (let* ((output (tmp-path "text-basic"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 16.0)))
              (draw-text renderer gc 20.0 50.0 "Hello" *default-font-path* 0))))
    ;; Only test if font exists
    (if (probe-file *default-font-path*)
        (progn
          (print-png canvas output)
          (is (file-exists-and-valid-p output)))
        (skip "Font not available: ~A" *default-font-path*))))

;;; ============================================================
;;; Multiple shapes test (acceptance scenario 1)
;;; ============================================================

(test acceptance-scenario-1-backend-renders-path
  "Acceptance: Create canvas, draw red line + blue rect, save to PNG."
  (let* ((output (tmp-path "acceptance-s1"))
         (canvas (make-instance 'canvas-vecto :width 640 :height 480 :dpi 100)))
    (setf (canvas-render-fn canvas)
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
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output 5000))
    (is (png-header-valid-p output))
    ;; Copy to evidence
    (let ((evidence-path ".sisyphus/evidence/phase3b-backend-render.png"))
      (ensure-directories-exist evidence-path)
      (uiop:copy-file output evidence-path))))

;;; ============================================================
;;; Acceptance scenario 2: Dashed lines
;;; ============================================================

(test acceptance-scenario-2-dashed-lines
  "Acceptance: Dashed line renders correctly."
  (let* ((output (tmp-path "acceptance-s2"))
         (canvas (make-instance 'canvas-vecto :width 400 :height 300 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 150.0) (350.0 150.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 3.0 :edgecolor "black" :dashes '(5.0 3.0))))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))
    (is (png-header-valid-p output))
    ;; Copy to evidence
    (let ((evidence-path ".sisyphus/evidence/phase3b-dashed-line.png"))
      (ensure-directories-exist evidence-path)
      (uiop:copy-file output evidence-path))))

;;; ============================================================
;;; Render-to-png convenience function test
;;; ============================================================

(test render-to-png-convenience
  "render-to-png convenience function works."
  (let ((output (tmp-path "convenience")))
    (render-to-png output
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
;;; Circle path test (using path-circle)
;;; ============================================================

(test draw-circle-path
  "Draw a circle using path-circle Bézier approximation."
  (let* ((output (tmp-path "circle"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:path-circle :center '(100.0 100.0) :radius 50.0d0))
                  (gc (make-graphics-context :facecolor "yellow" :edgecolor "black" :linewidth 2.0)))
              (draw-path renderer gc path nil))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Empty canvas test
;;; ============================================================

(test empty-canvas-to-png
  "An empty canvas (white background) produces valid PNG."
  (let* ((output (tmp-path "empty-canvas"))
         (canvas (make-instance 'canvas-vecto :width 100 :height 100 :dpi 100)))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))
    (is (png-header-valid-p output))))

;;; ============================================================
;;; Transform application test
;;; ============================================================

(test draw-path-with-transform
  "Draw a path with an affine transform applied."
  (let* ((output (tmp-path "transformed"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            ;; Draw a small line from (0,0) to (1,1), scaled by 100 + translated by 50
            (let ((path (mpl.primitives:make-path
                         :vertices '((0.0 0.0) (1.0 1.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red"))
                  (transform (mpl.primitives:make-affine-2d :scale '(100.0 100.0)
                                                             :translate '(50.0 50.0))))
              (draw-path renderer gc path transform))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Multiple paths in one render
;;; ============================================================

(test draw-multiple-paths
  "Draw multiple paths in a single render."
  (let* ((output (tmp-path "multi-path"))
         (canvas (make-instance 'canvas-vecto :width 300 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            ;; Horizontal lines at different Y positions
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
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Line cap and join tests
;;; ============================================================

(test draw-line-caps
  "Draw lines with different cap styles."
  (let* ((output (tmp-path "line-caps"))
         (canvas (make-instance 'canvas-vecto :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
          (lambda (renderer)
            (dolist (cap-and-y '((:butt . 50.0) (:round . 100.0) (:projecting . 150.0)))
              (let ((path (mpl.primitives:make-path
                           :vertices (list (list 30.0 (cdr cap-and-y)) (list 170.0 (cdr cap-and-y)))
                           :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                    (gc (make-graphics-context :linewidth 10.0 :edgecolor "black"
                                               :capstyle (car cap-and-y))))
                (draw-path renderer gc path nil)))))
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

(test draw-line-joins
  "Draw polylines with different join styles."
  (let* ((output (tmp-path "line-joins"))
         (canvas (make-instance 'canvas-vecto :width 300 :height 200 :dpi 100)))
    (setf (canvas-render-fn canvas)
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
    (print-png canvas output)
    (is (file-exists-and-valid-p output))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-backend-tests ()
  "Run all backend-vecto tests and return results."
  (let ((results (run 'backend-vecto-suite)))
    (explain! results)
    results))
