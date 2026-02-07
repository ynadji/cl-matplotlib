;;;; test-collections.lisp — Tests for Collection classes and hatch patterns
;;;; Phase 5c — FiveAM test suite

(defpackage #:cl-matplotlib.tests.collections
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rendering
                ;; Hatch
                #:hatch-get-path #:*valid-hatch-patterns*
                ;; Collection base
                #:collection #:collection-offsets #:collection-trans-offset
                #:collection-facecolors #:collection-edgecolors
                #:collection-linewidths #:collection-linestyles
                #:collection-antialiaseds #:collection-hatch
                #:collection-pickradius #:collection-capstyle #:collection-joinstyle
                #:collection-set-offsets #:collection-set-facecolor
                #:collection-set-edgecolor #:collection-set-linewidth
                #:collection-set-color #:collection-get-paths
                ;; LineCollection
                #:line-collection #:line-collection-segments
                #:collection-set-segments #:make-line-collection
                ;; PathCollection
                #:path-collection #:path-collection-paths #:path-collection-sizes
                #:collection-set-paths #:collection-set-sizes
                #:make-path-collection #:collection-get-transforms
                ;; PatchCollection
                #:patch-collection #:patch-collection-patches
                #:collection-set-patches
                ;; PolyCollection
                #:poly-collection #:poly-collection-verts
                #:collection-set-verts
                ;; QuadMesh
                #:quad-mesh #:quad-mesh-width #:quad-mesh-height
                #:quad-mesh-coordinates
                ;; Artist protocol
                #:artist-alpha #:artist-visible #:artist-stale
                #:artist-zorder #:artist-label #:artist-transform
                #:draw
                ;; Mock renderer
                #:mock-renderer #:make-mock-renderer #:mock-renderer-calls
                ;; Graphics context
                #:make-gc
                ;; Patches (for PatchCollection)
                #:rectangle #:circle
                ;; Markers
                #:make-marker-path)
  (:export #:run-collection-tests))

(in-package #:cl-matplotlib.tests.collections)

(def-suite collection-suite :description "Collection classes test suite")
(in-suite collection-suite)

;;; ============================================================
;;; Hatch pattern tests
;;; ============================================================

(test hatch-nil-returns-nil
  "hatch-get-path with nil or empty string returns nil."
  (is (null (hatch-get-path nil)))
  (is (null (hatch-get-path ""))))

(test hatch-horizontal
  "Horizontal hatch pattern produces a path."
  (let ((path (hatch-get-path "-")))
    (is (not (null path)))
    (is (typep path 'mpl.primitives:mpl-path))
    (let ((verts (mpl.primitives:mpl-path-vertices path)))
      (is (plusp (array-dimension verts 0))))))

(test hatch-vertical
  "Vertical hatch pattern produces a path."
  (let ((path (hatch-get-path "|")))
    (is (not (null path)))
    (let ((verts (mpl.primitives:mpl-path-vertices path)))
      (is (plusp (array-dimension verts 0))))))

(test hatch-diagonal-northeast
  "Forward diagonal hatch pattern produces a path."
  (let ((path (hatch-get-path "/")))
    (is (not (null path)))
    (let ((verts (mpl.primitives:mpl-path-vertices path)))
      (is (plusp (array-dimension verts 0))))))

(test hatch-diagonal-southeast
  "Backslash diagonal hatch pattern produces a path."
  (let ((path (hatch-get-path "\\")))
    (is (not (null path)))
    (let ((verts (mpl.primitives:mpl-path-vertices path)))
      (is (plusp (array-dimension verts 0))))))

(test hatch-cross
  "Cross hatch (+) generates both horizontal and vertical lines."
  (let ((path (hatch-get-path "+")))
    (is (not (null path)))
    (let* ((verts (mpl.primitives:mpl-path-vertices path))
           (n (array-dimension verts 0)))
      ;; '+' generates both horizontal and vertical → more vertices than just '-' or '|'
      (is (>= n 4)))))

(test hatch-x
  "X hatch generates both diagonal directions."
  (let ((path (hatch-get-path "x")))
    (is (not (null path)))
    (let* ((verts (mpl.primitives:mpl-path-vertices path))
           (n (array-dimension verts 0)))
      (is (>= n 4)))))

(test hatch-density-increases
  "Repeating pattern character increases density (more vertices)."
  (let ((path1 (hatch-get-path "/"))
        (path2 (hatch-get-path "//")))
    (is (not (null path1)))
    (is (not (null path2)))
    (let ((n1 (array-dimension (mpl.primitives:mpl-path-vertices path1) 0))
          (n2 (array-dimension (mpl.primitives:mpl-path-vertices path2) 0)))
      (is (> n2 n1)))))

(test hatch-small-circles
  "Small circle hatch 'o' produces a path."
  (let ((path (hatch-get-path "o")))
    (is (not (null path)))))

(test hatch-large-circles
  "Large circle hatch 'O' produces a path."
  (let ((path (hatch-get-path "O")))
    (is (not (null path)))))

(test hatch-dots
  "Dot hatch '.' produces a path."
  (let ((path (hatch-get-path ".")))
    (is (not (null path)))))

(test hatch-stars
  "Star hatch '*' produces a path."
  (let ((path (hatch-get-path "*")))
    (is (not (null path)))))

(test hatch-combined-patterns
  "Combined pattern '/|' generates more vertices than either alone."
  (let ((path-slash (hatch-get-path "/"))
        (path-pipe (hatch-get-path "|"))
        (path-both (hatch-get-path "/|")))
    (is (not (null path-both)))
    (let ((n-slash (array-dimension (mpl.primitives:mpl-path-vertices path-slash) 0))
          (n-pipe (array-dimension (mpl.primitives:mpl-path-vertices path-pipe) 0))
          (n-both (array-dimension (mpl.primitives:mpl-path-vertices path-both) 0)))
      (is (>= n-both (+ n-slash n-pipe))))))

(test hatch-valid-patterns
  "*valid-hatch-patterns* contains all 10 expected characters."
  (is (= (length *valid-hatch-patterns*) 11))
  (dolist (ch '(#\/ #\\ #\| #\- #\+ #\x #\X #\o #\O #\. #\*))
    (is (member ch *valid-hatch-patterns*))))

;;; ============================================================
;;; Collection base class tests
;;; ============================================================

(test collection-creation
  "Collection can be instantiated with default values."
  (let ((c (make-instance 'collection)))
    (is (null (collection-offsets c)))
    (is (null (collection-facecolors c)))
    (is (null (collection-edgecolors c)))
    (is (equal '(1.0) (collection-linewidths c)))
    (is (equal '(:solid) (collection-linestyles c)))
    (is (equal '(t) (collection-antialiaseds c)))
    (is (= 5.0 (collection-pickradius c)))
    (is (eq :butt (collection-capstyle c)))
    (is (eq :round (collection-joinstyle c)))
    (is (= 1 (artist-zorder c)))))

(test collection-set-offsets-works
  "collection-set-offsets stores offsets and marks stale."
  (let ((c (make-instance 'collection)))
    (setf (artist-stale c) nil)
    (collection-set-offsets c '((1.0 2.0) (3.0 4.0)))
    (is (= 2 (length (collection-offsets c))))
    (is (artist-stale c))))

(test collection-set-facecolor-string
  "collection-set-facecolor wraps string into list."
  (let ((c (make-instance 'collection)))
    (collection-set-facecolor c "red")
    (is (equal '("red") (collection-facecolors c)))))

(test collection-set-facecolor-list
  "collection-set-facecolor stores list as-is."
  (let ((c (make-instance 'collection)))
    (collection-set-facecolor c '("red" "blue" "green"))
    (is (= 3 (length (collection-facecolors c))))))

(test collection-set-edgecolor-works
  "collection-set-edgecolor stores colors."
  (let ((c (make-instance 'collection)))
    (collection-set-edgecolor c "black")
    (is (equal '("black") (collection-edgecolors c)))))

(test collection-set-linewidth-number
  "collection-set-linewidth wraps number into list."
  (let ((c (make-instance 'collection)))
    (collection-set-linewidth c 2.0)
    (is (equal '(2.0) (collection-linewidths c)))))

(test collection-set-linewidth-list
  "collection-set-linewidth stores list as-is."
  (let ((c (make-instance 'collection)))
    (collection-set-linewidth c '(1.0 2.0 3.0))
    (is (= 3 (length (collection-linewidths c))))))

(test collection-set-color-sets-both
  "collection-set-color sets both face and edge colors."
  (let ((c (make-instance 'collection)))
    (collection-set-color c "blue")
    (is (equal '("blue") (collection-facecolors c)))
    (is (equal '("blue") (collection-edgecolors c)))))

(test collection-inherits-artist
  "Collection inherits artist properties."
  (let ((c (make-instance 'collection :alpha 0.5d0 :label "test"
                                       :visible nil :zorder 3)))
    (is (= 0.5d0 (artist-alpha c)))
    (is (string= "test" (artist-label c)))
    (is (not (artist-visible c)))
    (is (= 3 (artist-zorder c)))))

;;; ============================================================
;;; LineCollection tests
;;; ============================================================

(test line-collection-creation
  "LineCollection can be created with segments."
  (let ((lc (make-instance 'line-collection
                           :segments '(((0 0) (1 1)) ((2 2) (3 3))))))
    (is (= 2 (length (line-collection-segments lc))))))

(test line-collection-set-segments
  "collection-set-segments updates segments."
  (let ((lc (make-instance 'line-collection)))
    (collection-set-segments lc '(((0 0) (1 1) (2 0))))
    (is (= 1 (length (line-collection-segments lc))))
    (is (artist-stale lc))))

(test line-collection-get-paths
  "LineCollection converts segments to paths."
  (let ((lc (make-instance 'line-collection
                           :segments '(((0 0) (1 1)) ((2 2) (3 3))))))
    (let ((paths (collection-get-paths lc)))
      (is (= 2 (length paths)))
      ;; Each path should have the right number of vertices
      (is (= 2 (array-dimension (mpl.primitives:mpl-path-vertices (first paths)) 0)))
      (is (= 2 (array-dimension (mpl.primitives:mpl-path-vertices (second paths)) 0))))))

(test line-collection-draw
  "LineCollection can be drawn with mock renderer."
  (let ((lc (make-instance 'line-collection
                           :segments '(((0 0) (1 1)) ((2 2) (3 3)))
                           :edgecolors '("red" "blue")
                           :linewidths '(1.0 2.0)))
        (renderer (make-mock-renderer)))
    (draw lc renderer)
    ;; Should have 2 draw calls (one per segment)
    (is (= 2 (length (mock-renderer-calls renderer))))))

(test line-collection-convenience
  "make-line-collection creates a properly configured LineCollection."
  (let ((lc (make-line-collection
             :segments '(((0 0) (1 1)))
             :edgecolors "red"
             :linewidths 2.0
             :alpha 0.7d0)))
    (is (typep lc 'line-collection))
    (is (= 1 (length (line-collection-segments lc))))
    (is (equal '("red") (collection-edgecolors lc)))
    (is (equal '(2.0) (collection-linewidths lc)))
    (is (= 0.7d0 (artist-alpha lc)))))

(test line-collection-multipoint-segment
  "LineCollection handles segments with more than 2 points."
  (let ((lc (make-instance 'line-collection
                           :segments '(((0 0) (1 1) (2 0) (3 1))))))
    (let ((paths (collection-get-paths lc)))
      (is (= 1 (length paths)))
      (is (= 4 (array-dimension (mpl.primitives:mpl-path-vertices (first paths)) 0))))))

;;; ============================================================
;;; PathCollection tests
;;; ============================================================

(test path-collection-creation
  "PathCollection can be created with paths, offsets, and sizes."
  (let* ((marker (make-marker-path :circle))
         (pc (make-instance 'path-collection
                            :paths (list marker)
                            :offsets '((1.0 2.0) (3.0 4.0))
                            :sizes '(36.0 64.0))))
    (is (= 1 (length (path-collection-paths pc))))
    (is (= 2 (length (collection-offsets pc))))
    (is (= 2 (length (path-collection-sizes pc))))))

(test path-collection-get-paths
  "PathCollection returns stored paths."
  (let* ((marker (make-marker-path :circle))
         (pc (make-instance 'path-collection :paths (list marker))))
    (let ((paths (collection-get-paths pc)))
      (is (= 1 (length paths)))
      (is (eq marker (first paths))))))

(test path-collection-get-transforms
  "PathCollection generates scale transforms from sizes."
  (let* ((marker (make-marker-path :circle))
         (pc (make-instance 'path-collection
                            :paths (list marker)
                            :offsets '((0 0) (1 1))
                            :sizes '(100.0 25.0))))
    (let ((transforms (collection-get-transforms pc)))
      (is (= 2 (length transforms)))
      ;; Size 100 → scale 10, size 25 → scale 5
      (is (typep (first transforms) 'mpl.primitives:affine-2d)))))

(test path-collection-set-paths
  "collection-set-paths updates paths."
  (let* ((pc (make-instance 'path-collection))
         (marker (make-marker-path :square)))
    (collection-set-paths pc (list marker))
    (is (= 1 (length (path-collection-paths pc))))
    (is (artist-stale pc))))

(test path-collection-set-sizes
  "collection-set-sizes wraps number into list."
  (let ((pc (make-instance 'path-collection)))
    (collection-set-sizes pc 36.0)
    (is (equal '(36.0) (path-collection-sizes pc)))))

(test path-collection-draw
  "PathCollection can be drawn with mock renderer."
  (let* ((marker (make-marker-path :circle))
         (pc (make-instance 'path-collection
                            :paths (list marker)
                            :offsets '((0.0 0.0) (1.0 1.0) (2.0 2.0))
                            :sizes '(36.0)
                            :facecolors '("blue")
                            :edgecolors '("black")
                            :linewidths '(0.5)))
         (renderer (make-mock-renderer)))
    (draw pc renderer)
    ;; Should have 3 draw calls (one per offset)
    (is (= 3 (length (mock-renderer-calls renderer))))))

(test path-collection-convenience
  "make-path-collection creates a properly configured collection."
  (let* ((marker (make-marker-path :circle))
         (pc (make-path-collection
              :paths (list marker)
              :offsets '((0 0) (1 1))
              :sizes '(36.0)
              :facecolors "red"
              :edgecolors "black"
              :linewidths 0.5
              :alpha 0.5d0
              :zorder 3
              :label "scatter")))
    (is (typep pc 'path-collection))
    (is (= 1 (length (path-collection-paths pc))))
    (is (= 2 (length (collection-offsets pc))))
    (is (equal '("red") (collection-facecolors pc)))
    (is (equal '("black") (collection-edgecolors pc)))
    (is (equal '(0.5) (collection-linewidths pc)))
    (is (= 0.5d0 (artist-alpha pc)))
    (is (= 3 (artist-zorder pc)))
    (is (string= "scatter" (artist-label pc)))))

(test path-collection-cyclic-colors
  "PathCollection cycles colors when fewer colors than offsets."
  (let* ((marker (make-marker-path :circle))
         (pc (make-instance 'path-collection
                            :paths (list marker)
                            :offsets '((0 0) (1 1) (2 2) (3 3))
                            :facecolors '("red" "blue")
                            :edgecolors '("black")))
         (renderer (make-mock-renderer)))
    (draw pc renderer)
    ;; 4 items drawn, colors cycle: red, blue, red, blue
    (is (= 4 (length (mock-renderer-calls renderer))))))

;;; ============================================================
;;; PatchCollection tests
;;; ============================================================

(test patch-collection-creation
  "PatchCollection can be created with patches."
  (let* ((r1 (make-instance 'rectangle :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0))
         (r2 (make-instance 'rectangle :x0 2.0d0 :y0 2.0d0 :width 1.0d0 :height 1.0d0))
         (pc (make-instance 'patch-collection :patches (list r1 r2))))
    (is (= 2 (length (patch-collection-patches pc))))))

(test patch-collection-get-paths
  "PatchCollection extracts paths from patches."
  (let* ((r1 (make-instance 'rectangle :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0))
         (c1 (make-instance 'circle :center '(5.0d0 5.0d0) :radius 1.0d0))
         (pc (make-instance 'patch-collection :patches (list r1 c1))))
    (let ((paths (collection-get-paths pc)))
      (is (= 2 (length paths)))
      ;; Each path should be an mpl-path
      (is (typep (first paths) 'mpl.primitives:mpl-path))
      (is (typep (second paths) 'mpl.primitives:mpl-path)))))

(test patch-collection-set-patches
  "collection-set-patches updates patches."
  (let ((pc (make-instance 'patch-collection))
        (r1 (make-instance 'rectangle :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0)))
    (collection-set-patches pc (list r1))
    (is (= 1 (length (patch-collection-patches pc))))
    (is (artist-stale pc))))

;;; ============================================================
;;; PolyCollection tests
;;; ============================================================

(test poly-collection-creation
  "PolyCollection can be created with vertex lists."
  (let ((pc (make-instance 'poly-collection
                           :verts '(((0 0) (1 0) (0.5 1))
                                    ((2 2) (3 2) (3 3) (2 3))))))
    (is (= 2 (length (poly-collection-verts pc))))))

(test poly-collection-get-paths
  "PolyCollection converts vertex lists to closed paths."
  (let ((pc (make-instance 'poly-collection
                           :verts '(((0 0) (1 0) (0.5 1))))))
    (let ((paths (collection-get-paths pc)))
      (is (= 1 (length paths)))
      (let* ((path (first paths))
             (verts (mpl.primitives:mpl-path-vertices path))
             (codes (mpl.primitives:mpl-path-codes path)))
        ;; 3 vertices + 1 closepoly = 4
        (is (= 4 (array-dimension verts 0)))
        ;; First code is MOVETO, last is CLOSEPOLY
        (is (= mpl.primitives:+moveto+ (aref codes 0)))
        (is (= mpl.primitives:+closepoly+ (aref codes 3)))))))

(test poly-collection-set-verts
  "collection-set-verts updates vertex data."
  (let ((pc (make-instance 'poly-collection)))
    (collection-set-verts pc '(((0 0) (1 0) (1 1) (0 1))))
    (is (= 1 (length (poly-collection-verts pc))))
    (is (artist-stale pc))))

(test poly-collection-draw
  "PolyCollection can be drawn with mock renderer."
  (let ((pc (make-instance 'poly-collection
                           :verts '(((0 0) (1 0) (0.5 1))
                                    ((2 0) (3 0) (2.5 1)))
                           :facecolors '("red" "blue")
                           :edgecolors '("black")))
        (renderer (make-mock-renderer)))
    (draw pc renderer)
    ;; 2 polygons drawn
    (is (= 2 (length (mock-renderer-calls renderer))))))

;;; ============================================================
;;; QuadMesh tests
;;; ============================================================

(test quad-mesh-creation
  "QuadMesh can be created with mesh dimensions and coordinates."
  (let* ((coords (make-array '(3 3 2) :element-type 'double-float :initial-element 0.0d0))
         (qm (make-instance 'quad-mesh
                            :mesh-width 2
                            :mesh-height 2
                            :coordinates coords)))
    (is (= 2 (quad-mesh-width qm)))
    (is (= 2 (quad-mesh-height qm)))
    (is (not (null (quad-mesh-coordinates qm))))))

(test quad-mesh-get-paths
  "QuadMesh generates quadrilateral paths from coordinates."
  ;; Create a 2x2 mesh (3x3 corners)
  (let* ((coords (make-array '(3 3 2) :element-type 'double-float :initial-element 0.0d0))
         (qm (make-instance 'quad-mesh :mesh-width 2 :mesh-height 2
                                        :coordinates coords)))
    ;; Set corner coordinates for a regular grid
    (dotimes (i 3)
      (dotimes (j 3)
        (setf (aref coords i j 0) (float j 1.0d0)
              (aref coords i j 1) (float i 1.0d0))))
    (let ((paths (collection-get-paths qm)))
      ;; 2x2 mesh = 4 quads
      (is (= 4 (length paths)))
      ;; Each path should have 5 vertices (4 corners + close)
      (is (= 5 (array-dimension (mpl.primitives:mpl-path-vertices (first paths)) 0))))))

(test quad-mesh-draw
  "QuadMesh can be drawn with mock renderer."
  (let* ((coords (make-array '(3 3 2) :element-type 'double-float :initial-element 0.0d0))
         (qm (make-instance 'quad-mesh :mesh-width 2 :mesh-height 2
                                        :coordinates coords
                                        :facecolors '("red" "blue" "green" "yellow")))
         (renderer (make-mock-renderer)))
    (dotimes (i 3)
      (dotimes (j 3)
        (setf (aref coords i j 0) (float j 1.0d0)
              (aref coords i j 1) (float i 1.0d0))))
    (draw qm renderer)
    ;; 4 quads drawn
    (is (= 4 (length (mock-renderer-calls renderer))))))

(test quad-mesh-single-cell
  "QuadMesh with 1x1 mesh has one quad."
  (let* ((coords (make-array '(2 2 2) :element-type 'double-float :initial-element 0.0d0))
         (qm (make-instance 'quad-mesh :mesh-width 1 :mesh-height 1
                                        :coordinates coords)))
    (setf (aref coords 0 0 0) 0.0d0 (aref coords 0 0 1) 0.0d0
          (aref coords 0 1 0) 1.0d0 (aref coords 0 1 1) 0.0d0
          (aref coords 1 0 0) 0.0d0 (aref coords 1 0 1) 1.0d0
          (aref coords 1 1 0) 1.0d0 (aref coords 1 1 1) 1.0d0)
    (let ((paths (collection-get-paths qm)))
      (is (= 1 (length paths))))))

;;; ============================================================
;;; Collection draw protocol tests
;;; ============================================================

(test collection-invisible-no-draw
  "Invisible collection does not draw."
  (let ((c (make-instance 'line-collection
                          :segments '(((0 0) (1 1)))
                          :visible nil))
        (renderer (make-mock-renderer)))
    (draw c renderer)
    (is (= 0 (length (mock-renderer-calls renderer))))))

(test collection-stale-cleared-after-draw
  "Drawing clears the stale flag."
  (let ((lc (make-instance 'line-collection
                           :segments '(((0 0) (1 1)))
                           :edgecolors '("black")))
        (renderer (make-mock-renderer)))
    (is (artist-stale lc))
    (draw lc renderer)
    (is (not (artist-stale lc)))))

(test collection-empty-no-draw
  "Collection with no items doesn't draw."
  (let ((lc (make-instance 'line-collection :segments nil))
        (renderer (make-mock-renderer)))
    (draw lc renderer)
    (is (= 0 (length (mock-renderer-calls renderer))))))

;;; ============================================================
;;; Integration with marker paths
;;; ============================================================

(test path-collection-with-different-markers
  "PathCollection works with different marker shapes."
  (let* ((circle-path (make-marker-path :circle))
         (square-path (make-marker-path :square))
         (pc (make-instance 'path-collection
                            :paths (list circle-path square-path)
                            :offsets '((0 0) (1 1) (2 2) (3 3))
                            :facecolors '("red")
                            :edgecolors '("black")))
         (renderer (make-mock-renderer)))
    (draw pc renderer)
    ;; 4 items drawn, cycling through 2 paths
    (is (= 4 (length (mock-renderer-calls renderer))))))

(test path-collection-single-offset
  "PathCollection with single offset draws one item."
  (let* ((marker (make-marker-path :circle))
         (pc (make-instance 'path-collection
                            :paths (list marker)
                            :offsets '((5.0 5.0))
                            :facecolors '("green")
                            :sizes '(100.0)))
         (renderer (make-mock-renderer)))
    (draw pc renderer)
    (is (= 1 (length (mock-renderer-calls renderer))))))

;;; ============================================================
;;; Collection with transforms
;;; ============================================================

(test collection-with-transform
  "Collection respects artist transform for offsets."
  (let* ((marker (make-marker-path :circle))
         (pc (make-instance 'path-collection
                            :paths (list marker)
                            :offsets '((1.0 1.0))
                            :facecolors '("blue")
                            :trans-offset (mpl.primitives:make-affine-2d
                                          :scale '(10.0d0 10.0d0))))
         (renderer (make-mock-renderer)))
    (draw pc renderer)
    ;; Drawn once
    (is (= 1 (length (mock-renderer-calls renderer))))))

;;; ============================================================
;;; Run all tests
;;; ============================================================

(defun run-collection-tests ()
  "Run all collection tests and report results."
  (let ((results (run 'collection-suite)))
    (explain! results)
    (unless (results-status results)
      (error "Collection tests FAILED"))
    results))
