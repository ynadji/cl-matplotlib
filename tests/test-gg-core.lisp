;;;; test-gg-core.lisp — PR0 tests: data protocol, aes, stack, blank build

(defpackage #:ggplot.tests
  (:use #:cl #:fiveam)
  (:export #:run-gg-tests))

(in-package #:ggplot.tests)

(def-suite gg-suite :description "ggplot core test suite")
(in-suite gg-suite)

;;; ============================================================
;;; Data protocol
;;; ============================================================

(test protocol-column-plist
  (let ((data '(:x #(1 2 3) :y #(4 5 6))))
    (is-true (gg:ggdata-p data))
    (is (equal '(:x :y) (gg:ggcolumns data)))
    (is (equalp #(1 2 3) (gg:ggcolumn data :x)))
    (is (equalp #(4 5 6) (gg:ggcolumn data "y")))
    (is (= 3 (gg:ggnrows data)))))

(test protocol-column-alist
  (let ((data '((:x . #(1 2 3)) ("y" . (4 5 6)))))
    (is-true (gg:ggdata-p data))
    (is (equal '(:x :y) (gg:ggcolumns data)))
    (is (equalp #(4 5 6) (gg:ggcolumn data :y)))
    (is (= 3 (gg:ggnrows data)))))

(test protocol-row-plists
  (let ((data '((:x 1 :y 4) (:x 2 :y 5) (:x 3 :y 6))))
    (is-true (gg:ggdata-p data))
    (is (equal '(:x :y) (gg:ggcolumns data)))
    (is (equalp #(1 2 3) (gg:ggcolumn data :x)))
    (is (= 3 (gg:ggnrows data)))))

(test protocol-hash-table
  (let ((data (make-hash-table :test #'equal)))
    (setf (gethash "x" data) #(1 2)
          (gethash "y" data) #(3 4))
    (is-true (gg:ggdata-p data))
    (is (equalp #(1 2) (gg:ggcolumn data :x)))
    (is (= 2 (gg:ggnrows data)))))

(test protocol-ggdata-array
  (let ((data (gg:make-ggdata (make-array '(3 2) :initial-contents
                                          '((1 4) (2 5) (3 6)))
                              :columns '(:x :y))))
    (is-true (gg:ggdata-p data))
    (is (equal '(:x :y) (gg:ggcolumns data)))
    (is (equalp #(4 5 6) (gg:ggcolumn data :y)))
    (is (= 3 (gg:ggnrows data)))))

(test protocol-rejects-non-data
  (is-false (gg:ggdata-p 42))
  (is-false (gg:ggdata-p "hello"))
  (signals error (gg:ggplot 42)))

;;; ============================================================
;;; aes
;;; ============================================================

(test aes-plist-form
  (let ((m (gg:aes :x :wt :y :mpg :color :cyl)))
    (is (eq :wt (ggplot::aes-ref m :x)))
    (is (eq :mpg (ggplot::aes-ref m :y)))
    (is (eq :cyl (ggplot::aes-ref m :color)))))

(test aes-positional-form
  (let ((m (gg:aes :wt :mpg :color :cyl)))
    (is (eq :wt (ggplot::aes-ref m :x)))
    (is (eq :mpg (ggplot::aes-ref m :y)))
    (is (eq :cyl (ggplot::aes-ref m :color)))))

(test aes-colour-canonicalized
  (let ((m (gg:aes :x :a :colour :b)))
    (is (eq :b (ggplot::aes-ref m :color)))))

(test aes-rejects-unknown
  (signals error (gg:aes :x :a :wibble :b)))

(test aes-function-reference
  (let* ((data '(:v #(1.0d0 2.0d0 3.0d0)))
         (plot (gg:stack (gg:ggplot data (gg:aes :x (lambda (tbl)
                                                      (map 'vector
                                                           (lambda (v) (* 2 v))
                                                           (gg:ggcolumn tbl :v)))
                                          :y :v))
                 (gg:geom-blank)))
         (built (gg:ggbuild plot))
         (table (cdr (first (ggplot::ggbuilt-layer-tables built)))))
    (is (equalp #(2.0d0 4.0d0 6.0d0) (ggplot::gtable-column table :x)))))

;;; ============================================================
;;; stack / ++ / immutability
;;; ============================================================

(test stack-returns-new-plot
  (let* ((p (gg:ggplot '(:x #(1 2) :y #(3 4)) (gg:aes :x :x :y :y)))
         (p2 (gg:stack p (gg:geom-blank))))
    (is (not (eq p p2)))
    (is (= 0 (length (ggplot::plot-layers p))))
    (is (= 1 (length (ggplot::plot-layers p2))))))

(test stack-nil-component-is-noop
  (let* ((p (gg:ggplot '(:x #(1 2) :y #(3 4)) (gg:aes :x :x :y :y)))
         (p2 (gg:stack p nil (gg:geom-blank) nil)))
    (is (= 1 (length (ggplot::plot-layers p2))))))

(test stack-folds-labs
  (let* ((p (gg:ggplot '(:x #(1 2) :y #(3 4)) (gg:aes :x :x :y :y)))
         (p2 (gg:stack p (gg:geom-blank) (gg:ggtitle "hi"))))
    (is (= 1 (length (ggplot::plot-layers p2))))
    (is (equal "hi" (cdr (assoc :title (ggplot::plot-labs p2)))))))

(test theme-merge
  (let* ((p (gg:ggplot '(:x #(1 2) :y #(3 4)) (gg:aes :x :x :y :y)))
         (p2 (gg:stack p
               (gg:theme-gray)
               (gg:theme :panel-background (gg:element-rect :fill "white")))))
    (let ((theme (ggplot::plot-theme p2)))
      (is (equal "white"
                 (ggplot::element-rect-fill
                  (ggplot::theme-element theme :panel-background))))
      ;; unmerged elements from theme-gray survive
      (is (not (null (ggplot::theme-element theme :axis-text)))))))

;;; ============================================================
;;; Extended Wilkinson breaks (mizani parity)
;;; ============================================================

(test extended-breaks-basic
  ;; mizani extended_breaks()(0, 100) -> [0, 25, 50, 75, 100]
  (is (equalp '(0.0d0 25.0d0 50.0d0 75.0d0 100.0d0)
              (ggplot::extended-breaks 0 100)))
  ;; mizani extended_breaks()(0, 1) -> [0, 0.25, 0.5, 0.75, 1]
  (is (equalp '(0.0d0 0.25d0 0.5d0 0.75d0 1.0d0)
              (ggplot::extended-breaks 0 1)))
  ;; mizani extended_breaks()(1, 9) -> [2, 4, 6, 8] or [2.5 5 7.5]? verified below
  (let ((breaks (ggplot::extended-breaks 1 9)))
    (is (every (lambda (b) (<= 0 b 10)) breaks))
    (is (<= 3 (length breaks) 6))))

;;; ============================================================
;;; Date scales
;;; ============================================================

(test date-breaks-anchor
  ;; plotnine phase: '6 months' over a range starting 2022-11-25 anchors
  ;; at the first month-start inside the range (2022-12), not the month
  ;; containing lo.
  (let* ((lo (gg:date 2022 11 25))
         (hi (gg:date 2024 12 15))
         (uts (ggplot::%date-break-uts lo hi '(:month 6))))
    (is (equal '("2022-12" "2023-06" "2023-12" "2024-06" "2024-12")
               (mapcar (lambda (ut) (gg:format-date ut "%Y-%m")) uts))))
  ;; Yearly breaks skip a year-start before lo.
  (let* ((lo (gg:date 2021 3 1))
         (hi (gg:date 2024 6 1))
         (uts (ggplot::%date-break-uts lo hi '(:year 1))))
    (is (equal '("2022" "2023" "2024")
               (mapcar (lambda (ut) (gg:format-date ut "%Y")) uts)))))

(test format-date-directives
  (let ((ut (gg:date 2024 3 7)))
    (is (string= "2024-03-07" (gg:format-date ut "%Y-%m-%d")))
    (is (string= "Mar 7" (gg:format-date ut "%b %e")))
    (is (string= "March 24" (gg:format-date ut "%B %y")))))

;;; ============================================================
;;; Build pipeline
;;; ============================================================

(test build-blank-plot
  (let* ((p (gg:ggplot '(:x #(1.0d0 5.0d0) :y #(10.0d0 20.0d0))
                       (gg:aes :x :x :y :y)))
         (built (gg:ggbuild p))
         (panel (first (ggplot::ggbuilt-panels built))))
    ;; implicit geom-blank layer
    (is (= 1 (length (ggplot::ggbuilt-layer-tables built))))
    ;; expanded range: [1,5] +/- 5% of 4 = [0.8, 5.2]
    (destructuring-bind (lo hi) (getf panel :x-range)
      (is (< (abs (- lo 0.8d0)) 1.0d-9))
      (is (< (abs (- hi 5.2d0)) 1.0d-9)))
    (destructuring-bind (lo hi) (getf panel :y-range)
      (is (< (abs (- lo 9.5d0)) 1.0d-9))
      (is (< (abs (- hi 20.5d0)) 1.0d-9)))
    ;; breaks lie inside the expanded range
    (is (every (lambda (b) (<= 0.8d0 b 5.2d0)) (getf panel :x-breaks)))))

(test build-explicit-limits
  (let* ((p (gg:stack (gg:ggplot '(:x #(1.0d0 5.0d0) :y #(1.0d0 2.0d0))
                                 (gg:aes :x :x :y :y))
              (gg:xlim 0 10)))
         (built (gg:ggbuild p))
         (panel (first (ggplot::ggbuilt-panels built))))
    (destructuring-bind (lo hi) (getf panel :x-range)
      (is (< (abs (- lo -0.5d0)) 1.0d-9))
      (is (< (abs (- hi 10.5d0)) 1.0d-9)))))

;;; ============================================================
;;; Render smoke test
;;; ============================================================

(test render-blank-to-png
  (let* ((p (gg:ggplot '(:x #(1.0d0 2.0d0 3.0d0) :y #(1.0d0 4.0d0 9.0d0))
                       (gg:aes :x :x :y :y)))
         (path (format nil "/tmp/gg-test-blank-~D.png" (get-universal-time))))
    (finishes (gg:ggsave p path))
    (is-true (probe-file path))
    (when (probe-file path)
      (delete-file path))))

;;; ============================================================
;;; Scale long tail
;;; ============================================================

(test brewer-palette-values
  ;; mizani brewer_pal('qual', 'Set2')(3)
  (is (equal '("#66C2A5" "#FC8D62" "#8DA0CB")
             (ggplot::brewer-palette "Set2" 3)))
  (signals error (ggplot::brewer-palette "Set2" 99))
  (signals error (ggplot::brewer-palette "NoSuch" 3)))

(test gradient2-midpoint-maps-mid-color
  (let ((scale (gg:scale-fill-gradient2 :low "#000000" :mid "#FFFFFF"
                                        :high "#0000FF" :midpoint 0)))
    (ggplot::scale-train scale #(-2.0d0 2.0d0))
    (is (string-equal "#FFFFFF"
                      (svref (ggplot::scale-map scale #(0.0d0)) 0)))))

(test reverse-scale-negates-and-relabels
  (let ((scale (gg:scale-y-reverse)))
    (is (equalp #(-1.0d0 -2.0d0)
                (ggplot::scale-transform scale #(1.0d0 2.0d0))))
    (is (equal '("1" "2")
               (ggplot::scale-break-labels scale '(-1.0d0 -2.0d0))))))

;;; ============================================================
;;; Facets: grid layout, labellers, free scales
;;; ============================================================

(test facet-grid-layout
  (let* ((p (gg:ggadd
             (gg:ggadd (gg:ggplot '(:g #("u" "u" "v" "v")
                                   :h #("p" "q" "p" "q")
                                   :x #(1.0d0 2.0d0 3.0d0 4.0d0)
                                   :y #(1.0d0 2.0d0 3.0d0 4.0d0))
                                 (gg:aes :x :x :y :y))
                       (gg:geom-point))
             (gg:facet-grid :rows :g :cols :h)))
         (built (gg:ggbuild p))
         (panels (ggplot::ggbuilt-panels built)))
    (is (= 4 (length panels)))
    (is (= 2 (ggplot::ggbuilt-nrow built)))
    (is (= 2 (ggplot::ggbuilt-ncol built)))
    ;; top strips only on row 0, right strips only on last col
    (let ((p00 (first panels)) (p11 (fourth panels)))
      (is (string= "p" (getf p00 :label)))
      (is (null (getf p00 :row-label)))
      (is (null (getf p11 :label)))
      (is (string= "v" (getf p11 :row-label))))))

(test facet-labeller-both
  (multiple-value-bind (layout nrow ncol)
      (ggplot::facet-layout
       (gg:facet-wrap :g :labeller :both)
       (list (ggplot::make-gtable :g #("a" "b"))))
    (declare (ignore nrow ncol))
    (is (string= "g: a" (getf (first layout) :label)))))

(test facet-free-y-panels
  (let* ((p (gg:ggadd
             (gg:ggadd (gg:ggplot '(:g #("a" "a" "b" "b")
                                   :x #(1.0d0 2.0d0 1.0d0 2.0d0)
                                   :y #(1.0d0 2.0d0 100.0d0 200.0d0))
                                 (gg:aes :x :x :y :y))
                       (gg:geom-point))
             (gg:facet-wrap :g :scales :free-y)))
         (built (gg:ggbuild p))
         (panels (ggplot::ggbuilt-panels built)))
    (destructuring-bind (y0-lo y0-hi) (getf (first panels) :y-range)
      (destructuring-bind (y1-lo y1-hi) (getf (second panels) :y-range)
        ;; panel a spans ~1..2, panel b ~100..200
        (is (< y0-hi 10.0d0))
        (is (> y1-lo 10.0d0))
        (is (< y0-lo y0-hi))
        (is (< y1-lo y1-hi))))))

;;; ============================================================
;;; Extension API (gg.ext)
;;; ============================================================
;;; A miniature third-party extension: a custom stat registered under a
;;; keyword and a custom geom, both defined purely against gg.ext.

(defclass test-stat-double (gg.ext:stat) ())

(defmethod gg.ext:stat-compute-panel ((stat test-stat-double) data scales &key)
  (declare (ignore scales))
  (gg.ext:map-stat-groups
   data
   (lambda (sub)
     (let ((x (gg.ext:gtable-column sub :x))
           (y (gg.ext:gtable-column sub :y)))
       (gg.ext:make-gtable
        :x x
        :y (map 'simple-vector (lambda (v) (* 2 v)) y))))))

(defclass test-geom-dot (gg.ext:geom) ())

(defmethod gg.ext:geom-default-aes ((geom test-geom-dot))
  '(:color "black" :size 1.5d0 :alpha 1.0d0 :stroke 0.5d0 :shape :o))

(defmethod gg.ext:geom-key-glyph ((geom test-geom-dot)) :point)

(defmethod gg.ext:geom-draw-panel ((geom test-geom-dot) data panel axes)
  (declare (ignore panel))
  (let ((x (gg.ext:gtable-column data :x))
        (y (gg.ext:gtable-column data :y)))
    (cl-matplotlib.containers:scatter
     axes (coerce x 'list) (coerce y 'list)
     :s (gg.ext:size-to-scatter-s 1.5d0) :zorder 2)))

(test extension-stat-and-geom
  (gg.ext:register-stat :test-double 'test-stat-double)
  (let* ((layer (gg.ext:make-geom-layer 'test-geom-dot
                                        '() :stat :test-double))
         (p (gg:ggadd (gg:ggplot '(:x #(1.0d0 2.0d0 3.0d0)
                                   :y #(1.0d0 2.0d0 3.0d0))
                                 (gg:aes :x :x :y :y))
                      layer))
         (built (gg:ggbuild p))
         (table (cdr (first (ggplot::ggbuilt-layer-tables built)))))
    ;; the custom stat doubled y
    (is (equalp #(2.0d0 4.0d0 6.0d0) (gg.ext:gtable-column table :y)))
    ;; and the custom geom renders
    (let ((path (format nil "/tmp/gg-test-ext-~D.png" (get-universal-time))))
      (finishes (gg:ggsave p path))
      (is-true (probe-file path))
      (when (probe-file path) (delete-file path)))))

(test extension-register-aesthetic
  (gg.ext:register-aesthetic :height)
  (finishes (gg:aes :x :a :height :h)))

;;; ============================================================
;;; Runner
;;; ============================================================

(defun run-gg-tests ()
  "Run all gg tests, signaling an error on failure."
  (let ((results (run 'gg-suite)))
    (explain! results)
    (unless (results-status results)
      (error "gg tests failed"))
    results))

;;; ============================================================
;;; Coord protocol: polar math, trans breaks, munching
;;; ============================================================

(test coord-polar-transform-math
  (let ((coord (gg:coord-polar :theta :x))
        (panel '(:x-raw-range (0.0d0 10.0d0) :y-raw-range (0.0d0 1.0d0)
                 :x-range (0.0d0 10.0d0) :y-range (0.0d0 1.0d0))))
    ;; theta 0 at 12 o'clock: (0, r) -> (0, r)
    (multiple-value-bind (xs ys)
        (ggplot::coord-transform-points coord '(0.0d0) '(1.0d0) panel)
      (is (< (abs (first xs)) 1d-9))
      (is (< (abs (- (first ys) 1.0d0)) 1d-9)))
    ;; quarter turn clockwise: x = 2.5 -> 3 o'clock = (1, 0)
    (multiple-value-bind (xs ys)
        (ggplot::coord-transform-points coord '(2.5d0) '(1.0d0) panel)
      (is (< (abs (- (first xs) 1.0d0)) 1d-9))
      (is (< (abs (first ys)) 1d-9))))
  ;; direction -1 goes anticlockwise
  (let ((coord (gg:coord-polar :theta :x :direction -1))
        (panel '(:x-raw-range (0.0d0 10.0d0) :y-raw-range (0.0d0 1.0d0)
                 :x-range (0.0d0 10.0d0) :y-range (0.0d0 1.0d0))))
    (multiple-value-bind (xs ys)
        (ggplot::coord-transform-points coord '(2.5d0) '(1.0d0) panel)
      (declare (ignore ys))
      (is (< (abs (- (first xs) -1.0d0)) 1d-9)))))

(test coord-munch-counts
  (multiple-value-bind (xs ys)
      (ggplot::%munch-segments '(0.0d0 1.0d0 2.0d0) '(0.0d0 1.0d0 0.0d0)
                               :n 10)
    ;; 2 segments x 10 + final point
    (is (= 21 (length xs)))
    (is (= 21 (length ys)))))

(test coord-trans-break-positions
  (let ((coord (gg:coord-trans :x :log10)))
    (is (equal '(0.0d0 1.0d0 2.0d0)
               (mapcar (lambda (v) (float v 1d0))
                       (ggplot::coord-adjust-breaks
                        coord '(1.0d0 10.0d0 100.0d0) :x))))
    ;; y untransformed
    (is (equal '(5.0d0) (ggplot::coord-adjust-breaks coord '(5.0d0) :y)))))

(test coord-flip-through-protocol
  (let ((table (ggplot::make-gtable :x #(1.0d0) :y #(2.0d0))))
    (let ((flipped (ggplot::coord-transform-table (gg:coord-flip) table nil)))
      (is (= 2.0d0 (svref (ggplot::gtable-column flipped :x) 0)))
      (is (= 1.0d0 (svref (ggplot::gtable-column flipped :y) 0))))
    ;; cartesian is identity
    (is (eq table (ggplot::coord-transform-table (gg:coord-cartesian)
                                                 table nil)))))

(test coord-pie-renders
  (let ((p (gg:stack (gg:ggplot '(:cat #("a" "b") :value #(30.0d0 70.0d0))
                                (gg:aes :x 0 :y :value :fill :cat))
             (gg:geom-bar :stat :identity :width 1)
             (gg:coord-polar :theta :y))))
    (let ((path (format nil "/tmp/gg-pie-test-~D.png" (get-universal-time))))
      (finishes (gg:ggsave p path))
      (is-true (probe-file path))
      (when (probe-file path) (delete-file path)))))
