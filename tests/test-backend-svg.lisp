;;;; test-backend-svg.lisp — Tests for SVG backend
;;;; FiveAM test suite

(defpackage #:cl-matplotlib.tests.backend-svg
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.backends
                ;; Protocol
                #:draw-path #:draw-image #:draw-text #:draw-markers
                #:draw-gouraud-triangles
                #:get-canvas-width-height #:points-to-pixels
                #:renderer-clear #:get-renderer #:print-svg #:canvas-draw
                ;; Classes
                #:renderer-base #:renderer-svg #:renderer-width #:renderer-height #:renderer-dpi
                #:canvas-svg #:canvas-width #:canvas-height #:canvas-dpi
                #:canvas-render-fn-svg
                ;; Helpers
                #:make-graphics-context #:render-to-svg)
  (:export #:run-svg-backend-tests))

(in-package #:cl-matplotlib.tests.backend-svg)

(def-suite backend-svg-suite :description "SVG backend test suite")
(in-suite backend-svg-suite)

;;; ============================================================
;;; Helper functions
;;; ============================================================

(defun tmp-svg-path (name)
  "Create a temporary SVG file path."
  (format nil "/tmp/cl-mpl-test-~A.svg" name))

(defun file-exists-and-valid-p (path &optional (min-size 100))
  "Check that PATH exists and is larger than MIN-SIZE bytes."
  (and (probe-file path)
       (> (with-open-file (s path :element-type '(unsigned-byte 8))
            (file-length s))
          min-size)))

(defun svg-header-valid-p (path)
  "Check that the file at PATH starts with <?xml or <svg."
  (when (probe-file path)
    (with-open-file (s path)
      (let ((first-line (read-line s nil "")))
        (or (search "<?xml" first-line)
            (search "<svg" first-line))))))

(defun svg-contains-p (path substring)
  "Check that the SVG file at PATH contains SUBSTRING."
  (when (probe-file path)
    (with-open-file (s path)
      (let ((content (make-string (file-length s))))
        (read-sequence content s)
        (search substring content)))))

;;; ============================================================
;;; Canvas creation tests
;;; ============================================================

(test svg-canvas-creation-default
  "SVG canvas can be created with default parameters."
  (let ((canvas (make-instance 'canvas-svg)))
    (is (= 640 (canvas-width canvas)))
    (is (= 480 (canvas-height canvas)))
    (is (= 100.0 (canvas-dpi canvas)))))

(test svg-canvas-creation-custom
  "SVG canvas can be created with custom parameters."
  (let ((canvas (make-instance 'canvas-svg :width 800 :height 600 :dpi 150)))
    (is (= 800 (canvas-width canvas)))
    (is (= 600 (canvas-height canvas)))
    (is (= 150 (canvas-dpi canvas)))))

;;; ============================================================
;;; Renderer tests
;;; ============================================================

(test svg-get-renderer-creates-renderer
  "get-renderer returns a renderer-svg instance with correct w/h/dpi."
  (let* ((canvas (make-instance 'canvas-svg :width 320 :height 240 :dpi 72))
         (renderer (get-renderer canvas)))
    (is (typep renderer 'renderer-svg))
    (is (= 320 (renderer-width renderer)))
    (is (= 240 (renderer-height renderer)))
    (is (= 72 (renderer-dpi renderer)))))

(test svg-get-renderer-caches
  "get-renderer returns the same instance on repeated calls."
  (let ((canvas (make-instance 'canvas-svg)))
    (let ((r1 (get-renderer canvas))
          (r2 (get-renderer canvas)))
      (is (eq r1 r2)))))

(test svg-renderer-is-renderer-base
  "renderer-svg is a subclass of renderer-base."
  (let* ((canvas (make-instance 'canvas-svg))
         (renderer (get-renderer canvas)))
    (is (typep renderer 'renderer-base))
    (is (typep renderer 'renderer-svg))))

;;; ============================================================
;;; Path drawing tests (use print-svg + check SVG content)
;;; ============================================================

(test svg-draw-path-line
  "Draw a simple line path and save to SVG."
  (let* ((output (tmp-svg-path "draw-line"))
         (canvas (make-instance 'canvas-svg :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 10.0) (190.0 190.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red")))
              (draw-path renderer gc path nil))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-header-valid-p output))
    (is (svg-contains-p output "<path"))))

(test svg-draw-path-filled-rect
  "Draw a filled rectangle, check fill= in SVG."
  (let* ((output (tmp-svg-path "draw-rect"))
         (canvas (make-instance 'canvas-svg :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
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
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "fill="))))

(test svg-draw-path-stroke-only
  "Draw a path with stroke only, check stroke= in SVG."
  (let* ((output (tmp-svg-path "stroke-only"))
         (canvas (make-instance 'canvas-svg :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((20.0 100.0) (180.0 100.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 3.0 :edgecolor "green")))
              (draw-path renderer gc path nil))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "stroke="))))

(test svg-draw-path-dashed
  "Draw a dashed line, check stroke-dasharray in SVG."
  (let* ((output (tmp-svg-path "dashed-line"))
         (canvas (make-instance 'canvas-svg :width 400 :height 300 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((50.0 150.0) (350.0 150.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 3.0 :edgecolor "black" :dashes '(5.0 3.0))))
              (draw-path renderer gc path nil))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "stroke-dasharray"))))

(test svg-draw-path-with-clip
  "Draw a clipped path, check <clipPath in SVG."
  (let* ((output (tmp-svg-path "clipped"))
         (canvas (make-instance 'canvas-svg :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 10.0) (190.0 190.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red"
                                             :clip-rectangle (mpl.primitives:make-bbox 50 50 200 150))))
              (draw-path renderer gc path nil))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "<clipPath"))))

;;; ============================================================
;;; Text rendering tests
;;; ============================================================

(test svg-draw-text-basic
  "Draw text, check <text and font-family in SVG."
  (let* ((output (tmp-svg-path "text-basic"))
         (canvas (make-instance 'canvas-svg :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 16.0)))
              (draw-text renderer gc 20.0 50.0 "Hello SVG" nil 0))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "<text"))
    (is (svg-contains-p output "font-family=\"DejaVu Sans\""))))

(test svg-draw-text-center-aligned
  "Draw center-aligned text, check text-anchor=\"middle\" in SVG."
  (let* ((output (tmp-svg-path "text-center"))
         (canvas (make-instance 'canvas-svg :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 14.0)))
              (draw-text renderer gc 100.0 50.0 "Centered" nil 0.0 nil :center :baseline))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "text-anchor=\"middle\""))))

(test svg-draw-text-empty-string
  "Empty string produces no <text output."
  (let* ((output (tmp-svg-path "text-empty"))
         (canvas (make-instance 'canvas-svg :width 200 :height 100 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 12.0)))
              (draw-text renderer gc 50.0 50.0 "" nil 0))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (not (svg-contains-p output "<text")))))

(test svg-draw-text-xml-escape
  "Text with <>&, check escaped entities in SVG."
  (let* ((output (tmp-svg-path "text-escape"))
         (canvas (make-instance 'canvas-svg :width 300 :height 100 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 12.0)))
              (draw-text renderer gc 20.0 50.0 "x < y & z > w" nil 0))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "&lt;"))
    (is (svg-contains-p output "&amp;"))
    (is (svg-contains-p output "&gt;"))))

;;; ============================================================
;;; Image embedding tests
;;; ============================================================

(test svg-draw-image-base64
  "Draw a 2x2 image, check <image and data:image/png;base64, in SVG."
  (let* ((output (tmp-svg-path "image-b64"))
         (canvas (make-instance 'canvas-svg :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let* ((w 2) (h 2)
                   (data (make-array (* w h 4) :element-type '(unsigned-byte 8)
                                                :initial-element 128)))
              (draw-image renderer nil 50 50
                          (list :data data :width w :height h)))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "<image"))
    (is (svg-contains-p output "data:image/png;base64,"))))

(test svg-draw-image-no-temp-files
  "Verify no /tmp/cl-mpl-svg-*.png left behind after draw-image."
  (let* ((output (tmp-svg-path "image-noleaks"))
         (canvas (make-instance 'canvas-svg :width 100 :height 100 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let* ((w 2) (h 2)
                   (data (make-array (* w h 4) :element-type '(unsigned-byte 8)
                                                :initial-element 200)))
              (draw-image renderer nil 10 10
                          (list :data data :width w :height h)))))
    (print-svg canvas output)
    ;; Check no temp PNG files remain
    (let ((leftover (directory "/tmp/cl-mpl-svg-*.png")))
      (is (null leftover)))))

;;; ============================================================
;;; Marker tests
;;; ============================================================

(test svg-draw-markers-symbol-use
  "Draw markers, check <symbol and <use in SVG."
  (let* ((output (tmp-svg-path "markers"))
         (canvas (make-instance 'canvas-svg :width 300 :height 200 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let* ((marker-path (mpl.primitives:make-path
                                 :vertices '((-3.0 -3.0) (3.0 -3.0) (3.0 3.0) (-3.0 3.0) (-3.0 -3.0))
                                 :codes (list mpl.primitives:+moveto+
                                              mpl.primitives:+lineto+
                                              mpl.primitives:+lineto+
                                              mpl.primitives:+lineto+
                                              mpl.primitives:+closepoly+)))
                   (data-path (mpl.primitives:make-path
                               :vertices '((50.0 50.0) (150.0 100.0) (250.0 50.0))
                               :codes (list mpl.primitives:+moveto+
                                            mpl.primitives:+lineto+
                                            mpl.primitives:+lineto+)))
                   (gc (make-graphics-context :facecolor "blue" :edgecolor "black" :linewidth 1.0)))
              (draw-markers renderer gc marker-path nil data-path nil))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output))
    (is (svg-contains-p output "<symbol"))
    (is (svg-contains-p output "<use"))))

;;; ============================================================
;;; Output structure tests
;;; ============================================================

(test svg-print-svg-valid-header
  "Check <?xml and <svg xmlns= in file."
  (let* ((output (tmp-svg-path "header"))
         (canvas (make-instance 'canvas-svg :width 100 :height 100 :dpi 100)))
    (print-svg canvas output)
    (is (svg-contains-p output "<?xml"))
    (is (svg-contains-p output "<svg xmlns="))))

(test svg-print-svg-has-defs
  "Check <defs> in SVG."
  (let* ((output (tmp-svg-path "defs"))
         (canvas (make-instance 'canvas-svg :width 100 :height 100 :dpi 100)))
    (print-svg canvas output)
    (is (svg-contains-p output "<defs>"))))

(test svg-print-svg-has-y-flip
  "Check translate(0, and scale(1,-1) in SVG."
  (let* ((output (tmp-svg-path "yflip"))
         (canvas (make-instance 'canvas-svg :width 200 :height 300 :dpi 100)))
    (print-svg canvas output)
    (is (svg-contains-p output "translate(0,"))
    (is (svg-contains-p output "scale(1,-1)"))))

(test svg-print-svg-closes-properly
  "Check </svg> at end of file."
  (let* ((output (tmp-svg-path "closing"))
         (canvas (make-instance 'canvas-svg :width 100 :height 100 :dpi 100)))
    (print-svg canvas output)
    (is (svg-contains-p output "</svg>"))))

;;; ============================================================
;;; Integration test
;;; ============================================================

(test svg-integration-full-pipeline
  "Create canvas, draw line + text, save, check content."
  (let* ((output (tmp-svg-path "integration"))
         (canvas (make-instance 'canvas-svg :width 640 :height 480 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            ;; Draw a red line
            (let ((path (mpl.primitives:make-path
                         :vertices '((100.0 100.0) (500.0 400.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red")))
              (draw-path renderer gc path nil))
            ;; Draw text
            (let ((gc (make-graphics-context :edgecolor "black" :linewidth 18.0)))
              (draw-text renderer gc 100.0 440.0 "Integration Test" nil 0))))
    (print-svg canvas output)
    (is (file-exists-and-valid-p output 200))
    (is (svg-contains-p output "<path"))
    (is (svg-contains-p output "<text"))))

;;; ============================================================
;;; Regression guards
;;; ============================================================

(test svg-regression-vecto-still-works
  "Vecto renderer can still be instantiated."
  (is (typep (make-instance 'mpl.backends:renderer-vecto) 'renderer-base)))

(test svg-regression-pdf-still-works
  "PDF renderer can still be instantiated."
  (is (typep (make-instance 'mpl.backends:renderer-pdf) 'renderer-base)))

;;; ============================================================
;;; Render-to-svg convenience function test
;;; ============================================================

(test svg-render-to-svg-convenience
  "render-to-svg convenience function works."
  (let ((output (tmp-svg-path "convenience")))
    (render-to-svg output
                   :width 100 :height 100
                   :draw-fn (lambda (renderer)
                              (let ((path (mpl.primitives:make-path
                                           :vertices '((10.0 10.0) (90.0 90.0))
                                           :codes (list mpl.primitives:+moveto+
                                                        mpl.primitives:+lineto+)))
                                    (gc (make-graphics-context :linewidth 1.0 :edgecolor "black")))
                                (draw-path renderer gc path nil))))
    (is (file-exists-and-valid-p output))
    (is (svg-header-valid-p output))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

;;; ============================================================
;;; Destination tests — file / stream / string
;;; ============================================================

(defun %line-canvas ()
  "A canvas that draws one red line; used by the destination tests."
  (let ((canvas (make-instance 'canvas-svg :width 200 :height 200 :dpi 100)))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (let ((path (mpl.primitives:make-path
                         :vertices '((10.0 10.0) (190.0 190.0))
                         :codes (list mpl.primitives:+moveto+ mpl.primitives:+lineto+)))
                  (gc (make-graphics-context :linewidth 2.0 :edgecolor "red")))
              (draw-path renderer gc path nil))))
    canvas))

(test svg-print-svg-nil-returns-string
  "print-svg with a NIL destination returns the SVG document as a string."
  (let ((doc (print-svg (%line-canvas) nil)))
    (is (stringp doc))
    (is (eql 0 (search "<?xml" doc)))
    (is (search "<path" doc))
    (is (search "</svg>" doc))))

(test svg-print-svg-destinations-agree
  "File, stream and string destinations produce identical documents."
  (let* ((output (tmp-svg-path "destinations"))
         (from-string (print-svg (%line-canvas) nil))
         (from-stream (with-output-to-string (s)
                        (is (eq s (print-svg (%line-canvas) s)))))
         (from-file (progn
                      (is (equal output (print-svg (%line-canvas) output)))
                      (with-open-file (s output :external-format :utf-8)
                        (let ((content (make-string (file-length s))))
                          (subseq content 0 (read-sequence content s)))))))
    (is (string= from-string from-stream))
    (is (string= from-string from-file))))

;;; ============================================================
;;; Vertical text alignment — baseline shift from font metrics
;;; ============================================================

(defun %text-element-for (va)
  "The <text ...> element emitted for the string \"Title\" with vertical alignment VA."
  (let* ((canvas (make-instance 'canvas-svg :width 200 :height 100 :dpi 100))
         (gc (make-graphics-context :linewidth 20.0 :edgecolor "black")))
    (setf (canvas-render-fn-svg canvas)
          (lambda (renderer)
            (draw-text renderer gc 100.0d0 90.0d0 "Title" nil 0.0d0 nil :center va)))
    (let* ((doc (print-svg canvas nil))
           (start (search "<text" doc))
           (end (search "</text>" doc)))
      (subseq doc start end))))

(defun %y-attr (element)
  "The numeric value of ELEMENT's y=\"...\" attribute, or NIL."
  (let ((pos (search " y=\"" element)))
    (when pos
      (let ((from (+ pos 4)))
        (read-from-string (subseq element from (position #\" element :start from)))))))

(test svg-text-valign-uses-baseline-shift-not-dominant-baseline
  "Vertical alignment is a metric-derived y offset; librsvg (Emacs) ignores dominant-baseline."
  (let ((top (%text-element-for :top))
        (center (%text-element-for :center))
        (bottom (%text-element-for :bottom))
        (baseline (%text-element-for :baseline)))
    (is-false (search "dominant-baseline" top))
    (is-false (search "dominant-baseline" center))
    (is-false (search "dominant-baseline" bottom))
    ;; :baseline needs no shift at all
    (is (null (%y-attr baseline)))
    ;; :top shifts the baseline down by the ascent: 0.5-1x the 20px font size
    (let ((y (%y-attr top)))
      (is (and y (< 10 y 20))))
    ;; :center is roughly half of :top for a string without descenders
    (let ((yt (%y-attr top)) (yc (%y-attr center)))
      (is (and yt yc (< (abs (- yc (/ yt 2))) 1.5))))
    ;; :bottom moves the baseline up (toward the ascenders) for "Title": no descenders, ~0
    (let ((y (%y-attr bottom)))
      (is (or (null y) (<= -1.0 y 0.5))))))

(defun run-svg-backend-tests ()
  "Run all svg backend tests, signaling an error on failure."
  (let ((results (run 'backend-svg-suite)))
    (explain! results)
    (unless (results-status results)
      (error "Svg backend tests failed"))
    results))
