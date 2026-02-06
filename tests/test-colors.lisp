;;;; test-colors.lisp — Tests for color system
;;;; Ported from matplotlib's test_colors.py
;;;; Uses FiveAM test framework.

(in-package #:cl-matplotlib.primitives.tests)

(def-suite color-tests
  :description "Color system tests ported from matplotlib's test_colors.py")

(in-suite color-tests)

;;; ============================================================
;;; Helper utilities
;;; ============================================================

(defun color-approx= (a b &optional (tol 1d-2))
  "Check if two doubles are approximately equal (color precision)."
  (<= (abs (- a b)) tol))

(defun rgba-approx= (v1 v2 &optional (tol 1d-2))
  "Check if two RGBA vectors are approximately equal."
  (and (= (length v1) 4)
       (= (length v2) 4)
       (color-approx= (aref v1 0) (aref v2 0) tol)
       (color-approx= (aref v1 1) (aref v2 1) tol)
       (color-approx= (aref v1 2) (aref v2 2) tol)
       (color-approx= (aref v1 3) (aref v2 3) tol)))

;;; ============================================================
;;; Color conversion tests (to-hex, to-rgb)
;;; ============================================================

(test to-hex-basic
  "Test to-hex conversion."
  (is (string= "#ff0000" (to-hex #(1.0 0.0 0.0 1.0))))
  (is (string= "#00ff00" (to-hex #(0.0 1.0 0.0 1.0))))
  (is (string= "#0000ff" (to-hex #(0.0 0.0 1.0 1.0))))
  (is (string= "#ffffff" (to-hex #(1.0 1.0 1.0 1.0))))
  (is (string= "#000000" (to-hex #(0.0 0.0 0.0 1.0)))))

(test to-hex-keep-alpha
  "Test to-hex with alpha channel."
  (is (string= "#ff000080" (to-hex #(1.0 0.0 0.0 0.5) :keep-alpha t)))
  (is (string= "#ff0000ff" (to-hex #(1.0 0.0 0.0 1.0) :keep-alpha t))))

(test to-hex-from-name
  "Test to-hex from named colors."
  (is (string= "#ff0000" (to-hex "red")))
  (is (string= "#0000ff" (to-hex "blue"))))

(test to-rgb-basic
  "Test to-rgb conversion."
  (let ((rgb (to-rgb "red")))
    (is (= 3 (length rgb)))
    (is (color-approx= 1.0 (aref rgb 0)))
    (is (color-approx= 0.0 (aref rgb 1)))
    (is (color-approx= 0.0 (aref rgb 2)))))

(test to-rgb-from-hex
  "Test to-rgb from hex."
  (let ((rgb (to-rgb "#FF8000")))
    (is (color-approx= 1.0 (aref rgb 0)))
    (is (color-approx= 0.5 (aref rgb 1) 0.01))
    (is (color-approx= 0.0 (aref rgb 2)))))

;;; ============================================================
;;; Colormap creation tests
;;; ============================================================

(test colormap-registry-populated
  "Test that colormaps are registered."
  (is (> (hash-table-count *colormaps*) 20))
  (is (not (null (get-colormap :viridis))))
  (is (not (null (get-colormap :plasma))))
  (is (not (null (get-colormap :inferno))))
  (is (not (null (get-colormap :magma))))
  (is (not (null (get-colormap :cividis))))
  (is (not (null (get-colormap :hot))))
  (is (not (null (get-colormap :cool))))
  (is (not (null (get-colormap :jet))))
  (is (not (null (get-colormap :gray))))
  (is (not (null (get-colormap :binary))))
  (is (not (null (get-colormap :coolwarm))))
  (is (not (null (get-colormap :spring))))
  (is (not (null (get-colormap :summer))))
  (is (not (null (get-colormap :autumn))))
  (is (not (null (get-colormap :winter)))))

(test colormap-registry-sequential
  "Test sequential colormaps are registered."
  (is (not (null (get-colormap "Blues"))))
  (is (not (null (get-colormap "Greens"))))
  (is (not (null (get-colormap "Greys"))))
  (is (not (null (get-colormap "Reds")))))

(test colormap-registry-diverging
  "Test diverging colormaps are registered."
  (is (not (null (get-colormap "RdBu"))))
  (is (not (null (get-colormap "RdYlGn"))))
  (is (not (null (get-colormap "Spectral"))))
  (is (not (null (get-colormap :coolwarm)))))

(test list-colormaps-works
  "Test list-colormaps returns sorted list."
  (let ((names (list-colormaps)))
    (is (listp names))
    (is (> (length names) 20))
    ;; Check sorted
    (is (every (lambda (a b) (string<= a b))
               names (cdr names)))))

(test colormap-grey-alias
  "Test grey/gray alias."
  (is (eq (get-colormap :gray) (get-colormap :grey))))

;;; ============================================================
;;; Colormap call tests
;;; ============================================================

(test colormap-call-endpoints
  "Test colormap maps 0 and 1 correctly."
  (let ((cmap (get-colormap :gray)))
    ;; Gray at 0 should be black
    (let ((c0 (colormap-call cmap 0.0)))
      (is (= 4 (length c0)))
      (is (color-approx= 0.0 (aref c0 0) 0.05))
      (is (color-approx= 0.0 (aref c0 1) 0.05))
      (is (color-approx= 0.0 (aref c0 2) 0.05)))
    ;; Gray at 1 should be white
    (let ((c1 (colormap-call cmap 1.0)))
      (is (color-approx= 1.0 (aref c1 0) 0.05))
      (is (color-approx= 1.0 (aref c1 1) 0.05))
      (is (color-approx= 1.0 (aref c1 2) 0.05)))))

(test colormap-call-midpoint
  "Test colormap at midpoint."
  (let ((cmap (get-colormap :gray)))
    ;; Gray at 0.5 should be ~0.5
    (let ((c (colormap-call cmap 0.5)))
      (is (color-approx= 0.5 (aref c 0) 0.05))
      (is (color-approx= 0.5 (aref c 1) 0.05))
      (is (color-approx= 0.5 (aref c 2) 0.05)))))

(test colormap-call-alpha
  "Test colormap call with alpha override."
  (let* ((cmap (get-colormap :gray))
         (c (colormap-call cmap 0.5 :alpha 0.5)))
    (is (color-approx= 0.5 (aref c 3) 0.01))))

(test colormap-call-out-of-range
  "Test colormap handles out-of-range values."
  (let ((cmap (get-colormap :gray)))
    ;; Under range
    (let ((c (colormap-call cmap -0.1)))
      (is (= 4 (length c))))
    ;; Over range
    (let ((c (colormap-call cmap 1.5)))
      (is (= 4 (length c))))))

(test colormap-viridis-endpoints
  "Test viridis colormap endpoints."
  (let ((cmap (get-colormap :viridis)))
    ;; viridis at 0 should be dark purple
    (let ((c0 (colormap-call cmap 0.0)))
      (is (< (aref c0 0) 0.4))   ; low red
      (is (< (aref c0 1) 0.1))   ; low green
      (is (> (aref c0 2) 0.2)))  ; some blue
    ;; viridis at 1 should be bright yellow
    (let ((c1 (colormap-call cmap 1.0)))
      (is (> (aref c1 0) 0.8))   ; high red
      (is (> (aref c1 1) 0.8))   ; high green
      (is (< (aref c1 2) 0.5))))) ; low blue

(test colormap-hot-progression
  "Test hot colormap goes black → red → yellow → white."
  (let ((cmap (get-colormap :hot)))
    ;; At 0: near black
    (let ((c (colormap-call cmap 0.0)))
      (is (< (aref c 0) 0.15))
      (is (< (aref c 1) 0.05))
      (is (< (aref c 2) 0.05)))
    ;; At 1: white
    (let ((c (colormap-call cmap 1.0)))
      (is (> (aref c 0) 0.95))
      (is (> (aref c 1) 0.95))
      (is (> (aref c 2) 0.95)))))

(test colormap-binary-inverted
  "Test binary colormap goes white → black."
  (let ((cmap (get-colormap :binary)))
    ;; At 0: white
    (let ((c (colormap-call cmap 0.0)))
      (is (> (aref c 0) 0.95))
      (is (> (aref c 1) 0.95))
      (is (> (aref c 2) 0.95)))
    ;; At 1: black
    (let ((c (colormap-call cmap 1.0)))
      (is (< (aref c 0) 0.05))
      (is (< (aref c 1) 0.05))
      (is (< (aref c 2) 0.05)))))

(test colormap-jet-rainbow
  "Test jet colormap has rainbow progression."
  (let ((cmap (get-colormap :jet)))
    ;; At 0: blue
    (let ((c (colormap-call cmap 0.0)))
      (is (< (aref c 0) 0.1))
      (is (< (aref c 1) 0.1))
      (is (> (aref c 2) 0.3)))
    ;; At 1: red
    (let ((c (colormap-call cmap 1.0)))
      (is (> (aref c 0) 0.3))
      (is (< (aref c 1) 0.1))
      (is (< (aref c 2) 0.1)))))

(test colormap-coolwarm-diverging
  "Test coolwarm is blue at 0, red at 1, white-ish at 0.5."
  (let ((cmap (get-colormap :coolwarm)))
    ;; At 0: cool (blue-ish)
    (let ((c (colormap-call cmap 0.0)))
      (is (< (aref c 0) 0.4))
      (is (> (aref c 2) 0.6)))
    ;; At 0.5: near white/gray
    (let ((c (colormap-call cmap 0.5)))
      (is (> (aref c 0) 0.8))
      (is (> (aref c 1) 0.8))
      (is (> (aref c 2) 0.8)))
    ;; At 1: warm (red-ish)
    (let ((c (colormap-call cmap 1.0)))
      (is (> (aref c 0) 0.6))
      (is (< (aref c 2) 0.3)))))

;;; ============================================================
;;; LinearSegmentedColormap tests
;;; ============================================================

(test linear-segmented-colormap-creation
  "Test creating a LinearSegmentedColormap."
  (let ((cmap (make-linear-segmented-colormap
               "test-lsc"
               (list :red   '((0.0 0.0 0.0) (1.0 1.0 1.0))
                     :green '((0.0 0.0 0.0) (1.0 1.0 1.0))
                     :blue  '((0.0 0.0 0.0) (1.0 1.0 1.0))))))
    (is (string= "test-lsc" (colormap-name cmap)))
    (is (= 256 (colormap-n cmap)))
    ;; Should behave like gray
    (let ((c (colormap-call cmap 0.5)))
      (is (color-approx= 0.5 (aref c 0) 0.05)))))

(test linear-segmented-from-list
  "Test creating colormap from list of colors."
  (let ((cmap (linear-segmented-colormap-from-list
               "test-from-list"
               '("red" "green" "blue"))))
    (is (string= "test-from-list" (colormap-name cmap)))
    ;; At 0: red
    (let ((c (colormap-call cmap 0.0)))
      (is (> (aref c 0) 0.9))
      (is (< (aref c 1) 0.1)))
    ;; At 1: blue
    (let ((c (colormap-call cmap 1.0)))
      (is (< (aref c 0) 0.1))
      (is (> (aref c 2) 0.9)))))

;;; ============================================================
;;; ListedColormap tests
;;; ============================================================

(test listed-colormap-creation
  "Test creating a ListedColormap."
  (let ((cmap (make-listed-colormap
               (list #(1.0 0.0 0.0 1.0)
                     #(0.0 1.0 0.0 1.0)
                     #(0.0 0.0 1.0 1.0))
               :name "test-listed")))
    (is (string= "test-listed" (colormap-name cmap)))
    (is (= 3 (colormap-n cmap)))
    ;; At 0: red
    (let ((c (colormap-call cmap 0.0)))
      (is (color-approx= 1.0 (aref c 0)))
      (is (color-approx= 0.0 (aref c 1))))
    ;; At 1: blue
    (let ((c (colormap-call cmap 1.0)))
      (is (color-approx= 0.0 (aref c 0)))
      (is (color-approx= 1.0 (aref c 2))))))

;;; ============================================================
;;; Normalize tests
;;; ============================================================

(test normalize-basic
  "Test basic linear normalization."
  (let ((norm (make-normalize :vmin 0.0 :vmax 10.0)))
    (is (color-approx= 0.0 (normalize-call norm 0.0)))
    (is (color-approx= 0.5 (normalize-call norm 5.0)))
    (is (color-approx= 1.0 (normalize-call norm 10.0)))))

(test normalize-out-of-range
  "Test normalization with out-of-range values."
  (let ((norm (make-normalize :vmin 0.0 :vmax 10.0)))
    ;; Without clip: values outside [0,1]
    (is (< (normalize-call norm -5.0) 0.0))
    (is (> (normalize-call norm 15.0) 1.0))))

(test normalize-clip
  "Test normalization with clipping."
  (let ((norm (make-normalize :vmin 0.0 :vmax 10.0 :clip t)))
    (is (color-approx= 0.0 (normalize-call norm -5.0)))
    (is (color-approx= 1.0 (normalize-call norm 15.0)))
    (is (color-approx= 0.5 (normalize-call norm 5.0)))))

(test normalize-equal-vmin-vmax
  "Test normalization when vmin == vmax."
  (let ((norm (make-normalize :vmin 5.0 :vmax 5.0)))
    (is (= 0.0d0 (normalize-call norm 5.0)))))

(test normalize-inverse
  "Test inverse normalization."
  (let ((norm (make-normalize :vmin 0.0 :vmax 10.0)))
    (is (color-approx= 0.0 (normalize-inverse norm 0.0)))
    (is (color-approx= 5.0 (normalize-inverse norm 0.5)))
    (is (color-approx= 10.0 (normalize-inverse norm 1.0)))))

;;; ============================================================
;;; NoNorm tests
;;; ============================================================

(test no-norm-passthrough
  "Test NoNorm passes values through."
  (let ((norm (make-no-norm)))
    (is (= 0.5 (normalize-call norm 0.5)))
    (is (= 42 (normalize-call norm 42)))
    (is (= 0.5 (normalize-inverse norm 0.5)))))

;;; ============================================================
;;; LogNorm tests
;;; ============================================================

(test log-norm-basic
  "Test logarithmic normalization."
  (let ((norm (make-log-norm :vmin 1.0 :vmax 100.0)))
    (is (color-approx= 0.0 (normalize-call norm 1.0)))
    (is (color-approx= 0.5 (normalize-call norm 10.0)))
    (is (color-approx= 1.0 (normalize-call norm 100.0)))))

(test log-norm-inverse
  "Test LogNorm inverse."
  (let ((norm (make-log-norm :vmin 1.0 :vmax 100.0)))
    (is (color-approx= 1.0 (normalize-inverse norm 0.0)))
    (is (color-approx= 10.0 (normalize-inverse norm 0.5)))
    (is (color-approx= 100.0 (normalize-inverse norm 1.0)))))

;;; ============================================================
;;; PowerNorm tests
;;; ============================================================

(test power-norm-basic
  "Test power-law normalization."
  (let ((norm (make-power-norm 2.0 :vmin 0.0 :vmax 10.0)))
    (is (color-approx= 0.0 (normalize-call norm 0.0)))
    ;; (5/10)^2 = 0.25
    (is (color-approx= 0.25 (normalize-call norm 5.0)))
    (is (color-approx= 1.0 (normalize-call norm 10.0)))))

(test power-norm-gamma-half
  "Test power norm with gamma=0.5 (square root)."
  (let ((norm (make-power-norm 0.5 :vmin 0.0 :vmax 1.0)))
    ;; (0.25)^0.5 = 0.5
    (is (color-approx= 0.5 (normalize-call norm 0.25)))))

(test power-norm-inverse
  "Test PowerNorm inverse."
  (let ((norm (make-power-norm 2.0 :vmin 0.0 :vmax 10.0)))
    (is (color-approx= 0.0 (normalize-inverse norm 0.0)))
    ;; inverse of 0.25 with gamma=2: sqrt(0.25) * 10 = 5
    (is (color-approx= 5.0 (normalize-inverse norm 0.25)))))

;;; ============================================================
;;; TwoSlopeNorm tests
;;; ============================================================

(test two-slope-norm-basic
  "Test TwoSlopeNorm with center."
  (let ((norm (make-two-slope-norm 0.0 :vmin -4000.0 :vmax 10000.0)))
    (is (color-approx= 0.0 (normalize-call norm -4000.0)))
    (is (color-approx= 0.5 (normalize-call norm 0.0)))
    (is (color-approx= 1.0 (normalize-call norm 10000.0)))))

(test two-slope-norm-asymmetric
  "Test TwoSlopeNorm with asymmetric range."
  (let ((norm (make-two-slope-norm 0.0 :vmin -4000.0 :vmax 10000.0)))
    ;; -2000 is halfway between -4000 and 0 → 0.25
    (is (color-approx= 0.25 (normalize-call norm -2000.0)))
    ;; 5000 is halfway between 0 and 10000 → 0.75
    (is (color-approx= 0.75 (normalize-call norm 5000.0)))))

(test two-slope-norm-inverse
  "Test TwoSlopeNorm inverse."
  (let ((norm (make-two-slope-norm 0.0 :vmin -4000.0 :vmax 10000.0)))
    (is (color-approx= -4000.0 (normalize-inverse norm 0.0) 1.0))
    (is (color-approx= 0.0 (normalize-inverse norm 0.5) 1.0))
    (is (color-approx= 10000.0 (normalize-inverse norm 1.0) 1.0))))

(test two-slope-norm-invalid-order
  "Test TwoSlopeNorm rejects invalid ordering."
  (signals error (make-two-slope-norm 0.0 :vmin 1.0 :vmax 10.0))  ; vcenter <= vmin
  (signals error (make-two-slope-norm 20.0 :vmin 0.0 :vmax 10.0))) ; vcenter >= vmax

;;; ============================================================
;;; BoundaryNorm tests
;;; ============================================================

(test boundary-norm-basic
  "Test BoundaryNorm with simple boundaries."
  (let ((norm (make-boundary-norm '(0.0 1.0 2.0 3.0) 3)))
    ;; Value in first bin [0,1) → 0
    (is (= 0 (normalize-call norm 0.5)))
    ;; Value in second bin [1,2) → 1
    (is (= 1 (normalize-call norm 1.5)))
    ;; Value in third bin [2,3) → 2
    (is (= 2 (normalize-call norm 2.5)))))

(test boundary-norm-not-invertible
  "Test BoundaryNorm is not invertible."
  (let ((norm (make-boundary-norm '(0.0 1.0 2.0) 2)))
    (signals error (normalize-inverse norm 0.5))))

(test boundary-norm-minimum-boundaries
  "Test BoundaryNorm requires at least 2 boundaries."
  (signals error (make-boundary-norm '(1.0) 1)))

;;; ============================================================
;;; SymLogNorm tests
;;; ============================================================

(test sym-log-norm-basic
  "Test symmetric log normalization."
  (let ((norm (make-sym-log-norm 1.0 :vmin -10.0 :vmax 10.0)))
    ;; At 0: should be 0.5 (center)
    (is (color-approx= 0.5 (normalize-call norm 0.0)))
    ;; Symmetric: norm(-x) + norm(x) ≈ 1
    (let ((pos (normalize-call norm 5.0))
          (neg (normalize-call norm -5.0)))
      (is (color-approx= 1.0 (+ pos neg) 0.05)))))

;;; ============================================================
;;; ScalarMappable tests
;;; ============================================================

(test scalar-mappable-basic
  "Test ScalarMappable combines norm and colormap."
  (let ((sm (make-scalar-mappable
             :norm (make-normalize :vmin 0.0 :vmax 100.0)
             :cmap (get-colormap :gray))))
    ;; 50 → normalized 0.5 → gray 0.5
    (let ((c (scalar-mappable-to-rgba sm 50.0)))
      (is (= 4 (length c)))
      (is (color-approx= 0.5 (aref c 0) 0.05))
      (is (color-approx= 0.5 (aref c 1) 0.05))
      (is (color-approx= 0.5 (aref c 2) 0.05)))))

(test scalar-mappable-with-viridis
  "Test ScalarMappable with viridis colormap."
  (let ((sm (make-scalar-mappable
             :norm (make-normalize :vmin 0.0 :vmax 1.0)
             :cmap (get-colormap :viridis))))
    ;; At 0: dark purple
    (let ((c (scalar-mappable-to-rgba sm 0.0)))
      (is (< (aref c 0) 0.4))
      (is (> (aref c 2) 0.2)))
    ;; At 1: bright yellow
    (let ((c (scalar-mappable-to-rgba sm 1.0)))
      (is (> (aref c 0) 0.8))
      (is (> (aref c 1) 0.8)))))

(test scalar-mappable-autoscale
  "Test ScalarMappable autoscale."
  (let ((sm (make-scalar-mappable
             :norm (make-normalize)
             :cmap (get-colormap :gray))))
    (scalar-mappable-autoscale sm '(10.0 20.0 30.0 40.0 50.0))
    (is (color-approx= 10.0 (norm-vmin (sm-norm sm))))
    (is (color-approx= 50.0 (norm-vmax (sm-norm sm))))
    ;; 30 is midpoint → 0.5 → gray 0.5
    (let ((c (scalar-mappable-to-rgba sm 30.0)))
      (is (color-approx= 0.5 (aref c 0) 0.05)))))

;;; ============================================================
;;; Colormap registration tests
;;; ============================================================

(test register-custom-colormap
  "Test registering a custom colormap."
  (let ((cmap (make-linear-segmented-colormap
               "test-custom"
               (list :red   '((0.0 1.0 1.0) (1.0 0.0 0.0))
                     :green '((0.0 0.0 0.0) (1.0 0.0 0.0))
                     :blue  '((0.0 0.0 0.0) (1.0 1.0 1.0))))))
    (register-colormap cmap :name "test-custom" :force t)
    (is (eq cmap (get-colormap "test-custom")))))

(test get-colormap-error-on-unknown
  "Test get-colormap signals error for unknown name."
  (signals error (get-colormap "nonexistent-colormap-xyz")))

;;; ============================================================
;;; Seasonal colormap tests
;;; ============================================================

(test spring-colormap
  "Test spring colormap: magenta → yellow."
  (let ((cmap (get-colormap :spring)))
    ;; At 0: magenta (1, 0, 1)
    (let ((c (colormap-call cmap 0.0)))
      (is (> (aref c 0) 0.9))
      (is (< (aref c 1) 0.1))
      (is (> (aref c 2) 0.9)))
    ;; At 1: yellow (1, 1, 0)
    (let ((c (colormap-call cmap 1.0)))
      (is (> (aref c 0) 0.9))
      (is (> (aref c 1) 0.9))
      (is (< (aref c 2) 0.1)))))

(test autumn-colormap
  "Test autumn colormap: red → yellow."
  (let ((cmap (get-colormap :autumn)))
    ;; At 0: red (1, 0, 0)
    (let ((c (colormap-call cmap 0.0)))
      (is (> (aref c 0) 0.9))
      (is (< (aref c 1) 0.1))
      (is (< (aref c 2) 0.1)))
    ;; At 1: yellow (1, 1, 0)
    (let ((c (colormap-call cmap 1.0)))
      (is (> (aref c 0) 0.9))
      (is (> (aref c 1) 0.9))
      (is (< (aref c 2) 0.1)))))

(test summer-colormap
  "Test summer colormap."
  (let ((cmap (get-colormap :summer)))
    ;; At 0: (0, 0.5, 0.4)
    (let ((c (colormap-call cmap 0.0)))
      (is (< (aref c 0) 0.1))
      (is (color-approx= 0.5 (aref c 1) 0.05))
      (is (color-approx= 0.4 (aref c 2) 0.05)))
    ;; At 1: (1, 1, 0.4)
    (let ((c (colormap-call cmap 1.0)))
      (is (> (aref c 0) 0.9))
      (is (> (aref c 1) 0.9))
      (is (color-approx= 0.4 (aref c 2) 0.05)))))

(test winter-colormap
  "Test winter colormap."
  (let ((cmap (get-colormap :winter)))
    ;; At 0: (0, 0, 1)
    (let ((c (colormap-call cmap 0.0)))
      (is (< (aref c 0) 0.1))
      (is (< (aref c 1) 0.1))
      (is (> (aref c 2) 0.9)))
    ;; At 1: (0, 1, 0.5)
    (let ((c (colormap-call cmap 1.0)))
      (is (< (aref c 0) 0.1))
      (is (> (aref c 1) 0.9))
      (is (color-approx= 0.5 (aref c 2) 0.05)))))

;;; ============================================================
;;; Colormap monotonicity tests
;;; ============================================================

(test gray-colormap-monotonic
  "Test gray colormap is monotonically increasing."
  (let ((cmap (get-colormap :gray)))
    (let ((prev-r 0.0))
      (loop for i from 0 to 10
            for val = (/ (float i) 10.0)
            for c = (colormap-call cmap val)
            do (is (>= (aref c 0) (- prev-r 0.001)))
               (setf prev-r (aref c 0))))))

;;; ============================================================
;;; Edge case tests
;;; ============================================================

(test colormap-nan-handling
  "Test colormap handles NaN as bad color."
  (let* ((cmap (get-colormap :viridis))
         (nan float-features:double-float-nan)
         (c (colormap-call cmap nan)))
    ;; Bad color is transparent black by default
    (is (= 4 (length c)))
    (is (color-approx= 0.0 (aref c 0)))
    (is (color-approx= 0.0 (aref c 3)))))

(test normalize-roundtrip
  "Test normalize → inverse roundtrip."
  (let ((norm (make-normalize :vmin -10.0 :vmax 10.0)))
    (dolist (val '(-10.0 -5.0 0.0 5.0 10.0))
      (let* ((normalized (normalize-call norm val))
             (recovered (normalize-inverse norm normalized)))
        (is (color-approx= val recovered 0.001))))))

(test log-norm-roundtrip
  "Test LogNorm normalize → inverse roundtrip."
  (let ((norm (make-log-norm :vmin 1.0 :vmax 1000.0)))
    (dolist (val '(1.0 10.0 100.0 1000.0))
      (let* ((normalized (normalize-call norm val))
             (recovered (normalize-inverse norm normalized)))
        (is (color-approx= val recovered 0.01))))))

(test power-norm-roundtrip
  "Test PowerNorm normalize → inverse roundtrip."
  (let ((norm (make-power-norm 2.0 :vmin 0.0 :vmax 10.0)))
    (dolist (val '(0.0 2.5 5.0 7.5 10.0))
      (let* ((normalized (normalize-call norm val))
             (recovered (normalize-inverse norm normalized)))
        (is (color-approx= val recovered 0.01))))))
