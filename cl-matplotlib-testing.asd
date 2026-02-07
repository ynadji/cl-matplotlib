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
