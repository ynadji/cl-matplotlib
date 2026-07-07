;;;; test-show-core.lisp — cl-matplotlib-show: render-to-buffer and
;;;; interactor invariants (zoom anchoring incl. log axes, exact pan,
;;;; reset determinism, hit testing, resize).

(defpackage #:cl-matplotlib.tests.show
  (:use #:cl #:fiveam)
  (:export #:run-show-tests))

(in-package #:cl-matplotlib.tests.show)

(def-suite show-suite :description "cl-matplotlib-show test suite")
(in-suite show-suite)

(defun %fresh-line-figure (&key yscale)
  "A single-axes figure with a line plot; optional :log y scale."
  (mpl.pyplot:close-figure :all)
  (let ((fig (mpl.pyplot:figure)))
    (let ((ax (mpl.pyplot:gca)))
      (if (eq yscale :log)
          (progn
            ;; plot first: set-yscale :log recomputes view limits from
            ;; the data limits (log-space margins)
            (mpl.pyplot:plot '(1 2 3 4 5) '(0.1 1 10 100 1000))
            (mpl.containers:axes-set-yscale ax :log))
          (mpl.pyplot:plot '(1 2 3 4 5) '(2 4 1 5 3))))
    fig))

(defun %axes-center-px (fig ax)
  "Center pixel of AX in top-left-origin coordinates."
  (let ((pos (mpl.containers:axes-base-position ax))
        (w (mpl.containers:figure-width-px fig))
        (h (mpl.containers:figure-height-px fig)))
    (values (round (* (+ (first pos) (/ (third pos) 2)) w))
            (round (- h (* (+ (second pos) (/ (fourth pos) 2)) h))))))

;;; ============================================================
;;; Render to buffer
;;; ============================================================

(test render-rgba-buffer
  (let ((fig (%fresh-line-figure)))
    (multiple-value-bind (rgba w h renderer)
        (mpl.show:render-figure-to-rgba fig)
      (is (= w (mpl.containers:figure-width-px fig)))
      (is (= h (mpl.containers:figure-height-px fig)))
      (is (typep rgba '(simple-array (unsigned-byte 8) (*))))
      (is (= (length rgba) (* 4 w h)))
      (is (not (null renderer)))
      ;; a second render reusing the renderer produces identical pixels
      (multiple-value-bind (rgba2 w2 h2)
          (mpl.show:render-figure-to-rgba fig :renderer renderer)
        (is (= w w2))
        (is (= h h2))
        (is (equalp rgba rgba2))))))

(test render-png-magic
  (let ((fig (%fresh-line-figure)))
    (multiple-value-bind (png w h)
        (mpl.show:render-figure-to-png-octets fig)
      (declare (ignore w h))
      (is (> (length png) 8))
      (is (equalp #(137 80 78 71 13 10 26 10) (subseq png 0 8))))))

;;; ============================================================
;;; Zoom — cursor anchoring
;;; ============================================================

(test zoom-anchoring-linear
  (let* ((fig (%fresh-line-figure))
         (it (mpl.show:make-interactor fig))
         (ax (first (mpl.containers:figure-axes fig))))
    (multiple-value-bind (cx cy) (%axes-center-px fig ax)
      ;; offset from center so anchoring is non-trivial
      (let ((px (+ cx 40)) (py (- cy 30)))
        (multiple-value-bind (x1 y1) (mpl.show:interactor-cursor-coords it px py)
          (dotimes (i 3)
            (is (eq ax (mpl.show:interactor-zoom it px py 1.1d0))))
          (multiple-value-bind (x2 y2) (mpl.show:interactor-cursor-coords it px py)
            (is (< (abs (- x1 x2)) 1d-9))
            (is (< (abs (- y1 y2)) 1d-9))))
        ;; zooming in shrinks the x range
        (multiple-value-bind (x0 x1) (mpl.containers:axes-get-xlim ax)
          (is (< (- x1 x0) 4.5)))))))

(test zoom-anchoring-log
  (let* ((fig (%fresh-line-figure :yscale :log))
         (it (mpl.show:make-interactor fig))
         (ax (first (mpl.containers:figure-axes fig))))
    (multiple-value-bind (cx cy) (%axes-center-px fig ax)
      (let ((px (+ cx 25)) (py (+ cy 35)))
        (multiple-value-bind (x1 y1) (mpl.show:interactor-cursor-coords it px py)
          (dotimes (i 3)
            (mpl.show:interactor-zoom it px py 1.25d0))
          (multiple-value-bind (x2 y2) (mpl.show:interactor-cursor-coords it px py)
            (is (< (abs (- x1 x2)) 1d-9))
            ;; log axis: anchor holds in data space (relative tolerance)
            (is (< (abs (- y1 y2)) (* 1d-9 (max 1d0 (abs y1)))))))
        ;; limits stayed positive on the log axis
        (multiple-value-bind (y0 y1) (mpl.containers:axes-get-ylim ax)
          (is (> y0 0))
          (is (> y1 y0)))))))

;;; ============================================================
;;; Pan
;;; ============================================================

(test pan-exact-shift-linear
  (let* ((fig (%fresh-line-figure))
         (it (mpl.show:make-interactor fig))
         (ax (first (mpl.containers:figure-axes fig))))
    (multiple-value-bind (cx cy) (%axes-center-px fig ax)
      (multiple-value-bind (x0 x1) (mpl.containers:axes-get-xlim ax)
        (multiple-value-bind (y0 y1) (mpl.containers:axes-get-ylim ax)
          (let* ((aw (* (third (mpl.containers:axes-base-position ax))
                        (mpl.containers:figure-width-px fig)))
                 (dx-px 50)
                 (expected-shift (- (* (/ dx-px aw) (- x1 x0)))))
            (is (eq ax (mpl.show:interactor-pan-start it cx cy)))
            (is (eq ax (mpl.show:interactor-pan-move it (+ cx dx-px) cy)))
            (is (eq ax (mpl.show:interactor-pan-end it)))
            (multiple-value-bind (nx0 nx1) (mpl.containers:axes-get-xlim ax)
              (is (< (abs (- nx0 (+ x0 expected-shift))) 1d-9))
              (is (< (abs (- nx1 (+ x1 expected-shift))) 1d-9)))
            ;; pure horizontal drag leaves y untouched
            (multiple-value-bind (ny0 ny1) (mpl.containers:axes-get-ylim ax)
              (is (< (abs (- ny0 y0)) 1d-9))
              (is (< (abs (- ny1 y1)) 1d-9)))))))))

(test pan-move-without-start
  (let* ((fig (%fresh-line-figure))
         (it (mpl.show:make-interactor fig)))
    (is (null (mpl.show:interactor-pan-move it 100 100)))
    (is (null (mpl.show:interactor-pan-end it)))))

;;; ============================================================
;;; Reset
;;; ============================================================

(test reset-restores-home-and-pixels
  (let* ((fig (%fresh-line-figure))
         (it (mpl.show:make-interactor fig))
         (ax (first (mpl.containers:figure-axes fig)))
         (before (mpl.show:interactor-render-rgba it)))
    (multiple-value-bind (hx0 hx1) (mpl.containers:axes-get-xlim ax)
      (multiple-value-bind (cx cy) (%axes-center-px fig ax)
        (mpl.show:interactor-zoom it (+ cx 30) cy 1.5d0)
        (mpl.show:interactor-pan-start it cx cy)
        (mpl.show:interactor-pan-move it (+ cx 40) (- cy 20))
        (mpl.show:interactor-pan-end it))
      (multiple-value-bind (zx0 zx1) (mpl.containers:axes-get-xlim ax)
        (is (not (and (= hx0 zx0) (= hx1 zx1)))))
      (mpl.show:interactor-reset it)
      (multiple-value-bind (rx0 rx1) (mpl.containers:axes-get-xlim ax)
        (is (= hx0 rx0))
        (is (= hx1 rx1)))
      ;; render after zoom→reset is byte-identical to the first frame
      (is (equalp before (mpl.show:interactor-render-rgba it))))))

;;; ============================================================
;;; Hit testing
;;; ============================================================

(test hit-test-subplots-grid
  (mpl.pyplot:close-figure :all)
  (multiple-value-bind (fig axes) (mpl.pyplot:subplots 2 2)
    (let ((it (mpl.show:make-interactor fig)))
      (dotimes (i 2)
        (dotimes (j 2)
          (let ((ax (aref axes i j)))
            (multiple-value-bind (cx cy) (%axes-center-px fig ax)
              (is (eq ax (mpl.show:interactor-hit-axes it cx cy)))))))
      ;; figure corner is outside every axes
      (is (null (mpl.show:interactor-hit-axes it 1 1))))))

;;; ============================================================
;;; Resize
;;; ============================================================

(test resize-follows-buffer
  (let* ((fig (%fresh-line-figure))
         (it (mpl.show:make-interactor fig)))
    (mpl.show:interactor-render-rgba it)
    (mpl.show:interactor-resize it 800 600)
    (multiple-value-bind (rgba w h) (mpl.show:interactor-render-rgba it)
      (is (= 800 w))
      (is (= 600 h))
      (is (= (length rgba) (* 4 800 600))))
    ;; and back down
    (mpl.show:interactor-resize it 400 300)
    (multiple-value-bind (rgba w h) (mpl.show:interactor-render-rgba it)
      (is (= 400 w))
      (is (= 300 h))
      (is (= (length rgba) (* 4 400 300))))))

;;; ============================================================
;;; pyplot hook
;;; ============================================================

(test pyplot-show-hook-wired
  (is (functionp mpl.pyplot:*show-hook*)))

(defun run-show-tests ()
  "Run all cl-matplotlib-show tests and report results."
  (let ((results (run 'show-suite)))
    (explain! results)
    (unless (results-status results)
      (error "show tests failed!"))))
