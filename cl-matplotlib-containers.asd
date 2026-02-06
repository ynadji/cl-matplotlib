;;;; cl-matplotlib-containers — Figure, Axes, layout engines
;;;; Phase 4a: Figure, FigureCanvas, savefig pipeline, layout engines
;;;; Phase 4b: Axes with plot, scatter, bar — MVP complete

(asdf:defsystem #:cl-matplotlib-containers
  :description "Container hierarchy for cl-matplotlib: Figure, Axes, layout engines"
  :version "0.2.0"
  :depends-on (#:cl-matplotlib-backends)
  :serial t
  :pathname "src/containers/"
  :components ((:file "layout-engine")
               (:file "figure")
               (:file "axes-base")
               (:file "axes"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-containers/tests))))

(asdf:defsystem #:cl-matplotlib-containers/tests
  :description "Tests for cl-matplotlib-containers"
  :depends-on (#:cl-matplotlib-containers #:fiveam)
  :pathname "tests/"
  :components ((:file "test-figure")
               (:file "test-axes"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.figure '#:run-figure-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.axes '#:run-axes-tests)))
