;;;; cl-matplotlib-rendering — Artist hierarchy, rendering primitives
;;;; Phase 3a: Artist base, Line2D, patches, text, markers, image
;;;; Phase 3d: Font management, text-to-path, AFM parser

(asdf:defsystem #:cl-matplotlib-rendering
  :description "Artist hierarchy and rendering primitives for cl-matplotlib"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-primitives #:zpb-ttf)
  :serial t
  :pathname "src/rendering/"
  :components ((:file "artist")
               (:file "lines")
               (:file "patches")
               (:file "text")
               (:file "markers")
               (:file "image")
               (:file "font-manager")
               (:file "text-path")
               (:file "afm"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-rendering/tests))))

(asdf:defsystem #:cl-matplotlib-rendering/tests
  :description "Tests for cl-matplotlib-rendering"
  :depends-on (#:cl-matplotlib-rendering #:fiveam)
  :pathname "tests/"
  :components ((:file "test-artist")
               (:file "test-font-manager"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.artist '#:run-artist-tests)
             (uiop:symbol-call '#:cl-matplotlib.tests.font '#:run-font-tests)))
