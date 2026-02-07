;;;; test-style.lisp — Tests for style sheet system
;;;; Phase 7c — Style sheets

(defpackage #:cl-matplotlib.tests.style
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rc
                #:use-style #:with-style #:available-styles #:reload-styles
                #:rc #:initialize-styles))

(in-package #:cl-matplotlib.tests.style)

(def-suite style-suite :description "Style sheet system test suite")
(in-suite style-suite)

;;; ============================================================
;;; Initialization tests
;;; ============================================================

(test initialize-styles
  "Test that styles can be initialized"
  (initialize-styles)
  (is (not (null (available-styles)))))

;;; ============================================================
;;; available-styles tests
;;; ============================================================

(test available-styles-returns-list
  "Test that available-styles returns a list"
  (let ((styles (available-styles)))
    (is (listp styles))))

(test available-styles-contains-core-styles
  "Test that available-styles contains all 8 core styles"
  (let ((styles (available-styles)))
    (is (member :default styles))
    (is (member :classic styles))
    (is (member :ggplot styles))
    (is (member :seaborn styles))
    (is (member :bmh styles))
    (is (member :dark_background styles))
    (is (member :fivethirtyeight styles))
    (is (member :grayscale styles))))

(test available-styles-sorted
  "Test that available-styles returns sorted list"
  (let ((styles (available-styles)))
    (is (equal styles (sort (copy-list styles) #'string< :key #'symbol-name)))))

;;; ============================================================
;;; use-style tests
;;; ============================================================

(test use-style-single-style
  "Test applying a single style"
  (use-style :ggplot)
  ;; ggplot has axes.facecolor: E5E5E5
  (is (string-equal (rc "axes.facecolor") "#E5E5E5")))

(test use-style-dark-background
  "Test applying dark_background style"
  (use-style :dark_background)
  ;; dark_background has axes.facecolor: black
  (is (string-equal (rc "axes.facecolor") "black")))

(test use-style-seaborn
  "Test applying seaborn style"
  (use-style :seaborn)
  ;; seaborn has axes.facecolor: EAEAF2
  (is (string-equal (rc "axes.facecolor") "#EAEAF2")))

(test use-style-multiple-styles
  "Test applying multiple styles (later overrides earlier)"
  (use-style '(:ggplot :dark_background))
  ;; dark_background should override ggplot
  (is (string-equal (rc "axes.facecolor") "black")))

(test use-style-list-single-element
  "Test applying a list with single style"
  (use-style '(:bmh))
  ;; bmh has axes.facecolor: eeeeee
  (is (string-equal (rc "axes.facecolor") "#eeeeee")))

;;; ============================================================
;;; with-style macro tests
;;; ============================================================

(test with-style-temporary-override
  "Test that with-style temporarily overrides rcParams"
  (let ((original (rc "axes.facecolor")))
    (with-style (:ggplot)
      ;; Inside the macro, should be ggplot style
      (is (string-equal (rc "axes.facecolor") "#E5E5E5")))
    ;; After the macro, should be restored
    (is (string-equal (rc "axes.facecolor") original))))

(test with-style-restores-on-error
  "Test that with-style restores params even on error"
  (let ((original (rc "axes.facecolor")))
    (handler-case
        (with-style (:dark_background)
          (is (string-equal (rc "axes.facecolor") "black"))
          (error "Test error"))
      (error nil))
    ;; Should be restored despite error
    (is (string-equal (rc "axes.facecolor") original))))

(test with-style-multiple-styles
  "Test with-style with multiple styles"
  (let ((original (rc "axes.facecolor")))
    (with-style (:ggplot :dark_background)
      ;; dark_background should override ggplot
      (is (string-equal (rc "axes.facecolor") "black")))
    ;; Should be restored
    (is (string-equal (rc "axes.facecolor") original))))

(test with-style-nested
  "Test nested with-style calls"
  (let ((original (rc "axes.facecolor")))
    (with-style (:ggplot)
      (is (string-equal (rc "axes.facecolor") "#E5E5E5"))
      (with-style (:dark_background)
        (is (string-equal (rc "axes.facecolor") "black")))
      ;; Should be restored to ggplot
      (is (string-equal (rc "axes.facecolor") "#E5E5E5")))
    ;; Should be restored to original
    (is (string-equal (rc "axes.facecolor") original))))

;;; ============================================================
;;; reload-styles tests
;;; ============================================================

(test reload-styles-clears-cache
  "Test that reload-styles clears the style cache"
  ;; Load a style to populate cache
  (use-style :ggplot)
  ;; Reload should work without error
  (reload-styles)
  ;; Should still be able to use styles
  (use-style :seaborn)
  (is (string-equal (rc "axes.facecolor") "#EAEAF2")))

;;; ============================================================
;;; Style-specific tests
;;; ============================================================

(test style-default
  "Test default style"
  (use-style :default)
  ;; default has axes.grid: False (converted to NIL)
  (is (null (rc "axes.grid"))))

(test style-classic
  "Test classic style"
  (use-style :classic)
  ;; classic has lines.color: b
  (is (string-equal (rc "lines.color") "b")))

(test style-bmh
  "Test bmh style"
  (use-style :bmh)
  ;; bmh has axes.grid: True (converted to T)
  (is (eq (rc "axes.grid") t)))

(test style-fivethirtyeight
  "Test fivethirtyeight style"
  (use-style :fivethirtyeight)
  ;; fivethirtyeight has axes.grid: true (converted to T)
  (is (eq (rc "axes.grid") t)))

(test style-grayscale
  "Test grayscale style"
  (use-style :grayscale)
  ;; grayscale has lines.color: black
  (is (string-equal (rc "lines.color") "black")))

;;; ============================================================
;;; Integration tests
;;; ============================================================

(test style-changes-multiple-params
  "Test that styles change multiple parameters"
  (use-style :ggplot)
  ;; ggplot should set multiple params
  (is (string-equal (rc "axes.facecolor") "#E5E5E5"))
  (is (string-equal (rc "axes.edgecolor") "white"))
  (is (eq (rc "axes.grid") t)))

(test style-override-chain
  "Test that later styles override earlier ones"
  (use-style :ggplot)
  (let ((ggplot-facecolor (rc "axes.facecolor")))
    (use-style :dark_background)
    (let ((dark-facecolor (rc "axes.facecolor")))
      (is (not (string-equal ggplot-facecolor dark-facecolor))))))

;;; ============================================================
;;; Test runner
;;; ============================================================

(defun run-style-tests ()
  "Run all style tests and return results"
  (run! 'style-suite))
