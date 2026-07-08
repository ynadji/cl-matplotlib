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
;;;; signals a single summary error at the end if any failed.
;;;;
;;;; The base library suites are hard :depends-on. The display backends
;;;; (show / show-web / show-sdl2) are instead loaded lazily inside
;;;; perform and guarded: an adapter that is unavailable — a native lib
;;;; like libSDL2 that isn't installed, web deps not fetched, or a newly
;;;; added .asd not yet in ASDF's source registry — is reported SKIPPED
;;;; rather than aborting the whole run. (If a show suite is unexpectedly
;;;; skipped right after adding these systems, refresh discovery with
;;;; (asdf:clear-source-registry) — or (ql:register-local-projects) under
;;;; a Quicklisp local-projects setup — then re-run.)
(asdf:defsystem #:cl-matplotlib/tests
  :description "Aggregate: run every cl-matplotlib subsystem test suite via one test-system"
  :depends-on (#:cl-matplotlib-foundation/tests
               #:cl-matplotlib-primitives/tests
               #:cl-matplotlib-rendering/tests
               #:cl-matplotlib-backends/tests
               #:cl-matplotlib-containers/tests
               #:cl-matplotlib-pyplot/tests
               #:cl-matplotlib-testing/tests
               #:ggplot/tests)
  :perform (asdf:test-op (o c)
             (declare (ignore o c))
             (let ((required '("cl-matplotlib-foundation/tests"
                               "cl-matplotlib-primitives/tests"
                               "cl-matplotlib-rendering/tests"
                               "cl-matplotlib-backends/tests"
                               "cl-matplotlib-containers/tests"
                               "cl-matplotlib-pyplot/tests"
                               "cl-matplotlib-testing/tests"
                               "ggplot/tests"))
                   ;; Optional display backends: loaded lazily and
                   ;; guarded so a missing native lib / undiscovered .asd
                   ;; is skipped, not fatal.
                   (optional '("cl-matplotlib-show/tests"
                               "cl-matplotlib-show-web/tests"
                               "cl-matplotlib-show-sdl2/tests"))
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
                       ;; load the primary system first so a missing
                       ;; foreign lib / undiscovered .asd is caught here
                       ;; as "unavailable" rather than a test failure
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
