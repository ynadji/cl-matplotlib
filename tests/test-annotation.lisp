;;;; test-annotation.lisp — Tests for annotation, FancyArrowPatch, ConnectionStyle, BoxStyle, AnchoredText
;;;; Phase 6c — FiveAM test suite

(defpackage #:cl-matplotlib.tests.annotation
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rendering
                ;; Artist base
                #:artist #:draw #:get-path
                #:artist-alpha #:artist-visible #:artist-label #:artist-zorder
                #:artist-transform #:artist-stale
                ;; Mock renderer
                #:mock-renderer #:make-mock-renderer #:mock-renderer-calls
                #:renderer-draw-path #:renderer-draw-text
                ;; Graphics context
                #:graphics-context #:make-gc
                ;; Patch base
                #:patch #:patch-edgecolor #:patch-facecolor #:patch-linewidth
                #:patch-linestyle #:patch-capstyle #:patch-joinstyle
                ;; Text
                #:text-artist #:text-x #:text-y #:text-text #:text-color #:text-fontsize
                ;; FancyArrowPatch
                #:fancy-arrow-patch #:fancy-arrow-posA #:fancy-arrow-posB
                #:fancy-arrow-arrowstyle #:fancy-arrow-connectionstyle
                #:fancy-arrow-shrinkA #:fancy-arrow-shrinkB
                #:fancy-arrow-mutation-scale #:fancy-arrow-cached-path
                ;; ConnectionStyle
                #:connection-style #:connect #:make-connection-style
                #:arc3-connection #:arc3-rad
                #:angle3-connection #:angle3-angleA #:angle3-angleB
                #:angle-connection #:angle-angleA
                ;; BoxStyle
                #:box-style #:box-transmute #:make-box-style
                #:square-box #:round-box #:round4-box #:sawtooth-box #:roundtooth-box
                #:square-box-pad #:round-box-pad
                ;; Annotation
                #:annotation #:annotation-xy #:annotation-xytext
                #:annotation-xycoords #:annotation-textcoords
                #:annotation-arrowprops #:annotation-bbox
                #:annotation-arrow-patch
                #:annotation-set-position #:annotation-set-target
                ;; AnchoredText
                #:anchored-text #:anchored-text-text #:anchored-text-loc
                #:anchored-text-pad #:anchored-text-borderpad
                #:anchored-text-frameon #:anchored-text-fontsize
                #:anchored-text-color #:anchored-text-facecolor #:anchored-text-edgecolor)
  (:export #:run-annotation-tests))

(in-package #:cl-matplotlib.tests.annotation)

(def-suite annotation-suite :description "Annotation, FancyArrowPatch, ConnectionStyle, BoxStyle test suite")
(in-suite annotation-suite)

;;; ============================================================
;;; ConnectionStyle tests
;;; ============================================================

(test arc3-connection-straight
  "Arc3 with rad=0 produces a straight line."
  (let* ((cs (make-instance 'arc3-connection :rad 0.0d0))
         (path (connect cs '(0.0d0 0.0d0) '(10.0d0 0.0d0)))
         (verts (mpl.primitives:mpl-path-vertices path))
         (n (array-dimension verts 0)))
    (is (= 2 n))
    (is (< (abs (- (aref verts 0 0) 0.0d0)) 0.01d0))
    (is (< (abs (- (aref verts 1 0) 10.0d0)) 0.01d0))))

(test arc3-connection-curved
  "Arc3 with rad=0.3 produces a curved path (Bézier)."
  (let* ((cs (make-instance 'arc3-connection :rad 0.3d0))
         (path (connect cs '(0.0d0 0.0d0) '(10.0d0 0.0d0)))
         (verts (mpl.primitives:mpl-path-vertices path))
         (n (array-dimension verts 0)))
    ;; Should have 4 vertices (MOVETO + 3 CURVE4)
    (is (= 4 n))
    ;; Start at (0, 0)
    (is (< (abs (aref verts 0 0)) 0.01d0))
    ;; End at (10, 0)
    (is (< (abs (- (aref verts 3 0) 10.0d0)) 0.01d0))))

(test arc3-connection-factory
  "make-connection-style :arc3 works."
  (let ((cs (make-connection-style :arc3 :rad 0.5d0)))
    (is (typep cs 'arc3-connection))
    (is (= 0.5d0 (arc3-rad cs)))))

(test angle3-connection-creation
  "Angle3 connection creates a 3-vertex path."
  (let* ((cs (make-instance 'angle3-connection :angleA 90.0d0 :angleB 0.0d0))
         (path (connect cs '(0.0d0 0.0d0) '(10.0d0 5.0d0)))
         (verts (mpl.primitives:mpl-path-vertices path))
         (n (array-dimension verts 0)))
    (is (= 3 n))
    (is (< (abs (aref verts 0 0)) 0.01d0))  ;; starts at (0,0)
    (is (< (abs (- (aref verts 2 0) 10.0d0)) 0.01d0))))  ;; ends at (10,...)

(test angle3-connection-factory
  "make-connection-style :angle3 works."
  (let ((cs (make-connection-style :angle3 :angleA 45.0d0 :angleB 90.0d0)))
    (is (typep cs 'angle3-connection))
    (is (= 45.0d0 (angle3-angleA cs)))
    (is (= 90.0d0 (angle3-angleB cs)))))

(test angle-connection-creation
  "Angle connection creates a 3-vertex path."
  (let* ((cs (make-instance 'angle-connection :angleA 90.0d0))
         (path (connect cs '(0.0d0 0.0d0) '(10.0d0 5.0d0)))
         (verts (mpl.primitives:mpl-path-vertices path))
         (n (array-dimension verts 0)))
    (is (= 3 n))))

(test angle-connection-factory
  "make-connection-style :angle works."
  (let ((cs (make-connection-style :angle :angleA 45.0d0)))
    (is (typep cs 'angle-connection))
    (is (= 45.0d0 (angle-angleA cs)))))

;;; ============================================================
;;; BoxStyle tests
;;; ============================================================

(test square-box-creation
  "Square box transmutes to a closed rectangular path."
  (let* ((style (make-instance 'square-box :pad 0.3d0))
         (path (box-transmute style 0.0d0 0.0d0 10.0d0 5.0d0))
         (verts (mpl.primitives:mpl-path-vertices path))
         (n (array-dimension verts 0)))
    (is (>= n 5))
    ;; First vertex should be at (-0.3, -0.3)
    (is (< (abs (- (aref verts 0 0) -0.3d0)) 0.01d0))
    (is (< (abs (- (aref verts 0 1) -0.3d0)) 0.01d0))))

(test round-box-creation
  "Round box transmutes to a path with rounded corners."
  (let* ((style (make-instance 'round-box :pad 0.3d0))
         (path (box-transmute style 0.0d0 0.0d0 10.0d0 5.0d0))
         (n (array-dimension (mpl.primitives:mpl-path-vertices path) 0)))
    ;; Rounded box has more vertices than square
    (is (>= n 8))))

(test round4-box-creation
  "Round4 box creates a path."
  (let* ((style (make-instance 'round4-box :pad 0.2d0))
         (path (box-transmute style 1.0d0 2.0d0 8.0d0 4.0d0))
         (n (array-dimension (mpl.primitives:mpl-path-vertices path) 0)))
    (is (>= n 8))))

(test sawtooth-box-creation
  "Sawtooth box creates a rectangular path."
  (let* ((style (make-instance 'sawtooth-box :pad 0.3d0))
         (path (box-transmute style 0.0d0 0.0d0 10.0d0 5.0d0))
         (n (array-dimension (mpl.primitives:mpl-path-vertices path) 0)))
    (is (>= n 5))))

(test roundtooth-box-creation
  "Roundtooth box creates a rectangular path."
  (let* ((style (make-instance 'roundtooth-box :pad 0.3d0))
         (path (box-transmute style 0.0d0 0.0d0 10.0d0 5.0d0))
         (n (array-dimension (mpl.primitives:mpl-path-vertices path) 0)))
    (is (>= n 5))))

(test box-style-factory
  "make-box-style creates correct types."
  (is (typep (make-box-style :square) 'square-box))
  (is (typep (make-box-style :round) 'round-box))
  (is (typep (make-box-style :round4) 'round4-box))
  (is (typep (make-box-style :sawtooth) 'sawtooth-box))
  (is (typep (make-box-style :roundtooth) 'roundtooth-box)))

;;; ============================================================
;;; FancyArrowPatch tests
;;; ============================================================

(test fancy-arrow-creation
  "FancyArrowPatch can be created with posA/posB."
  (let ((fa (make-instance 'fancy-arrow-patch
                           :posA '(0.0d0 0.0d0)
                           :posB '(10.0d0 5.0d0)
                           :arrowstyle :->)))
    (is (typep fa 'fancy-arrow-patch))
    (is (equal '(0.0d0 0.0d0) (fancy-arrow-posA fa)))
    (is (equal '(10.0d0 5.0d0) (fancy-arrow-posB fa)))
    (is (eq :-> (fancy-arrow-arrowstyle fa)))
    ;; Default capstyle and joinstyle are :round
    (is (eq :round (patch-capstyle fa)))
    (is (eq :round (patch-joinstyle fa)))))

(test fancy-arrow-default-connection
  "FancyArrowPatch with posA/posB gets arc3 connection by default."
  (let ((fa (make-instance 'fancy-arrow-patch
                           :posA '(0.0d0 0.0d0)
                           :posB '(10.0d0 0.0d0))))
    (is (typep (fancy-arrow-connectionstyle fa) 'arc3-connection))))

(test fancy-arrow-get-path
  "FancyArrowPatch generates a valid path."
  (let* ((fa (make-instance 'fancy-arrow-patch
                            :posA '(0.0d0 0.0d0)
                            :posB '(10.0d0 0.0d0)
                            :arrowstyle :->))
         (path (get-path fa)))
    (is (typep path 'mpl.primitives:mpl-path))
    (is (> (mpl.primitives:path-length path) 0))))

(test fancy-arrow-styles
  "All arrow styles produce valid paths."
  (dolist (style '(:-> :<- :<-> :- :-bracket :-bar-bar :simple :fancy :wedge))
    (let* ((fa (make-instance 'fancy-arrow-patch
                              :posA '(0.0d0 0.0d0)
                              :posB '(10.0d0 5.0d0)
                              :arrowstyle style))
           (path (get-path fa)))
      (is (typep path 'mpl.primitives:mpl-path)
          "Style ~A should produce an mpl-path" style)
      (is (> (mpl.primitives:path-length path) 0)
          "Style ~A should produce non-empty path" style))))

(test fancy-arrow-draw
  "FancyArrowPatch draws without error."
  (let ((fa (make-instance 'fancy-arrow-patch
                           :posA '(0.0d0 0.0d0)
                           :posB '(10.0d0 5.0d0)
                           :arrowstyle :->
                           :edgecolor "red"
                           :linewidth 2.0))
        (renderer (make-mock-renderer)))
    (draw fa renderer)
    ;; Should have recorded draw calls
    (is (> (length (mock-renderer-calls renderer)) 0))))

(test fancy-arrow-shrink
  "FancyArrowPatch respects shrinkA/shrinkB."
  (let* ((fa-no-shrink (make-instance 'fancy-arrow-patch
                                       :posA '(0.0d0 0.0d0)
                                       :posB '(100.0d0 0.0d0)
                                       :arrowstyle :-
                                       :shrinkA 0.0d0
                                       :shrinkB 0.0d0))
         (fa-shrink (make-instance 'fancy-arrow-patch
                                    :posA '(0.0d0 0.0d0)
                                    :posB '(100.0d0 0.0d0)
                                    :arrowstyle :-
                                    :shrinkA 10.0d0
                                    :shrinkB 10.0d0))
         (path-no (get-path fa-no-shrink))
         (path-yes (get-path fa-shrink))
         (v-no (mpl.primitives:mpl-path-vertices path-no))
         (v-yes (mpl.primitives:mpl-path-vertices path-yes)))
    ;; Shrunk path should start further from origin
    (is (< (aref v-no 0 0) (aref v-yes 0 0)))
    ;; Shrunk path should end closer to origin
    (is (> (aref v-no 1 0) (aref v-yes 1 0)))))

(test fancy-arrow-mutation-scale
  "FancyArrowPatch mutation-scale affects head size."
  (let* ((fa1 (make-instance 'fancy-arrow-patch
                              :posA '(0.0d0 0.0d0)
                              :posB '(100.0d0 0.0d0)
                              :arrowstyle :->
                              :mutation-scale 1.0d0))
         (fa2 (make-instance 'fancy-arrow-patch
                              :posA '(0.0d0 0.0d0)
                              :posB '(100.0d0 0.0d0)
                              :arrowstyle :->
                              :mutation-scale 2.0d0))
         (path1 (get-path fa1))
         (path2 (get-path fa2))
         (bb1 (mpl.primitives:path-get-extents path1))
         (bb2 (mpl.primitives:path-get-extents path2)))
    ;; Larger mutation scale should produce wider bounding box (bigger head)
    (is (> (mpl.primitives:bbox-height bb2) (mpl.primitives:bbox-height bb1)))))

(test fancy-arrow-invisible
  "FancyArrowPatch with visible=nil does not draw."
  (let ((fa (make-instance 'fancy-arrow-patch
                           :posA '(0.0d0 0.0d0)
                           :posB '(10.0d0 5.0d0)
                           :visible nil))
        (renderer (make-mock-renderer)))
    (draw fa renderer)
    (is (= 0 (length (mock-renderer-calls renderer))))))

(test fancy-arrow-line-only
  "Arrow style :- produces a line-only path (no head)."
  (let* ((fa (make-instance 'fancy-arrow-patch
                            :posA '(0.0d0 0.0d0)
                            :posB '(10.0d0 0.0d0)
                            :arrowstyle :-))
         (path (get-path fa))
         (n (mpl.primitives:path-length path)))
    ;; Line only: should have 2 vertices
    (is (= 2 n))))

(test fancy-arrow-double-headed
  "Arrow style :<-> produces a path with both heads."
  (let* ((fa (make-instance 'fancy-arrow-patch
                            :posA '(0.0d0 0.0d0)
                            :posB '(50.0d0 0.0d0)
                            :arrowstyle :<->))
         (path (get-path fa))
         (n (mpl.primitives:path-length path)))
    ;; Double-headed: shaft (2) + head-a (4) + head-b (4) = 10+ vertices
    (is (> n 5))))

;;; ============================================================
;;; Annotation tests
;;; ============================================================

(test annotation-creation-basic
  "Annotation can be created with text and xy."
  (let ((ann (make-instance 'annotation
                            :text "Hello"
                            :xy '(5.0d0 10.0d0))))
    (is (typep ann 'annotation))
    (is (string= "Hello" (text-text ann)))
    (is (equal '(5.0d0 10.0d0) (annotation-xy ann)))
    ;; xytext defaults to xy
    (is (equal '(5.0d0 10.0d0) (annotation-xytext ann)))
    ;; Text position set from xytext
    (is (= 5.0d0 (text-x ann)))
    (is (= 10.0d0 (text-y ann)))
    ;; No arrow without arrowprops
    (is (null (annotation-arrow-patch ann)))))

(test annotation-creation-with-xytext
  "Annotation with different xytext and xy gets text at xytext."
  (let ((ann (make-instance 'annotation
                            :text "Point"
                            :xy '(10.0d0 20.0d0)
                            :xytext '(5.0d0 15.0d0))))
    (is (= 5.0d0 (text-x ann)))
    (is (= 15.0d0 (text-y ann)))
    ;; No arrow since no arrowprops
    (is (null (annotation-arrow-patch ann)))))

(test annotation-with-arrow
  "Annotation with arrowprops creates an arrow patch."
  (let ((ann (make-instance 'annotation
                            :text "Peak"
                            :xy '(5.0d0 25.0d0)
                            :xytext '(3.0d0 20.0d0)
                            :arrowprops '(:arrowstyle :-> :color "red" :linewidth 2))))
    (is (not (null (annotation-arrow-patch ann))))
    (is (typep (annotation-arrow-patch ann) 'fancy-arrow-patch))
    ;; Arrow goes from xytext to xy
    (let ((arrow (annotation-arrow-patch ann)))
      (is (equal '(3.0d0 20.0d0) (fancy-arrow-posA arrow)))
      (is (equal '(5.0d0 25.0d0) (fancy-arrow-posB arrow)))
      (is (string= "red" (patch-edgecolor arrow))))))

(test annotation-no-arrow-when-same-position
  "Annotation with xytext=xy does not create an arrow."
  (let ((ann (make-instance 'annotation
                            :text "Here"
                            :xy '(5.0d0 10.0d0)
                            :xytext '(5.0d0 10.0d0)
                            :arrowprops '(:arrowstyle :->))))
    (is (null (annotation-arrow-patch ann)))))

(test annotation-xycoords-default
  "Annotation defaults to :data xycoords."
  (let ((ann (make-instance 'annotation :text "Test" :xy '(0.0d0 0.0d0))))
    (is (eq :data (annotation-xycoords ann)))
    (is (eq :data (annotation-textcoords ann)))))

(test annotation-custom-xycoords
  "Annotation respects custom xycoords."
  (let ((ann (make-instance 'annotation
                            :text "Test"
                            :xy '(0.5d0 0.5d0)
                            :xycoords :axes)))
    (is (eq :axes (annotation-xycoords ann)))
    (is (eq :axes (annotation-textcoords ann)))))

(test annotation-draw
  "Annotation draws text (and arrow if present) without error."
  (let ((ann (make-instance 'annotation
                            :text "Peak"
                            :xy '(5.0d0 25.0d0)
                            :xytext '(3.0d0 20.0d0)
                            :arrowprops '(:arrowstyle :-> :color "red")))
        (renderer (make-mock-renderer)))
    (draw ann renderer)
    ;; Should have draw calls (arrow + text)
    (is (> (length (mock-renderer-calls renderer)) 0))))

(test annotation-draw-no-arrow
  "Annotation without arrow draws only text."
  (let ((ann (make-instance 'annotation
                            :text "Label"
                            :xy '(1.0d0 2.0d0)))
        (renderer (make-mock-renderer)))
    (draw ann renderer)
    ;; Should have at least 1 draw call (text)
    (is (>= (length (mock-renderer-calls renderer)) 1))))

(test annotation-draw-with-bbox
  "Annotation with bbox draws background box."
  (let ((ann (make-instance 'annotation
                            :text "Boxed"
                            :xy '(5.0d0 10.0d0)
                            :bbox '(:boxstyle :round :facecolor "wheat" :edgecolor "black")))
        (renderer (make-mock-renderer)))
    (draw ann renderer)
    ;; Should have at least 2 draw calls (box + text)
    (is (>= (length (mock-renderer-calls renderer)) 2))))

(test annotation-set-position-updates
  "annotation-set-position updates text and arrow."
  (let ((ann (make-instance 'annotation
                            :text "Moving"
                            :xy '(10.0d0 20.0d0)
                            :xytext '(5.0d0 15.0d0)
                            :arrowprops '(:arrowstyle :->))))
    (annotation-set-position ann '(7.0d0 12.0d0))
    (is (= 7.0d0 (text-x ann)))
    (is (= 12.0d0 (text-y ann)))
    (is (equal '(7.0d0 12.0d0) (fancy-arrow-posA (annotation-arrow-patch ann))))))

(test annotation-set-target-updates
  "annotation-set-target updates arrow endpoint."
  (let ((ann (make-instance 'annotation
                            :text "Targeting"
                            :xy '(10.0d0 20.0d0)
                            :xytext '(5.0d0 15.0d0)
                            :arrowprops '(:arrowstyle :->))))
    (annotation-set-target ann '(15.0d0 25.0d0))
    (is (equal '(15.0d0 25.0d0) (annotation-xy ann)))
    (is (equal '(15.0d0 25.0d0) (fancy-arrow-posB (annotation-arrow-patch ann))))))

(test annotation-inherits-from-text
  "Annotation inherits from text-artist and has text properties."
  (let ((ann (make-instance 'annotation
                            :text "Inherited"
                            :xy '(1.0d0 2.0d0)
                            :fontsize 14.0
                            :color "blue")))
    (is (typep ann 'text-artist))
    (is (= 14.0d0 (text-fontsize ann)))
    (is (string= "blue" (text-color ann)))))

(test annotation-invisible
  "Invisible annotation does not draw."
  (let ((ann (make-instance 'annotation
                            :text "Hidden"
                            :xy '(1.0d0 2.0d0)
                            :visible nil))
        (renderer (make-mock-renderer)))
    (draw ann renderer)
    (is (= 0 (length (mock-renderer-calls renderer))))))

(test annotation-arrow-style-configurable
  "Arrow arrowstyle from arrowprops is used."
  (let ((ann (make-instance 'annotation
                            :text "Styled"
                            :xy '(10.0d0 10.0d0)
                            :xytext '(5.0d0 5.0d0)
                            :arrowprops '(:arrowstyle :<-> :color "green"))))
    (let ((arrow (annotation-arrow-patch ann)))
      (is (eq :<-> (fancy-arrow-arrowstyle arrow)))
      (is (string= "green" (patch-edgecolor arrow))))))

(test annotation-connection-style
  "Arrow connectionstyle from arrowprops is used."
  (let ((ann (make-instance 'annotation
                            :text "Curved"
                            :xy '(10.0d0 10.0d0)
                            :xytext '(5.0d0 5.0d0)
                            :arrowprops '(:arrowstyle :-> :connectionstyle :angle3))))
    (let ((arrow (annotation-arrow-patch ann)))
      (is (typep (fancy-arrow-connectionstyle arrow) 'angle3-connection)))))

;;; ============================================================
;;; AnchoredText tests
;;; ============================================================

(test anchored-text-creation
  "AnchoredText can be created with defaults."
  (let ((at (make-instance 'anchored-text
                           :text "Legend"
                           :loc :upper-right)))
    (is (typep at 'anchored-text))
    (is (string= "Legend" (anchored-text-text at)))
    (is (eq :upper-right (anchored-text-loc at)))
    (is (= 0.4d0 (anchored-text-pad at)))
    (is (= 0.5d0 (anchored-text-borderpad at)))
    (is (eq t (anchored-text-frameon at)))
    (is (= 12.0 (anchored-text-fontsize at)))))

(test anchored-text-locations
  "AnchoredText supports all location keywords."
  (dolist (loc '(:upper-left :upper-right :lower-left :lower-right :center
                 :center-left :center-right :upper-center :lower-center))
    (let ((at (make-instance 'anchored-text :text "Test" :loc loc)))
      (is (eq loc (anchored-text-loc at))))))

(test anchored-text-draw
  "AnchoredText draws without error."
  (let ((at (make-instance 'anchored-text
                           :text "Sample"
                           :loc :upper-right))
        (renderer (make-mock-renderer)))
    (draw at renderer)
    ;; Should have at least 2 calls (box + text)
    (is (>= (length (mock-renderer-calls renderer)) 2))))

(test anchored-text-no-frame
  "AnchoredText with frameon=nil draws only text."
  (let ((at (make-instance 'anchored-text
                           :text "NoFrame"
                           :loc :upper-left
                           :frameon nil))
        (renderer (make-mock-renderer)))
    (draw at renderer)
    ;; Should have exactly 1 call (text only, no box)
    (is (= 1 (length (mock-renderer-calls renderer))))))

(test anchored-text-empty
  "AnchoredText with empty text does not draw."
  (let ((at (make-instance 'anchored-text :text "" :loc :center))
        (renderer (make-mock-renderer)))
    (draw at renderer)
    (is (= 0 (length (mock-renderer-calls renderer))))))

(test anchored-text-invisible
  "Invisible AnchoredText does not draw."
  (let ((at (make-instance 'anchored-text
                           :text "Hidden"
                           :loc :center
                           :visible nil))
        (renderer (make-mock-renderer)))
    (draw at renderer)
    (is (= 0 (length (mock-renderer-calls renderer))))))

(test anchored-text-custom-colors
  "AnchoredText custom colors are stored."
  (let ((at (make-instance 'anchored-text
                           :text "Colored"
                           :loc :lower-left
                           :color "blue"
                           :facecolor "yellow"
                           :edgecolor "red")))
    (is (string= "blue" (anchored-text-color at)))
    (is (string= "yellow" (anchored-text-facecolor at)))
    (is (string= "red" (anchored-text-edgecolor at)))))

(test anchored-text-zorder
  "AnchoredText has zorder=5 by default."
  (let ((at (make-instance 'anchored-text :text "Z" :loc :center)))
    (is (= 5 (artist-zorder at)))))

;;; ============================================================
;;; Integration tests: FancyArrowPatch + ConnectionStyle
;;; ============================================================

(test fancy-arrow-with-arc3
  "FancyArrowPatch with arc3 connection generates curved path."
  (let* ((fa (make-instance 'fancy-arrow-patch
                            :posA '(0.0d0 0.0d0)
                            :posB '(10.0d0 0.0d0)
                            :connectionstyle (make-instance 'arc3-connection :rad 0.3d0)
                            :arrowstyle :->))
         (path (get-path fa)))
    (is (> (mpl.primitives:path-length path) 2))))

(test fancy-arrow-with-angle3
  "FancyArrowPatch with angle3 connection generates angled path."
  (let* ((fa (make-instance 'fancy-arrow-patch
                            :posA '(0.0d0 0.0d0)
                            :posB '(10.0d0 5.0d0)
                            :connectionstyle (make-instance 'angle3-connection)
                            :arrowstyle :->))
         (path (get-path fa)))
    (is (> (mpl.primitives:path-length path) 2))))

(test fancy-arrow-with-custom-colors
  "FancyArrowPatch stores custom edge/face colors."
  (let ((fa (make-instance 'fancy-arrow-patch
                           :posA '(0.0d0 0.0d0)
                           :posB '(10.0d0 5.0d0)
                           :edgecolor "red"
                           :facecolor "blue")))
    (is (string= "red" (patch-edgecolor fa)))
    (is (string= "blue" (patch-facecolor fa)))))

(test fancy-arrow-zorder
  "FancyArrowPatch has zorder=2 by default."
  (let ((fa (make-instance 'fancy-arrow-patch
                           :posA '(0.0d0 0.0d0)
                           :posB '(10.0d0 5.0d0))))
    (is (= 2 (artist-zorder fa)))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-annotation-tests ()
  "Run all annotation tests and report results."
  (let ((results (run 'annotation-suite)))
    (explain! results)
    (unless (results-status results)
      (error "Annotation tests failed!"))))
