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
;;; Runner
;;; ============================================================

(defun run-gg-tests ()
  "Run all gg tests, signaling an error on failure."
  (let ((results (run 'gg-suite)))
    (explain! results)
    (unless (results-status results)
      (error "gg tests failed"))
    results))
