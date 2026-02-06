;;;; test-artist.lisp — Tests for artist hierarchy and rendering primitives
;;;; Phase 3a — FiveAM test suite

(defpackage #:cl-matplotlib.tests.artist
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rendering
                #:artist #:draw #:get-path #:get-patch-transform #:get-artist-transform
                #:artist-alpha #:artist-visible #:artist-label #:artist-zorder
                #:artist-transform #:artist-clip-box #:artist-clip-path
                #:artist-animated #:artist-picker #:artist-url #:artist-gid
                #:artist-rasterized #:artist-sketch-params #:artist-stale
                #:artist-set #:stale-p
                ;; Mock renderer
                #:mock-renderer #:make-mock-renderer #:mock-renderer-calls
                #:renderer-draw-path #:renderer-draw-text
                ;; Graphics context
                #:graphics-context #:make-gc
                ;; Line2D
                #:line-2d #:line-2d-xdata #:line-2d-ydata
                #:line-2d-linewidth #:line-2d-linestyle #:line-2d-color
                #:line-2d-marker #:line-2d-markersize #:line-2d-set-data
                ;; Patches
                #:patch #:patch-edgecolor #:patch-facecolor #:patch-linewidth
                #:rectangle #:rectangle-x0 #:rectangle-y0
                #:rectangle-width #:rectangle-height #:rectangle-angle
                #:ellipse #:ellipse-center #:ellipse-width #:ellipse-height #:ellipse-angle
                #:circle #:circle-radius
                #:polygon #:polygon-xy #:polygon-closed
                #:wedge #:wedge-center #:wedge-r #:wedge-theta1 #:wedge-theta2
                #:arc #:arc-theta1 #:arc-theta2
                #:path-patch #:path-patch-path
                #:fancy-bbox-patch #:fancy-bbox-x0 #:fancy-bbox-y0
                ;; Text
                #:text-artist #:text-x #:text-y #:text-text #:text-color
                #:text-fontsize #:text-rotation
                #:text-horizontalalignment #:text-verticalalignment
                ;; Markers
                #:marker-style #:marker-style-marker #:marker-style-path
                #:marker-style-filled-p #:make-marker-path #:make-marker-style
                ;; Image
                #:axes-image #:image-data #:image-extent #:image-interpolation))

(in-package #:cl-matplotlib.tests.artist)

(def-suite artist-suite :description "Artist hierarchy test suite")
(in-suite artist-suite)

;;; ============================================================
;;; Artist base class tests
;;; ============================================================

(test artist-creation
  "Test that artist base class can be created with defaults."
  (let ((a (make-instance 'artist)))
    (is (null (artist-alpha a)))
    (is (eq t (artist-visible a)))
    (is (string= "" (artist-label a)))
    (is (= 0 (artist-zorder a)))
    (is (null (artist-animated a)))
    (is (null (artist-picker a)))
    (is (null (artist-url a)))
    (is (null (artist-gid a)))
    (is (null (artist-rasterized a)))
    (is (null (artist-sketch-params a)))
    (is (eq t (artist-stale a)))))

(test artist-creation-with-kwargs
  "Test artist creation with keyword arguments."
  (let ((a (make-instance 'artist
                          :alpha 0.5d0
                          :visible nil
                          :label "test"
                          :zorder 5
                          :url "http://example.com"
                          :gid "group1")))
    (is (= 0.5d0 (artist-alpha a)))
    (is (null (artist-visible a)))
    (is (string= "test" (artist-label a)))
    (is (= 5 (artist-zorder a)))
    (is (string= "http://example.com" (artist-url a)))
    (is (string= "group1" (artist-gid a)))))

(test artist-property-setting
  "Test setting artist properties."
  (let ((a (make-instance 'artist)))
    (setf (artist-alpha a) 0.8d0)
    (is (= 0.8d0 (artist-alpha a)))
    (setf (artist-visible a) nil)
    (is (null (artist-visible a)))
    (setf (artist-label a) "my label")
    (is (string= "my label" (artist-label a)))))

(test artist-set-bulk
  "Test bulk property setting."
  (let ((a (make-instance 'artist)))
    (artist-set a :alpha 0.5d0 :label "test" :zorder 3)
    (is (= 0.5d0 (artist-alpha a)))
    (is (string= "test" (artist-label a)))
    (is (= 3 (artist-zorder a)))))

(test artist-stale-tracking
  "Test that stale flag is set after property changes."
  (let ((a (make-instance 'artist)))
    (setf (artist-stale a) nil)
    (setf (artist-alpha a) 0.5d0)
    (is (eq t (artist-stale a)))))

;;; ============================================================
;;; Mock renderer tests
;;; ============================================================

(test mock-renderer
  "Test mock renderer records calls."
  (let ((r (make-mock-renderer)))
    (is (null (mock-renderer-calls r)))
    (renderer-draw-path r nil nil nil)
    (is (= 1 (length (mock-renderer-calls r))))
    (is (eq :draw-path (caar (mock-renderer-calls r))))))

;;; ============================================================
;;; Line2D tests
;;; ============================================================

(test line-2d-creation
  "Test Line2D creation with data."
  (let ((line (make-instance 'line-2d
                             :xdata #(0.0d0 1.0d0 2.0d0)
                             :ydata #(0.0d0 1.0d0 0.0d0))))
    (is (= 3 (length (line-2d-xdata line))))
    (is (= 3 (length (line-2d-ydata line))))
    (is (= 0.0d0 (aref (line-2d-xdata line) 0)))
    (is (= 2.0d0 (aref (line-2d-xdata line) 2)))
    (is (= 2 (artist-zorder line)))))

(test line-2d-creation-from-lists
  "Test Line2D creation from lists."
  (let ((line (make-instance 'line-2d
                             :xdata '(0 1 2)
                             :ydata '(0 1 0))))
    (is (= 3 (length (line-2d-xdata line))))
    (is (= 0.0d0 (aref (line-2d-xdata line) 0)))
    (is (= 1.0d0 (aref (line-2d-ydata line) 1)))))

(test line-2d-properties
  "Test Line2D property defaults and setting."
  (let ((line (make-instance 'line-2d
                             :xdata '(0 1)
                             :ydata '(0 1)
                             :color "red"
                             :linewidth 2.0)))
    (is (string= "red" (line-2d-color line)))
    (is (= 2.0 (line-2d-linewidth line)))
    (is (eq :solid (line-2d-linestyle line)))
    (is (eq :none (line-2d-marker line)))))

(test line-2d-get-path
  "Test Line2D path generation."
  (let ((line (make-instance 'line-2d
                             :xdata '(0 1 2)
                             :ydata '(0 1 0))))
    (let ((path (get-path line)))
      (is (not (null path)))
      (is (= 3 (mpl.primitives:path-length path))))))

(test line-2d-draw
  "Test Line2D draw dispatches to renderer."
  (let ((line (make-instance 'line-2d
                             :xdata '(0 1 2)
                             :ydata '(0 1 0)
                             :color "blue"))
        (r (make-mock-renderer)))
    (draw line r)
    (is (= 1 (length (mock-renderer-calls r))))
    (is (eq :draw-path (caar (mock-renderer-calls r))))))

(test line-2d-set-data
  "Test Line2D set-data."
  (let ((line (make-instance 'line-2d
                             :xdata '(0 1)
                             :ydata '(0 1))))
    (line-2d-set-data line '(0 1 2 3) '(0 2 4 6))
    (is (= 4 (length (line-2d-xdata line))))
    (is (= 4 (length (line-2d-ydata line))))))

;;; ============================================================
;;; Rectangle tests
;;; ============================================================

(test rectangle-creation
  "Test rectangle creation."
  (let ((rect (make-instance 'rectangle
                             :xy '(0.0 0.0)
                             :width 1.0d0
                             :height 1.0d0)))
    (is (= 0.0d0 (rectangle-x0 rect)))
    (is (= 0.0d0 (rectangle-y0 rect)))
    (is (= 1.0d0 (rectangle-width rect)))
    (is (= 1.0d0 (rectangle-height rect)))
    (is (= 0.0d0 (rectangle-angle rect)))
    (is (= 1 (artist-zorder rect)))))

(test rectangle-creation-with-colors
  "Test rectangle with face and edge colors."
  (let ((rect (make-instance 'rectangle
                             :xy '(1.0 2.0)
                             :width 3.0d0
                             :height 4.0d0
                             :facecolor "blue"
                             :edgecolor "red")))
    (is (string= "blue" (patch-facecolor rect)))
    (is (string= "red" (patch-edgecolor rect)))))

(test rectangle-path
  "Test rectangle path is unit rectangle."
  (let ((rect (make-instance 'rectangle
                             :xy '(0.0 0.0) :width 1.0d0 :height 1.0d0)))
    (let ((path (get-path rect)))
      (is (not (null path))))))

(test rectangle-draw
  "Test rectangle draw dispatches."
  (let ((rect (make-instance 'rectangle
                             :xy '(0.0 0.0) :width 1.0d0 :height 1.0d0
                             :facecolor "blue"))
        (r (make-mock-renderer)))
    (draw rect r)
    (is (= 1 (length (mock-renderer-calls r))))
    (is (eq :draw-path (caar (mock-renderer-calls r))))))

;;; ============================================================
;;; Circle tests
;;; ============================================================

(test circle-creation
  "Test circle creation."
  (let ((c (make-instance 'circle
                          :center '(0.0 0.0)
                          :radius 5.0d0)))
    (is (= 5.0d0 (circle-radius c)))
    (is (= 10.0d0 (ellipse-width c)))
    (is (= 10.0d0 (ellipse-height c)))))

(test circle-path
  "Test circle returns unit circle path."
  (let ((c (make-instance 'circle :center '(0.0 0.0) :radius 1.0d0)))
    (let ((path (get-path c)))
      (is (not (null path)))
      (is (> (mpl.primitives:path-length path) 0)))))

;;; ============================================================
;;; Ellipse tests
;;; ============================================================

(test ellipse-creation
  "Test ellipse creation."
  (let ((e (make-instance 'ellipse
                          :xy '(1.0 2.0)
                          :width 3.0d0
                          :height 4.0d0
                          :angle 45.0d0)))
    (is (equal '(1.0 2.0) (ellipse-center e)))
    (is (= 3.0d0 (ellipse-width e)))
    (is (= 4.0d0 (ellipse-height e)))
    (is (= 45.0d0 (ellipse-angle e)))))

;;; ============================================================
;;; Polygon tests
;;; ============================================================

(test polygon-creation
  "Test polygon creation."
  (let ((p (make-instance 'polygon
                          :xy '((0.0 0.0) (1.0 0.0) (0.5 1.0)))))
    (is (polygon-closed p))
    (let ((path (get-path p)))
      (is (not (null path))))))

;;; ============================================================
;;; Text tests
;;; ============================================================

(test text-creation
  "Test text creation."
  (let ((txt (make-instance 'text-artist
                            :text "Hello"
                            :x 0.5d0
                            :y 0.5d0)))
    (is (string= "Hello" (text-text txt)))
    (is (= 0.5d0 (text-x txt)))
    (is (= 0.5d0 (text-y txt)))
    (is (= 3 (artist-zorder txt)))))

(test text-properties
  "Test text property defaults."
  (let ((txt (make-instance 'text-artist)))
    (is (string= "" (text-text txt)))
    (is (= 12.0 (text-fontsize txt)))
    (is (eq :left (text-horizontalalignment txt)))
    (is (eq :baseline (text-verticalalignment txt)))
    (is (= 0.0 (text-rotation txt)))))

(test text-draw
  "Test text draw dispatches."
  (let ((txt (make-instance 'text-artist
                            :text "Hello"
                            :x 1.0d0 :y 2.0d0
                            :color "red"))
        (r (make-mock-renderer)))
    (draw txt r)
    (is (= 1 (length (mock-renderer-calls r))))
    (is (eq :draw-text (caar (mock-renderer-calls r))))))

(test text-draw-empty
  "Test empty text does not draw."
  (let ((txt (make-instance 'text-artist :text ""))
        (r (make-mock-renderer)))
    (draw txt r)
    (is (= 0 (length (mock-renderer-calls r))))))

;;; ============================================================
;;; Marker tests
;;; ============================================================

(test marker-circle
  "Test circle marker path generation."
  (let ((path (make-marker-path :o)))
    (is (not (null path)))
    (is (> (mpl.primitives:path-length path) 0))))

(test marker-square
  "Test square marker path generation."
  (let ((path (make-marker-path :s)))
    (is (not (null path)))
    (is (> (mpl.primitives:path-length path) 0))))

(test marker-standard-set
  "Test all standard markers generate paths."
  (dolist (m '(:o :s :^ :v :< :> :d :plus :x :star :vline :hline))
    (let ((path (make-marker-path m)))
      (is (not (null path))
          "Marker ~S should produce a path" m))))

(test marker-filled-detection
  "Test filled marker detection."
  (let ((filled-ms (make-marker-style :o))
        (unfilled-ms (make-marker-style :plus)))
    (is (marker-style-filled-p filled-ms))
    (is (not (marker-style-filled-p unfilled-ms)))))

(test marker-none
  "Test none marker produces empty path."
  (let ((path (make-marker-path :none)))
    (is (= 0 (mpl.primitives:path-length path)))))

;;; ============================================================
;;; Image tests
;;; ============================================================

(test image-creation
  "Test AxesImage creation."
  (let ((img (make-instance 'axes-image)))
    (is (null (image-data img)))
    (is (null (image-extent img)))
    (is (eq :nearest (image-interpolation img)))
    (is (= 0 (artist-zorder img)))))

(test image-with-data
  "Test AxesImage with data."
  (let* ((data (make-array '(10 10) :element-type 'double-float :initial-element 0.5d0))
         (img (make-instance 'axes-image :data data)))
    (is (not (null (image-data img))))
    (is (equal '(10 10) (array-dimensions (image-data img))))))

;;; ============================================================
;;; Draw protocol integration test
;;; ============================================================

(test draw-protocol-integration
  "Test the full draw protocol with line, rect, text."
  (let ((line (make-instance 'line-2d
                             :xdata #(0.0d0 1.0d0 2.0d0)
                             :ydata #(0.0d0 1.0d0 0.0d0)
                             :color "red"
                             :linewidth 2.0))
        (rect (make-instance 'rectangle
                             :xy '(0.0 0.0)
                             :width 1.0d0
                             :height 1.0d0
                             :facecolor "blue"))
        (txt (make-instance 'text-artist
                            :text "Hello"
                            :x 0.5d0
                            :y 0.5d0))
        (r (make-mock-renderer)))
    ;; Draw all three
    (draw line r)
    (draw rect r)
    (draw txt r)
    ;; Should have 3 calls total
    (let ((calls (mock-renderer-calls r)))
      (is (= 3 (length calls)))
      ;; Calls are in reverse order (pushed)
      (is (eq :draw-text (car (first calls))))
      (is (eq :draw-path (car (second calls))))
      (is (eq :draw-path (car (third calls)))))))

(test invisible-artist-no-draw
  "Test that invisible artists are not drawn."
  (let ((line (make-instance 'line-2d
                             :xdata '(0 1) :ydata '(0 1)
                             :visible nil))
        (r (make-mock-renderer)))
    (draw line r)
    (is (= 0 (length (mock-renderer-calls r))))))

;;; ============================================================
;;; Wedge, Arc, PathPatch, FancyBbox tests
;;; ============================================================

(test wedge-creation
  "Test wedge creation."
  (let ((w (make-instance 'wedge
                          :center '(0.0 0.0)
                          :r 1.0d0
                          :theta1 0.0d0
                          :theta2 90.0d0)))
    (is (= 0.0d0 (wedge-theta1 w)))
    (is (= 90.0d0 (wedge-theta2 w)))
    (is (= 1.0d0 (wedge-r w)))))

(test arc-creation
  "Test arc creation."
  (let ((a (make-instance 'arc
                          :xy '(0.0 0.0)
                          :width 2.0d0
                          :height 2.0d0
                          :theta1 0.0d0
                          :theta2 180.0d0)))
    (is (= 0.0d0 (arc-theta1 a)))
    (is (= 180.0d0 (arc-theta2 a)))))

(test path-patch-creation
  "Test PathPatch creation."
  (let* ((path (mpl.primitives:make-path :vertices '((0.0 0.0) (1.0 0.0) (1.0 1.0))
                                          :closed t))
         (pp (make-instance 'path-patch :path path)))
    (is (eq path (path-patch-path pp)))))

(test fancy-bbox-creation
  "Test FancyBboxPatch creation."
  (let ((fb (make-instance 'fancy-bbox-patch
                           :xy '(1.0 2.0)
                           :width 3.0d0
                           :height 4.0d0)))
    (is (= 1.0d0 (fancy-bbox-x0 fb)))
    (is (= 2.0d0 (fancy-bbox-y0 fb)))
    (is (= 3.0d0 (cl-matplotlib.rendering::fancy-bbox-width fb)))
    (is (= 4.0d0 (cl-matplotlib.rendering::fancy-bbox-height fb)))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-artist-tests ()
  "Run all artist tests and return results."
  (run! 'artist-suite))
