;;;; cl-matplotlib-backends — Vecto/cl-aa based rendering backends
;;;; Phase 3b: RendererBase protocol + Vecto PNG backend

(asdf:defsystem #:cl-matplotlib-backends
  :description "Backend implementations for cl-matplotlib (Vecto/cl-aa based)"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-rendering
               #:vecto
               #:zpb-ttf
               #:zpng)
  :serial t
  :pathname "src/backends/"
  :components ((:file "renderer-base")
               (:file "backend-vecto"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-backends/tests))))

(asdf:defsystem #:cl-matplotlib-backends/tests
  :description "Tests for cl-matplotlib-backends"
  :depends-on (#:cl-matplotlib-backends #:fiveam)
  :pathname "tests/"
  :components ((:file "test-backend-vecto"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.backend-vecto '#:run-backend-tests)))
