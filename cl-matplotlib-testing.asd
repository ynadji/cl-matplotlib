;;;; cl-matplotlib-testing — Image comparison testing infrastructure
;;;; Phase 8a: Foundation for porting matplotlib's 94 test files

(asdf:defsystem #:cl-matplotlib-testing
  :description "Image comparison testing infrastructure for cl-matplotlib"
  :version "0.1.0"
  :depends-on (#:pngload
               #:zpng
               #:fiveam)
  :serial t
  :pathname "src/testing/"
  :components ((:file "package")
               (:file "compare")
               (:file "decorators"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-testing/tests))))

(asdf:defsystem #:cl-matplotlib-testing/tests
  :description "Tests for cl-matplotlib-testing"
  :depends-on (#:cl-matplotlib-testing #:fiveam #:zpng)
  :pathname "tests/"
  :components ((:file "test-testing"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.testing '#:run-testing-tests)))

;;; Ported image comparison tests (batch 1/3)
(asdf:defsystem #:cl-matplotlib-testing/ported
  :description "Ported image comparison tests from matplotlib (batch 1/3)"
  :depends-on (#:cl-matplotlib-testing
               #:cl-matplotlib-pyplot
               #:fiveam)
  :pathname "tests/"
  :serial t
  :components ((:file "test-backend-pdf-ported")
               (:file "test-pyplot-ported")
               (:file "test-legend-ported")
               (:file "test-colorbar-ported")
               (:file "test-scale-ported"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.backend-pdf-ported
                               '#:run-backend-pdf-ported-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.pyplot-ported
                               '#:run-pyplot-ported-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.legend-ported
                               '#:run-legend-ported-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.colorbar-ported
                               '#:run-colorbar-ported-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.scale-ported
                               '#:run-scale-ported-tests)))
