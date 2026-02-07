;;;; test-colorbar.lisp — Tests for Colorbar
;;;; Phase 4d — FiveAM test suite

(defpackage #:cl-matplotlib.tests.colorbar
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; Colorbar
                #:mpl-colorbar #:colorbar-mappable #:colorbar-cax #:colorbar-ax
                #:colorbar-orientation #:colorbar-label #:colorbar-ticks
                #:colorbar-format #:colorbar-n-levels #:colorbar-extend
                #:make-colorbar
                ;; Axes
                #:axes-base #:axes-base-figure #:axes-base-position
                #:mpl-axes
                ;; Plotting
                #:add-subplot #:plot #:scatter
                ;; Figure
                #:mpl-figure #:make-figure #:figure-axes #:figure-artists #:savefig)
  (:export #:run-colorbar-tests))

(in-package #:cl-matplotlib.tests.colorbar)

(def-suite colorbar-suite :description "Colorbar test suite")
(in-suite colorbar-suite)

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
      (and (= (read-byte s) 137)
           (= (read-byte s) 80)
           (= (read-byte s) 78)
           (= (read-byte s) 71)))))

(defun approx= (a b &optional (epsilon 0.01d0))
  "Return T if A and B are approximately equal."
  (< (abs (- a b)) epsilon))

;;; ============================================================
;;; Colorbar Creation Tests
;;; ============================================================

(test colorbar-creation-basic
  "mpl-colorbar can be created."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 10))))
    (let ((cb (make-colorbar ax sm)))
      (is (typep cb 'mpl-colorbar))
      (is (typep cb 'mpl.rendering:artist))
      (is (eq ax (colorbar-ax cb)))
      (is (eq sm (colorbar-mappable cb))))))

(test colorbar-default-orientation
  "Colorbar defaults to vertical orientation."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable)))
    (let ((cb (make-colorbar ax sm)))
      (is (eq :vertical (colorbar-orientation cb))))))

(test colorbar-horizontal-orientation
  "Colorbar can be horizontal."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable)))
    (let ((cb (make-colorbar ax sm :orientation :horizontal)))
      (is (eq :horizontal (colorbar-orientation cb))))))

(test colorbar-creates-cax
  "Colorbar creates its own axes."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable)))
    (let ((cb (make-colorbar ax sm)))
      (is (not (null (colorbar-cax cb))))
      (is (typep (colorbar-cax cb) 'axes-base)))))

(test colorbar-shrinks-parent-axes
  "Creating a vertical colorbar shrinks the parent axes width."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (original-width (third (axes-base-position ax)))
         (sm (mpl.primitives:make-scalar-mappable)))
    (make-colorbar ax sm)
    ;; Parent should be narrower now
    (is (< (third (axes-base-position ax)) original-width))))

(test colorbar-auto-ticks-with-norm
  "Colorbar generates auto ticks from norm vmin/vmax."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 100))))
    (let ((cb (make-colorbar ax sm)))
      (is (not (null (colorbar-ticks cb))))
      ;; Should have 5 ticks by default
      (is (= 5 (length (colorbar-ticks cb))))
      ;; First tick should be at vmin
      (is (approx= 0.0d0 (first (colorbar-ticks cb))))
      ;; Last tick should be at vmax
      (is (approx= 100.0d0 (car (last (colorbar-ticks cb))))))))

(test colorbar-custom-ticks
  "Colorbar accepts custom tick locations."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 10))))
    (let ((cb (make-colorbar ax sm :ticks '(0.0d0 2.5d0 5.0d0 7.5d0 10.0d0))))
      (is (= 5 (length (colorbar-ticks cb))))
      (is (approx= 2.5d0 (second (colorbar-ticks cb)))))))

(test colorbar-label
  "Colorbar accepts a label."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable)))
    (let ((cb (make-colorbar ax sm :label "Temperature (K)")))
      (is (string= "Temperature (K)" (colorbar-label cb))))))

(test colorbar-added-to-figure
  "Colorbar is added to figure artists."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable)))
    (let ((cb (make-colorbar ax sm)))
      (is (member cb (figure-artists fig))))))

(test colorbar-n-levels
  "Colorbar respects n-levels parameter."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable)))
    (let ((cb (make-colorbar ax sm :n-levels 64)))
      (is (= 64 (colorbar-n-levels cb))))))

;;; ============================================================
;;; Colorbar Draw Tests
;;; ============================================================

(test colorbar-draw-with-mock-renderer
  "Colorbar can be drawn with mock renderer without error."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 10)))
         (cb (make-colorbar ax sm))
         (renderer (mpl.rendering:make-mock-renderer)))
    ;; Mock renderer doesn't implement backends protocol,
    ;; so colorbar guards on renderer type — should not error
    (mpl.rendering:draw cb renderer)
    (pass)))

(test colorbar-marks-not-stale
  "Drawing colorbar marks it as not stale."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable))
         (cb (make-colorbar ax sm))
         (renderer (mpl.rendering:make-mock-renderer)))
    (is (eq t (mpl.rendering:artist-stale cb)))
    (mpl.rendering:draw cb renderer)
    (is (null (mpl.rendering:artist-stale cb)))))

;;; ============================================================
;;; Pipeline Tests — PNG Output
;;; ============================================================

(test pipeline-colorbar-vertical-to-png
  "Colorbar with vertical orientation produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 100)))
         (path (tmp-path "colorbar-vertical" "png")))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (make-colorbar ax sm :label "Value")
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-colorbar-horizontal-to-png
  "Colorbar with horizontal orientation produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 50)))
         (path (tmp-path "colorbar-horizontal" "png")))
    (plot ax '(1 2 3 4) '(1 4 9 16))
    (make-colorbar ax sm :orientation :horizontal)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-colorbar-custom-ticks-to-png
  "Colorbar with custom ticks produces valid PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (sm (mpl.primitives:make-scalar-mappable
              :norm (mpl.primitives:make-normalize :vmin 0 :vmax 1)))
         (path (tmp-path "colorbar-custom-ticks" "png")))
    (plot ax '(1 2 3) '(1 4 9))
    (make-colorbar ax sm :ticks '(0.0d0 0.25d0 0.5d0 0.75d0 1.0d0))
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-colorbar-tests ()
  "Run all colorbar tests and return success boolean."
  (let ((results (run 'colorbar-suite)))
    (explain! results)
    (results-status results)))
