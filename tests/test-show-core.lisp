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

;;; a recording adapter: (show) must register every open figure, current last
(defclass %recording-adapter () ((shown :initform nil :accessor %shown)))
(defmethod mpl.show:show-figure ((a %recording-adapter) figure &key block)
  (declare (ignore block))
  (push figure (%shown a))
  figure)

(test pyplot-show-registers-every-figure
  (mpl.show:wm-close-all)
  (mpl.pyplot:close-figure :all)
  (let ((adapter (make-instance '%recording-adapter)))
    (mpl.show:register-show-adapter :recording (lambda () adapter))
    (unwind-protect
         (let ((mpl.show:*show-backend* :recording))
           (let ((f1 (mpl.pyplot:figure))
                 (f2 (mpl.pyplot:figure))
                 (f3 (mpl.pyplot:figure)))
             (mpl.pyplot:figure :num (mpl.pyplot:figure-number f2))   ; make f2 current
             (mpl.pyplot:show)
             ;; only the current figure goes to the adapter ...
             (is (equal (list f2) (%shown adapter)))
             ;; ... but every figure has a window, in number order, current active
             (is (equal (list f1 f2 f3)
                        (mapcar #'mpl.show:figure-window-figure (mpl.show:wm-windows))))
             (is (eq f2 (mpl.show:figure-window-figure (mpl.show:wm-active-window))))
             ;; showing again adds nothing
             (mpl.pyplot:show)
             (is (= 3 (length (mpl.show:wm-windows))))))
      (setf mpl.show::*adapters* (remove :recording mpl.show::*adapters* :key #'first))
      (mpl.show:wm-close-all)
      (mpl.pyplot:close-figure :all))))

;;; ============================================================
;;; Interaction: 3D gestures, picking, clipboard, undo, legend, cursor
;;; ============================================================

(defun %two-line-figure ()
  "A figure with a zig-zag red line and a flat blue line, plus a legend."
  (mpl.pyplot:close-figure :all)
  (let ((fig (mpl.pyplot:figure)))
    (mpl.pyplot:plot '(0 1 2 3 4) '(0 1 0 1 0) :label "zig" :color "red")
    (mpl.pyplot:plot '(0 1 2 3 4) '(3 3 3 3 3) :label "flat" :color "blue")
    (mpl.pyplot:legend)
    fig))

(defun %flat-line (fig)
  (find "flat" (mpl.containers:axes-base-lines (first (mpl.containers:figure-axes fig)))
        :key #'mpl.rendering:artist-label :test #'equal))

(defun %pixel-of (it artist x y)
  "Top-left-origin pixel of data point (X Y) on ARTIST's axes."
  (mpl.show:interactor-render-rgba it)
  (let* ((tr (mpl.rendering:get-artist-transform artist))
         (p (mpl.primitives:transform-point tr (list (float x 1.0d0) (float y 1.0d0))))
         (h (mpl.containers:figure-height-px (mpl.show:interactor-figure it))))
    (values (round (elt p 0)) (round (- h (elt p 1))))))

(test rotate-3d-by-drag
  (mpl.pyplot:close-figure :all)
  (mpl.pyplot:subplots 1 1 :projection :3d)
  (mpl.pyplot:plot3d '(0 1 2) '(0 1 0) '(0 1 2))
  (let* ((fig (mpl.pyplot:gcf))
         (ax (first (mpl.containers:figure-axes fig)))
         (it (mpl.show:make-interactor fig)))
    (mpl.show:interactor-render-rgba it)
    (multiple-value-bind (ax0 ay0 aw ah) (mpl.show::%axes-pixel-bbox it ax)
      (declare (ignore ax0 ay0))
      ;; drag right by aw/4 and up by ah/4 → Axes3D._on_move: delev = -dy*180, dazim = -dx*180
      (let ((x0 300) (y0 240))
        (is (eq ax (mpl.show:interactor-pan-start it x0 y0)))
        (mpl.show:interactor-pan-move it (+ x0 (round (/ aw 4))) (- y0 (round (/ ah 4))))
        (mpl.show:interactor-pan-end it)
        (is (< (abs (- (mpl.containers:axes-3d-elev ax) (- 30 45))) 1.5))
        (is (< (abs (- (mpl.containers:axes-3d-azim ax) (- -60 45))) 1.5))))
    ;; wheel zoom shrinks the projected window; home restores everything
    (let ((x0 (mpl.primitives:bbox-x0 (mpl.containers:axes-base-view-lim ax))))
      (mpl.show:interactor-zoom it 300 240 2.0d0)
      (is (> (mpl.primitives:bbox-x0 (mpl.containers:axes-base-view-lim ax)) x0))
      (mpl.show:interactor-reset it)
      (is (= 30.0d0 (mpl.containers:axes-3d-elev ax)))
      (is (= -60.0d0 (mpl.containers:axes-3d-azim ax)))
      (is (< (abs (- (mpl.primitives:bbox-x0 (mpl.containers:axes-base-view-lim ax)) x0)) 1d-12)))
    ;; a rotated 3D frame still renders
    (mpl.show:interactor-pan-start it 300 240)
    (mpl.show:interactor-pan-move it 320 250)
    (mpl.show:interactor-pan-end it)
    (finishes (mpl.show:interactor-render-rgba it))))

(test pick-hit-and-miss
  (let* ((fig (%two-line-figure))
         (it (mpl.show:make-interactor fig))
         (flat (%flat-line fig)))
    (multiple-value-bind (px py) (%pixel-of it flat 2 3)
      (is (eq flat (mpl.show:interactor-pick it px py)))
      (is (eq flat (mpl.show:interactor-pick it px (+ py 3))))
      (is (null (mpl.show:interactor-pick it px (+ py 25))))
      (multiple-value-bind (artist index x y) (mpl.show:interactor-nearest-point it px py)
        (is (eq artist flat))
        (is (= index 2))
        (is (= x 2.0d0))
        (is (= y 3.0d0)))
      (let ((info (mpl.show:interactor-cursor-info it px py)))
        (is (equal "flat" (getf info :label)))
        (is (= 2 (getf info :index)))))))

(test click-select-copy-paste-across-figures
  (let* ((fig (%two-line-figure))
         (it (mpl.show:make-interactor fig))
         (flat (%flat-line fig)))
    (multiple-value-bind (px py) (%pixel-of it flat 2 3)
      (is (eq :frame (mpl.show:interactor-handle-event it (list :type :click :x px :y py))))
      (is (eq flat (mpl.show:interactor-selection it)))
      (mpl.show:interactor-handle-event it (list :type :keydown :key "c" :ctrl t))
      (is (= 1 (length mpl.show:*trace-clipboard*)))
      ;; paste into a second figure
      (let* ((fig2 (mpl.pyplot:figure))
             (ax2 (progn (mpl.pyplot:plot '(0 1) '(0 1)) (first (mpl.containers:figure-axes fig2))))
             (it2 (mpl.show:make-interactor fig2)))
        (mpl.show:interactor-render-rgba it2)
        (is (eq :frame (mpl.show:interactor-handle-event it2 (list :type :keydown :key "v" :ctrl t))))
        (is (= 2 (length (mpl.containers:axes-base-lines ax2))))
        (let ((pasted (mpl.show:interactor-selection it2)))
          (is (typep pasted 'mpl.rendering:line-2d))
          (is (equal "flat" (mpl.rendering:artist-label pasted)))
          (is (equalp (coerce (mpl.rendering:line-2d-ydata pasted) 'list) '(3.0d0 3.0d0 3.0d0 3.0d0 3.0d0)))
          (is (equal "blue" (mpl.rendering:line-2d-color pasted))))
        ;; undo removes it, redo restores it
        (is (eq :frame (mpl.show:interactor-handle-event it2 (list :type :keydown :key "z" :ctrl t))))
        (is (= 1 (length (mpl.containers:axes-base-lines ax2))))
        (is (eq :frame (mpl.show:interactor-handle-event it2 (list :type :keydown :key "z" :ctrl t :shift t))))
        (is (= 2 (length (mpl.containers:axes-base-lines ax2))))
        (finishes (mpl.show:interactor-render-rgba it2))))))

(test cut-and-undo-restores-order
  (let* ((fig (%two-line-figure))
         (it (mpl.show:make-interactor fig))
         (ax (first (mpl.containers:figure-axes fig)))
         (flat (%flat-line fig))
         (before (copy-list (mpl.containers:axes-base-lines ax))))
    (mpl.show:interactor-select it flat)
    (is (eq :frame (mpl.show:interactor-handle-event it (list :type :keydown :key "x" :ctrl t))))
    (is (= 1 (length (mpl.containers:axes-base-lines ax))))
    (is (null (mpl.show:interactor-selection it)))
    (is (mpl.show:interactor-can-undo-p it))
    (mpl.show:interactor-undo it)
    (is (equal before (mpl.containers:axes-base-lines ax)))
    (is (mpl.show:interactor-can-redo-p it))))

(test legend-click-toggles-series
  (let* ((fig (%two-line-figure))
         (it (mpl.show:make-interactor fig))
         (ax (first (mpl.containers:figure-axes fig))))
    (mpl.show:interactor-render-rgba it)
    (let* ((leg (mpl.containers:axes-base-legend ax))
           (entry (first (mpl.containers:legend-entry-bboxes leg)))
           (h (mpl.containers:figure-height-px fig)))
      (is (= 2 (length (mpl.containers:legend-entry-bboxes leg))))
      (destructuring-bind (handle x0 y0 x1 y1) entry
        (let ((lx (round (/ (+ x0 x1) 2))) (ly (round (- h (/ (+ y0 y1) 2)))))
          (is (eq handle (mpl.show:interactor-legend-hit it lx ly)))
          (let ((frame-before (copy-seq (mpl.show:interactor-render-rgba it))))
            (is (eq :frame (mpl.show:interactor-handle-event it (list :type :click :x lx :y ly))))
            (is (not (mpl.rendering:artist-visible handle)))
            (is (not (equalp frame-before (mpl.show:interactor-render-rgba it))))
            (mpl.show:interactor-undo it)
            (is (mpl.rendering:artist-visible handle))
            (is (equalp frame-before (mpl.show:interactor-render-rgba it)))))))))

(test cursor-mode-pins-and-overlay
  (let* ((fig (%two-line-figure))
         (it (mpl.show:make-interactor fig))
         (flat (%flat-line fig)))
    (multiple-value-bind (px py) (%pixel-of it flat 2 3)
      (let ((plain (copy-seq (mpl.show:interactor-render-rgba it))))
        (is (eq :coords (mpl.show:interactor-handle-event it (list :type :keydown :key "c"))))
        (is (eq :cursor (mpl.show:interactor-mode it)))
        (is (eq :frame (mpl.show:interactor-handle-event it (list :type :click :x px :y py))))
        (is (equal (list (list flat 2)) (mpl.show:interactor-pins it)))
        ;; the pin is drawn as an overlay, the figure itself is untouched
        (is (not (equalp plain (mpl.show:interactor-render-rgba it))))
        (is (equal '(3.0d0 3.0d0 3.0d0 3.0d0 3.0d0) (coerce (mpl.rendering:line-2d-ydata flat) 'list)))
        (is (eq :frame (mpl.show:interactor-handle-event it (list :type :keydown :key "Escape"))))
        (is (null (mpl.show:interactor-pins it)))
        (is (equalp plain (mpl.show:interactor-render-rgba it)))))))

(test selection-highlight-is-an-overlay
  (let* ((fig (%two-line-figure))
         (it (mpl.show:make-interactor fig))
         (flat (%flat-line fig)))
    (let ((plain (copy-seq (mpl.show:interactor-render-rgba it))))
      (mpl.show:interactor-select it flat)
      (is (not (equalp plain (mpl.show:interactor-render-rgba it))))
      (mpl.show:interactor-clear-selection it)
      (is (equalp plain (mpl.show:interactor-render-rgba it))))))

;;; ============================================================
;;; Window manager
;;; ============================================================

(defun %wm-reset ()
  (mpl.show:wm-close-all)
  (mpl.pyplot:close-figure :all))

(test wm-register-activate-close
  (%wm-reset)
  (let* ((events '())
         (listener (mpl.show:wm-add-listener (lambda (ev w) (push (list ev (mpl.show:figure-window-id w)) events)))))
    (unwind-protect
         (let* ((f1 (mpl.pyplot:figure))
                (f2 (mpl.pyplot:figure))
                (w1 (mpl.show:wm-register f1))
                (w2 (mpl.show:wm-register f2 :title "second")))
           (is (= 2 (length (mpl.show:wm-windows))))
           (is (equal "second" (mpl.show:figure-window-title w2)))
           (is (search "Figure" (mpl.show:figure-window-title w1)))
           ;; registering again returns the same window
           (is (eq w1 (mpl.show:wm-register f1)))
           (is (= 2 (length (mpl.show:wm-windows))))
           ;; the last registered/activated window is active and is pyplot's current figure
           (is (eq w1 (mpl.show:wm-active-window)))
           (is (eq f1 (mpl.pyplot:gcf)))
           (mpl.show:wm-activate (mpl.show:figure-window-id w2))
           (is (eq w2 (mpl.show:wm-active-window)))
           (is (eq f2 (mpl.pyplot:gcf)))
           (is (eq w2 (mpl.show:wm-find (mpl.show:figure-window-id w2))))
           (is (eq w2 (mpl.show:wm-window-for-figure f2)))
           ;; closing the active window activates the most recent remaining one
           (mpl.show:wm-close (mpl.show:figure-window-id w2))
           (is (mpl.show:figure-window-closed-p w2))
           (is (eq w1 (mpl.show:wm-active-window)))
           (is (= 1 (length (mpl.show:wm-windows))))
           ;; listener saw the lifecycle in order
           (let ((seq (reverse events)))
             (is (equal (list :added (mpl.show:figure-window-id w1)) (first seq)))
             (is (member (list :removed (mpl.show:figure-window-id w2)) seq :test #'equal))
             (is (member (list :activated (mpl.show:figure-window-id w2)) seq :test #'equal))))
      (mpl.show:wm-remove-listener listener)
      (%wm-reset))))

(test wm-close-figure-hook-and-wait
  (%wm-reset)
  (let* ((fig (mpl.pyplot:figure))
         (w (mpl.show:wm-register fig))
         (done nil)
         (waiter (bt:make-thread (lambda () (mpl.show:wm-wait-closed w) (setf done t)))))
    (sleep 0.1)
    (is (null done))
    ;; pyplot's close-figure closes the window and releases the waiter
    (mpl.pyplot:close-figure)
    (bt:join-thread waiter)
    (is (eq t done))
    (is (null (mpl.show:wm-window-for-figure fig)))
    (%wm-reset)))

(test wm-notify-changed-reaches-listeners
  (%wm-reset)
  (let* ((seen nil)
         (listener (mpl.show:wm-add-listener (lambda (ev w) (when (eq ev :changed) (setf seen w)))))
         (fig (mpl.pyplot:figure))
         (w (mpl.show:wm-register fig)))
    (unwind-protect
         (progn
           (is (eq w (mpl.show:wm-notify-changed fig)))
           (is (eq w seen))
           (is (null (mpl.show:wm-notify-changed (mpl.pyplot:figure)))))
      (mpl.show:wm-remove-listener listener)
      (%wm-reset))))

(defun run-show-tests ()
  "Run all cl-matplotlib-show tests and report results."
  (let ((results (run 'show-suite)))
    (explain! results)
    (unless (results-status results)
      (error "show tests failed!"))))
