;;;; package.lisp — Package definition for cl-matplotlib testing infrastructure
;;;; Phase 8a

(defpackage #:cl-matplotlib.testing
  (:use #:cl)
  (:nicknames #:mpl.testing)
  (:documentation "Image comparison testing infrastructure for cl-matplotlib.
Port of matplotlib.testing.compare and matplotlib.testing.decorators.")
  (:export
   ;; Image loading
   #:load-png-as-array
   ;; Comparison functions
   #:calculate-rms
   #:calculate-ssim
   #:compare-images
   #:save-diff-image
   ;; Tolerance
   #:*image-tolerance*
   ;; Baseline management
   #:*baseline-dir*
   #:baseline-dir
   #:find-baseline
   #:baseline-path
   #:update-baseline
   #:list-missing-baselines
   ;; Result directory
   #:*result-dir*
   #:result-dir
   #:result-path
   ;; FiveAM macros
   #:def-image-test
   #:def-figures-equal))
