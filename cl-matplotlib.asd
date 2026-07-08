;;;; cl-matplotlib — Pure Common Lisp matplotlib port
;;;; Main system definition

(asdf:defsystem #:cl-matplotlib
  :description "Pure Common Lisp implementation of matplotlib plotting library"
  :author "cl-matplotlib contributors"
  :license "BSD-3-Clause"
  :version "0.0.1"
  :depends-on (#:cl-matplotlib-foundation
               #:cl-matplotlib-primitives
               #:cl-matplotlib-rendering
               #:cl-matplotlib-containers
               #:cl-matplotlib-backends
               #:cl-matplotlib-pyplot)
  :serial t
  :components ((:file "src/packages"))
  ;; (asdf:test-system :cl-matplotlib) runs every subsystem's suite.
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib/tests))))

;;;; Aggregate test system — one asdf:test-system runs them all.
;;;;
;;;; (asdf:test-system :cl-matplotlib)         ; or :cl-matplotlib/tests
;;;;
;;;; Every subsystem carries its own <sys>/tests suite; this fans test-op
;;;; out across all of them, runs each even if an earlier one fails, and
;;;; signals a single summary error at the end if any failed. The SDL2
;;;; backend needs the libSDL2 foreign library, so it is load-guarded:
;;;; a machine without it reports SDL2 as skipped instead of aborting.
(asdf:defsystem #:cl-matplotlib/tests
  :description "Aggregate: run every cl-matplotlib subsystem test suite via one test-system"
  :depends-on (#:cl-matplotlib-foundation/tests
               #:cl-matplotlib-primitives/tests
               #:cl-matplotlib-rendering/tests
               #:cl-matplotlib-backends/tests
               #:cl-matplotlib-containers/tests
               #:cl-matplotlib-pyplot/tests
               #:cl-matplotlib-testing/tests
               #:ggplot/tests
               #:cl-matplotlib-show/tests
               #:cl-matplotlib-show-web/tests)
  :perform (asdf:test-op (o c)
             (declare (ignore o c))
             (let ((required '("cl-matplotlib-foundation/tests"
                               "cl-matplotlib-primitives/tests"
                               "cl-matplotlib-rendering/tests"
                               "cl-matplotlib-backends/tests"
                               "cl-matplotlib-containers/tests"
                               "cl-matplotlib-pyplot/tests"
                               "cl-matplotlib-testing/tests"
                               "ggplot/tests"
                               "cl-matplotlib-show/tests"
                               "cl-matplotlib-show-web/tests"))
                   ;; needs the libSDL2 foreign library — skip if absent
                   (optional '("cl-matplotlib-show-sdl2/tests"))
                   (failed '())
                   (skipped '()))
               (dolist (sys required)
                 (format t "~&~%;;; ==== ~A ====~%" sys)
                 (handler-case (asdf:operate 'asdf:test-op sys)
                   (error (e)
                     (push sys failed)
                     (format t "~&;;; FAILED ~A: ~A~%" sys e))))
               (dolist (sys optional)
                 (format t "~&~%;;; ==== ~A ====~%" sys)
                 (handler-case
                     (progn
                       (asdf:load-system (subseq sys 0 (position #\/ sys)))
                       (handler-case (asdf:operate 'asdf:test-op sys)
                         (error (e)
                           (push sys failed)
                           (format t "~&;;; FAILED ~A: ~A~%" sys e))))
                   (error (e)
                     (push sys skipped)
                     (format t "~&;;; SKIPPED ~A (unavailable): ~A~%" sys e))))
               (format t "~&~%;;; ================================================~%")
               (format t "~&;;; cl-matplotlib test summary: ~D failed, ~D skipped~%"
                       (length failed) (length skipped))
               (when skipped
                 (format t "~&;;;   skipped: ~{~A~^, ~}~%" (reverse skipped)))
               (when failed
                 (format t "~&;;;   failed:  ~{~A~^, ~}~%" (reverse failed))
                 (error "cl-matplotlib: ~D test suite(s) failed: ~{~A~^, ~}"
                        (length failed) (reverse failed))))))
