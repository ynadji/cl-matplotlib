;;;; cl-matplotlib-show-web — browser display backend (WebAgg-style)
;;;; PNG frames over a websocket to an HTML canvas; zoom/pan/home events
;;;; back. One lazily-started server; each (show) registers a figure
;;;; session addressed as /figure/<id>.

(asdf:defsystem #:cl-matplotlib-show-web
  :description "Browser display backend for cl-matplotlib — HTTP + websocket + HTML canvas"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-show
               #:clack
               #:clack-handler-hunchentoot
               #:websocket-driver
               #:yason
               #:trivial-open-browser)
  :serial t
  :pathname "src/show/web/"
  :components ((:file "packages")
               (:file "events")
               (:file "server"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-show-web/tests))))

(asdf:defsystem #:cl-matplotlib-show-web/tests
  :description "Tests for cl-matplotlib-show-web (pure event-handling parts; the websocket round-trip lives in tests/integration/test_show_web.py)"
  :depends-on (#:cl-matplotlib-show-web #:fiveam)
  :pathname "tests/"
  :components ((:file "test-show-web"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.show-web '#:run-show-web-tests)))
