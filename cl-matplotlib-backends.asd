;;;; cl-matplotlib-backends — Vecto/cl-aa + cl-pdf rendering backends
;;;; Phase 3b: RendererBase protocol + Vecto PNG backend
;;;; Phase 3c: cl-pdf PDF backend

(asdf:defsystem #:cl-matplotlib-backends
  :description "Backend implementations for cl-matplotlib (Vecto + cl-pdf + SVG)"
  :version "0.2.0"
  :depends-on (#:cl-matplotlib-rendering
               #:vecto
               #:zpb-ttf
               #:zpng
               #:cl-pdf)
  :serial t
  :pathname "src/backends/"
  :components ((:file "renderer-base")
               (:file "backend-vecto")
               (:file "backend-pdf")
               (:file "backend-svg"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-backends/tests))))

(asdf:defsystem #:cl-matplotlib-backends/tests
  :description "Tests for cl-matplotlib-backends"
  :depends-on (#:cl-matplotlib-backends #:fiveam)
  :pathname "tests/"
  :components ((:file "test-backend-vecto")
               (:file "test-backend-pdf")
               (:file "test-backend-svg"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.backend-vecto '#:run-backend-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.backend-pdf '#:run-pdf-backend-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.backend-svg '#:run-svg-backend-tests)))
