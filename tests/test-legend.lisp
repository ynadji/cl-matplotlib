;;;; test-legend.lisp — Tests for Legend and Legend Handlers
;;;; Phase 4d — FiveAM test suite

(defpackage #:cl-matplotlib.tests.legend
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                ;; Legend handlers
                #:handler-base #:handler-line-2d #:handler-patch
                #:handler-line-collection #:handler-path-collection
                #:create-legend-artists #:legend-artist
                #:get-legend-handler #:*default-handler-map*
                ;; Legend class
                #:mpl-legend #:legend-parent #:legend-handles #:legend-labels
                #:legend-loc #:legend-frameon-p #:legend-facecolor
                #:legend-edgecolor #:legend-framealpha #:legend-title
                #:legend-fontsize #:legend-entry-artists #:legend-frame
                #:*legend-codes* #:*legend-loc-positions*
                ;; Legend convenience
                #:axes-legend
                ;; Axes
                #:axes-base #:axes-base-figure #:axes-base-lines
                #:axes-base-patches #:axes-base-artists #:axes-base-legend
                #:mpl-axes
                ;; Plotting functions
                #:add-subplot #:plot #:scatter #:bar
                ;; Figure
                #:mpl-figure #:make-figure #:figure-axes #:savefig)
  (:export #:run-legend-tests))

(in-package #:cl-matplotlib.tests.legend)

(def-suite legend-suite :description "Legend and handler test suite")
(in-suite legend-suite)

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

;;; ============================================================
;;; Handler Tests
;;; ============================================================

(test handler-base-creation
  "HandlerBase can be created."
  (let ((h (make-instance 'handler-base)))
    (is (typep h 'handler-base))
    (is (= 0.0 (cl-matplotlib.containers::handler-xpad h)))
    (is (= 0.0 (cl-matplotlib.containers::handler-ypad h)))))

(test handler-line-2d-creation
  "HandlerLine2D can be created."
  (let ((h (make-instance 'handler-line-2d)))
    (is (typep h 'handler-line-2d))
    (is (typep h 'handler-base))
    (is (= 2 (cl-matplotlib.containers::handler-numpoints h)))))

(test handler-patch-creation
  "HandlerPatch can be created."
  (let ((h (make-instance 'handler-patch)))
    (is (typep h 'handler-patch))
    (is (typep h 'handler-base))))

(test handler-line-collection-creation
  "HandlerLineCollection can be created."
  (let ((h (make-instance 'handler-line-collection)))
    (is (typep h 'handler-line-collection))
    (is (typep h 'handler-base))))

(test handler-path-collection-creation
  "HandlerPathCollection can be created."
  (let ((h (make-instance 'handler-path-collection)))
    (is (typep h 'handler-path-collection))
    (is (= 3 (cl-matplotlib.containers::handler-pc-numpoints h)))))

(test handler-line-2d-creates-artists
  "HandlerLine2D creates a Line2D for legend entry."
  (let* ((h (make-instance 'handler-line-2d))
         (line (make-instance 'mpl.rendering:line-2d
                              :xdata '(1 2 3) :ydata '(1 4 9)
                              :color "red" :linewidth 2.0))
         (leg (make-instance 'mpl-legend :handles (list line) :labels (list "test")))
         (artists (create-legend-artists h leg line 0.0d0 0.0d0 20.0d0 10.0d0 10.0d0
                                         mpl.primitives:*identity-transform*)))
    (is (= 1 (length artists)))
    (is (typep (first artists) 'mpl.rendering:line-2d))
    (is (string= "red" (mpl.rendering:line-2d-color (first artists))))
    (is (= 2.0 (mpl.rendering:line-2d-linewidth (first artists))))))

(test handler-patch-creates-artists
  "HandlerPatch creates a Rectangle for legend entry."
  (let* ((h (make-instance 'handler-patch))
         (rect (make-instance 'mpl.rendering:rectangle
                              :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0
                              :facecolor "blue" :edgecolor "black"))
         (leg (make-instance 'mpl-legend :handles (list rect) :labels (list "test")))
         (artists (create-legend-artists h leg rect 0.0d0 0.0d0 20.0d0 10.0d0 10.0d0
                                         mpl.primitives:*identity-transform*)))
    (is (= 1 (length artists)))
    (is (typep (first artists) 'mpl.rendering:rectangle))))

(test handler-path-collection-creates-circles
  "HandlerPathCollection creates circles for scatter legend."
  (let* ((h (make-instance 'handler-path-collection))
         (circle (make-instance 'mpl.rendering:circle
                                :center '(1.0d0 1.0d0) :radius 3.0d0
                                :facecolor "green"))
         (leg (make-instance 'mpl-legend :handles (list circle) :labels (list "test")))
         (artists (create-legend-artists h leg circle 0.0d0 0.0d0 20.0d0 10.0d0 10.0d0
                                         mpl.primitives:*identity-transform*)))
    (is (= 3 (length artists)))
    (is (every (lambda (a) (typep a 'mpl.rendering:circle)) artists))))

(test get-legend-handler-line
  "get-legend-handler returns HandlerLine2D for Line2D."
  (let* ((line (make-instance 'mpl.rendering:line-2d))
         (handler (get-legend-handler line)))
    (is (typep handler 'handler-line-2d))))

(test get-legend-handler-rectangle
  "get-legend-handler returns HandlerPatch for Rectangle."
  (let* ((rect (make-instance 'mpl.rendering:rectangle
                              :x0 0.0d0 :y0 0.0d0 :width 1.0d0 :height 1.0d0))
         (handler (get-legend-handler rect)))
    (is (typep handler 'handler-patch))))

(test get-legend-handler-circle
  "get-legend-handler returns HandlerPathCollection for Circle."
  (let* ((circ (make-instance 'mpl.rendering:circle
                              :center '(0.0d0 0.0d0) :radius 1.0d0))
         (handler (get-legend-handler circ)))
    (is (typep handler 'handler-path-collection))))

(test get-legend-handler-polygon
  "get-legend-handler returns HandlerPatch for Polygon."
  (let* ((verts (make-array '(3 2) :element-type 'double-float
                            :initial-contents '((0.0d0 0.0d0) (1.0d0 0.0d0) (0.5d0 1.0d0))))
         (poly (make-instance 'mpl.rendering:polygon :xy verts))
         (handler (get-legend-handler poly)))
    (is (typep handler 'handler-patch))))

;;; ============================================================
;;; Legend Constants Tests
;;; ============================================================

(test legend-codes-defined
  "Legend position codes are defined."
  (is (not (null *legend-codes*)))
  (is (= 0 (cdr (assoc :best *legend-codes*))))
  (is (= 1 (cdr (assoc :upper-right *legend-codes*))))
  (is (= 2 (cdr (assoc :upper-left *legend-codes*))))
  (is (= 3 (cdr (assoc :lower-left *legend-codes*))))
  (is (= 4 (cdr (assoc :lower-right *legend-codes*)))))

(test legend-loc-positions-defined
  "Legend location positions are defined for all codes."
  (is (not (null *legend-loc-positions*)))
  ;; All 10 positions should be defined (1-10)
  (loop for code from 1 to 10
        do (is (not (null (assoc code *legend-loc-positions*))))))

;;; ============================================================
;;; Legend Class Tests
;;; ============================================================

(test legend-creation-basic
  "mpl-legend can be created with handles and labels."
  (let* ((line (make-instance 'mpl.rendering:line-2d
                              :xdata '(1 2 3) :ydata '(1 4 9)
                              :color "blue" :label "Line 1"))
         (leg (make-instance 'mpl-legend
                             :handles (list line)
                             :labels (list "Line 1"))))
    (is (typep leg 'mpl-legend))
    (is (typep leg 'mpl.rendering:artist))
    (is (= 1 (length (legend-handles leg))))
    (is (equal '("Line 1") (legend-labels leg)))
    (is (= 5 (mpl.rendering:artist-zorder leg)))))

(test legend-default-properties
  "Legend has correct default properties."
  (let ((leg (make-instance 'mpl-legend
                            :handles nil :labels nil)))
    (is (eq t (legend-frameon-p leg)))
    (is (string= "white" (legend-facecolor leg)))
    (is (string= "#cccccc" (legend-edgecolor leg)))
    (is (= 0.8d0 (legend-framealpha leg)))
    (is (string= "" (legend-title leg)))
    (is (= 10.0 (legend-fontsize leg)))))

(test legend-loc-keyword-resolution
  "Legend loc keyword resolves to numeric code."
  (let ((leg (make-instance 'mpl-legend
                            :handles nil :labels nil
                            :loc :upper-right)))
    (is (= 1 (legend-loc leg)))))

(test legend-loc-best-resolves
  "Legend loc :best resolves to code 0."
  (let ((leg (make-instance 'mpl-legend
                            :handles nil :labels nil
                            :loc :best)))
    (is (= 0 (legend-loc leg)))))

(test legend-loc-all-positions
  "All legend position keywords resolve correctly."
  (loop for (kw . code) in *legend-codes*
        do (let ((leg (make-instance 'mpl-legend
                                     :handles nil :labels nil :loc kw)))
             (is (= code (legend-loc leg))))))

(test legend-frame-created
  "Legend creates a frame rectangle when frameon=T."
  (let ((leg (make-instance 'mpl-legend
                            :handles nil :labels nil
                            :frameon t)))
    (is (not (null (legend-frame leg))))
    (is (typep (legend-frame leg) 'mpl.rendering:rectangle))))

(test legend-no-frame-when-off
  "Legend doesn't create frame when frameon=NIL."
  (let ((leg (make-instance 'mpl-legend
                            :handles nil :labels nil
                            :frameon nil)))
    (is (null (legend-frame leg)))))

(test legend-entries-built
  "Legend builds entry artists from handles and labels."
  (let* ((line (make-instance 'mpl.rendering:line-2d
                              :xdata '(1 2 3) :ydata '(1 4 9)
                              :color "red"))
         (leg (make-instance 'mpl-legend
                             :handles (list line)
                             :labels (list "My Line"))))
    (is (= 1 (length (legend-entry-artists leg))))
    ;; Each entry is (handle-artists . text-artist)
    (let ((entry (first (legend-entry-artists leg))))
      (is (listp (car entry)))
      (is (typep (cdr entry) 'mpl.rendering:text-artist))
      (is (string= "My Line" (mpl.rendering:text-text (cdr entry)))))))

(test legend-multiple-entries
  "Legend builds multiple entries."
  (let* ((line1 (make-instance 'mpl.rendering:line-2d :color "red"))
         (line2 (make-instance 'mpl.rendering:line-2d :color "blue"))
         (leg (make-instance 'mpl-legend
                             :handles (list line1 line2)
                             :labels (list "Line 1" "Line 2"))))
    (is (= 2 (length (legend-entry-artists leg))))))

(test legend-with-title
  "Legend can have a title."
  (let ((leg (make-instance 'mpl-legend
                            :handles nil :labels nil
                            :title "My Legend")))
    (is (string= "My Legend" (legend-title leg)))))

;;; ============================================================
;;; Axes.legend() Tests
;;; ============================================================

(test axes-legend-auto-labels
  "axes-legend auto-collects labeled artists."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9) :label "Line 1")
    (plot ax '(1 2 3) '(2 5 10) :label "Line 2")
    (let ((leg (axes-legend ax)))
      (is (not (null leg)))
      (is (typep leg 'mpl-legend))
      (is (= 2 (length (legend-handles leg))))
      ;; Labels may be in reverse order since lines are pushed (most recent first)
      ;; The important thing is both are present
      (is (= 2 (length (legend-labels leg))))
      (is (member "Line 1" (legend-labels leg) :test #'string=))
      (is (member "Line 2" (legend-labels leg) :test #'string=)))))

(test axes-legend-custom-handles-labels
  "axes-legend accepts custom handles and labels."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (line (make-instance 'mpl.rendering:line-2d :color "green")))
    (let ((leg (axes-legend ax
                            :handles (list line)
                            :labels (list "Custom"))))
      (is (not (null leg)))
      (is (= 1 (length (legend-handles leg))))
      (is (equal '("Custom") (legend-labels leg))))))

(test axes-legend-position
  "axes-legend sets the requested position."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (let ((leg (axes-legend ax :loc :lower-left)))
      (is (= 3 (legend-loc leg))))))

(test axes-legend-no-labels-returns-nil
  "axes-legend returns nil when no labeled artists."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9))  ;; no label
    (is (null (axes-legend ax)))))

(test axes-legend-skips-underscore-labels
  "axes-legend skips artists with labels starting with underscore."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9) :label "_internal")
    (plot ax '(1 2 3) '(2 5 10) :label "Visible")
    (let ((leg (axes-legend ax)))
      (is (not (null leg)))
      (is (= 1 (length (legend-handles leg))))
      (is (equal '("Visible") (legend-labels leg))))))

(test axes-legend-stored-in-axes
  "axes-legend stores the legend in axes slot."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (let ((leg (axes-legend ax)))
      (is (eq leg (axes-base-legend ax))))))

(test axes-legend-added-to-artists
  "axes-legend adds legend to axes artists list."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (let ((leg (axes-legend ax)))
      (is (member leg (axes-base-artists ax))))))

(test axes-legend-frameon-false
  "axes-legend respects frameon=nil."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (let ((leg (axes-legend ax :frameon nil)))
      (is (null (legend-frameon-p leg)))
      (is (null (legend-frame leg))))))

(test axes-legend-custom-fontsize
  "axes-legend respects fontsize parameter."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (let ((leg (axes-legend ax :fontsize 14.0)))
      (is (= 14.0 (legend-fontsize leg))))))

;;; ============================================================
;;; Legend Draw Tests
;;; ============================================================

(test legend-draw-with-mock-renderer
  "Legend can be drawn with mock renderer without error."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (renderer (mpl.rendering:make-mock-renderer)))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (let ((leg (axes-legend ax)))
      ;; Should not error — mock renderer doesn't implement backends protocol
      ;; but legend guards on renderer type
      (mpl.rendering:draw leg renderer)
      (pass))))

(test legend-marks-not-stale-after-draw
  "Drawing legend marks it as not stale."
  (let* ((line (make-instance 'mpl.rendering:line-2d :color "red"))
         (leg (make-instance 'mpl-legend
                             :handles (list line)
                             :labels (list "Test")))
         (renderer (mpl.rendering:make-mock-renderer)))
    (is (eq t (mpl.rendering:artist-stale leg)))
    (mpl.rendering:draw leg renderer)
    (is (null (mpl.rendering:artist-stale leg)))))

;;; ============================================================
;;; Pipeline Tests — PNG Output
;;; ============================================================

(test pipeline-plot-with-legend-to-png
  "Full pipeline: plot with legend produces valid PNG."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "legend-plot" "png")))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Quadratic")
    (plot ax '(1 2 3 4) '(2 4 6 8) :label "Linear")
    (axes-legend ax)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-legend-upper-left-to-png
  "Legend at upper-left produces valid PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "legend-upper-left" "png")))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (axes-legend ax :loc :upper-left)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-legend-lower-right-to-png
  "Legend at lower-right produces valid PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "legend-lower-right" "png")))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (axes-legend ax :loc :lower-right)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-legend-no-frame-to-png
  "Legend without frame produces valid PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "legend-no-frame" "png")))
    (plot ax '(1 2 3) '(1 4 9) :label "Data")
    (axes-legend ax :frameon nil)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-legend-scatter-to-png
  "Legend with scatter plot produces valid PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "legend-scatter" "png")))
    (scatter ax '(1 2 3 4 5) '(2 4 1 5 3) :label "Points")
    (axes-legend ax)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

(test pipeline-legend-mixed-to-png
  "Legend with mixed plot types produces valid PNG."
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (path (tmp-path "legend-mixed" "png")))
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Line")
    (bar ax '(1 2 3 4) '(3 5 2 7) :label "Bars")
    (axes-legend ax)
    (savefig fig path)
    (is (file-exists-and-valid-p path))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Evidence Generation
;;; ============================================================

(test evidence-phase4d-legend
  "Generate evidence PNG for Phase 4d: legend with two lines."
  (let* ((fig (make-figure :figsize '(6.4 4.8) :dpi 100))
         (ax (add-subplot fig 1 1 1))
         (evidence-dir ".sisyphus/evidence/")
         (path (format nil "~Aphase4d-legend.png" evidence-dir)))
    ;; Ensure directory exists
    (ensure-directories-exist path)
    (plot ax '(1 2 3 4) '(1 4 9 16) :label "Quadratic" :color "C0")
    (plot ax '(1 2 3 4) '(2 4 6 8) :label "Linear" :color "C1")
    (axes-legend ax :loc :upper-left)
    (savefig fig path)
    (is (file-exists-and-valid-p path 1000))
    (is (png-header-valid-p path))))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-legend-tests ()
  "Run all legend tests and return success boolean."
  (let ((results (run 'legend-suite)))
    (explain! results)
    (results-status results)))
