;;;; test-show-web.lisp — cl-matplotlib-show-web: the pure event layer
;;;; (JSON parse, burst coalescing, interactor dispatch). The live
;;;; websocket round-trip is covered by tests/integration/test_show_web.py.

(defpackage #:cl-matplotlib.tests.show-web
  (:use #:cl #:fiveam)
  (:export #:run-show-web-tests))

(in-package #:cl-matplotlib.tests.show-web)

(def-suite show-web-suite :description "cl-matplotlib-show-web test suite")
(in-suite show-web-suite)

(defun %ev (type &rest kv)
  (append (list :type type) kv))

(defun %fresh-interactor ()
  (mpl.pyplot:close-figure :all)
  (let ((fig (mpl.pyplot:figure)))
    (mpl.pyplot:plot '(1 2 3 4 5) '(2 4 1 5 3))
    (mpl.show:make-interactor fig)))

(defun %axes-center (it)
  (let* ((fig (mpl.show:interactor-figure it))
         (ax (first (mpl.containers:figure-axes fig)))
         (pos (mpl.containers:axes-base-position ax))
         (w (mpl.containers:figure-width-px fig))
         (h (mpl.containers:figure-height-px fig)))
    ;; a render must have happened for positions to be settled
    (mpl.show:interactor-render-rgba it)
    (values (round (* (+ (first pos) (/ (third pos) 2)) w))
            (round (- h (* (+ (second pos) (/ (fourth pos) 2)) h))))))

;;; ============================================================
;;; parse-event
;;; ============================================================

(test parse-event-fields
  (let ((ev (mpl.show.web:parse-event
             "{\"type\":\"wheel\",\"x\":120,\"y\":80,\"deltaY\":-100}")))
    (is (string= "wheel" (getf ev :type)))
    (is (= 120 (getf ev :x)))
    (is (= 80 (getf ev :y)))
    (is (= -100 (getf ev :delta-y)))
    (is (null (getf ev :w))))
  (let ((ev (mpl.show.web:parse-event "{\"type\":\"resize\",\"w\":800,\"h\":600}")))
    (is (string= "resize" (getf ev :type)))
    (is (= 800 (getf ev :w)))
    (is (= 600 (getf ev :h)))))

;;; ============================================================
;;; coalesce-events
;;; ============================================================

(test coalesce-mousemove-burst
  (let ((out (mpl.show.web:coalesce-events
              (list (%ev "mousemove" :x 1 :y 1)
                    (%ev "mousemove" :x 2 :y 2)
                    (%ev "mousemove" :x 3 :y 3)))))
    (is (= 1 (length out)))
    (is (= 3 (getf (first out) :x)))))

(test coalesce-wheel-burst-sums-deltas
  (let ((out (mpl.show.web:coalesce-events
              (list (%ev "wheel" :x 10 :y 10 :delta-y -100)
                    (%ev "wheel" :x 12 :y 11 :delta-y -100)
                    (%ev "wheel" :x 14 :y 12 :delta-y -100)))))
    (is (= 1 (length out)))
    (is (= -300 (getf (first out) :delta-y)))
    ;; merged wheel lands at the latest cursor position
    (is (= 14 (getf (first out) :x)))))

(test coalesce-preserves-boundaries
  ;; a mousedown between moves must survive, and order must hold
  (let ((out (mpl.show.web:coalesce-events
              (list (%ev "mousemove" :x 1 :y 1)
                    (%ev "mousemove" :x 2 :y 2)
                    (%ev "mousedown" :x 2 :y 2)
                    (%ev "mousemove" :x 3 :y 3)
                    (%ev "mousemove" :x 4 :y 4)
                    (%ev "mouseup")))))
    (is (equal '("mousemove" "mousedown" "mousemove" "mouseup")
               (mapcar (lambda (e) (getf e :type)) out)))
    (is (= 2 (getf (first out) :x)))
    (is (= 4 (getf (third out) :x)))))

(test coalesce-empty-and-single
  (is (null (mpl.show.web:coalesce-events '())))
  (let ((out (mpl.show.web:coalesce-events (list (%ev "home")))))
    (is (= 1 (length out)))))

;;; ============================================================
;;; apply-event dispatch
;;; ============================================================

(test apply-wheel-zooms-and-requests-frame
  (let ((it (%fresh-interactor)))
    (multiple-value-bind (cx cy) (%axes-center it)
      (let* ((fig (mpl.show:interactor-figure it))
             (ax (first (mpl.containers:figure-axes fig))))
        (multiple-value-bind (x0 x1) (mpl.containers:axes-get-xlim ax)
          (is (eq :frame (mpl.show.web:apply-event
                          it (%ev "wheel" :x cx :y cy :delta-y -100))))
          (multiple-value-bind (nx0 nx1) (mpl.containers:axes-get-xlim ax)
            ;; deltaY < 0 (scroll toward user) zooms IN
            (is (< (- nx1 nx0) (- x1 x0)))))
        ;; wheel outside every axes: no frame
        (is (null (mpl.show.web:apply-event
                   it (%ev "wheel" :x 1 :y 1 :delta-y -100))))))))

(test apply-drag-cycle
  (let ((it (%fresh-interactor)))
    (multiple-value-bind (cx cy) (%axes-center it)
      ;; hover before drag: coords only
      (is (eq :coords (mpl.show.web:apply-event it (%ev "mousemove" :x cx :y cy))))
      (is (null (mpl.show.web:apply-event it (%ev "mousedown" :x cx :y cy))))
      (is (eq :frame (mpl.show.web:apply-event
                      it (%ev "mousemove" :x (+ cx 30) :y cy))))
      (is (null (mpl.show.web:apply-event it (%ev "mouseup"))))
      ;; after mouseup, moves are coords again
      (is (eq :coords (mpl.show.web:apply-event
                       it (%ev "mousemove" :x (+ cx 40) :y cy)))))))

(test apply-home-and-resize
  (let ((it (%fresh-interactor)))
    (multiple-value-bind (cx cy) (%axes-center it)
      (mpl.show.web:apply-event it (%ev "wheel" :x cx :y cy :delta-y -200))
      (is (eq :frame (mpl.show.web:apply-event it (%ev "home"))))
      (is (eq :frame (mpl.show.web:apply-event it (%ev "resize" :w 500 :h 400))))
      (multiple-value-bind (rgba w h) (mpl.show:interactor-render-rgba it)
        (declare (ignore rgba))
        (is (= 500 w))
        (is (= 400 h)))
      ;; degenerate resize is refused
      (is (null (mpl.show.web:apply-event it (%ev "resize" :w 2 :h 2)))))))

(test coords-json-content
  (let ((it (%fresh-interactor)))
    (multiple-value-bind (cx cy) (%axes-center it)
      (let ((json (mpl.show.web:coords-json it cx cy)))
        (is (search "\"type\":\"coords\"" json))
        (is (search "\"x\":" json)))
      ;; outside all axes: bare message, no x
      (let ((json (mpl.show.web:coords-json it 1 1)))
        (is (search "\"type\":\"coords\"" json))
        (is (not (search "\"x\":" json)))))))

(defun run-show-web-tests ()
  "Run all cl-matplotlib-show-web tests and report results."
  (let ((results (run 'show-web-suite)))
    (explain! results)
    (unless (results-status results)
      (error "show-web tests failed!"))))
