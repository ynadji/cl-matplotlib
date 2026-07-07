;;;; cl-matplotlib-show — Interactive display core
;;;; Optional system (like ggplot): render-to-buffer, zoom/pan interactor,
;;;; and the adapter protocol behind pyplot's (show). Display backends
;;;; (cl-matplotlib-show-web, cl-matplotlib-show-sdl2) build on this.

(asdf:defsystem #:cl-matplotlib-show
  :description "Interactive display core for cl-matplotlib — in-memory figure rendering, zoom/pan interactor, show adapter protocol"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-backends
               #:cl-matplotlib-containers
               #:cl-matplotlib-pyplot
               #:bordeaux-threads
               #:flexi-streams
               #:vecto
               #:zpng)
  :serial t
  :pathname "src/show/"
  :components ((:file "packages")
               (:file "render")
               (:file "interactor")
               (:file "protocol"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-show/tests))))

(asdf:defsystem #:cl-matplotlib-show/tests
  :description "Tests for cl-matplotlib-show"
  :depends-on (#:cl-matplotlib-show #:fiveam)
  :pathname "tests/"
  :components ((:file "test-show-core"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.show '#:run-show-tests)))
