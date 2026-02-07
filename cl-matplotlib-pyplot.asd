;;;; cl-matplotlib-pyplot — Top-level plotting API
;;;; Phase 7a: Procedural pyplot interface wrapping OO Figure/Axes API

(asdf:defsystem #:cl-matplotlib-pyplot
  :description "Top-level pyplot API for cl-matplotlib — procedural wrappers around Figure/Axes"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-containers
               #:cl-matplotlib-backends)
  :serial t
  :pathname "src/pyplot/"
  :components ((:file "pyplot"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-pyplot/tests))))

(asdf:defsystem #:cl-matplotlib-pyplot/tests
  :description "Tests for cl-matplotlib-pyplot"
  :depends-on (#:cl-matplotlib-pyplot #:fiveam)
  :pathname "tests/"
  :components ((:file "test-pyplot"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.pyplot '#:run-pyplot-tests)))
