;;;; cl-matplotlib-show-sdl2 — native window display backend via SDL2.

(asdf:defsystem #:cl-matplotlib-show-sdl2
  :description "Native SDL2 display backend for cl-matplotlib — streaming-texture window with zoom/pan/reset"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-show #:sdl2)
  :serial t
  :pathname "src/show/sdl2/"
  :components ((:file "sdl2-adapter"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-show-sdl2/tests))))

(asdf:defsystem #:cl-matplotlib-show-sdl2/tests
  :description "Tests for cl-matplotlib-show-sdl2 (smoke test; needs SDL_VIDEODRIVER=dummy when headless)"
  :depends-on (#:cl-matplotlib-show-sdl2 #:fiveam)
  :pathname "tests/"
  :components ((:file "test-show-sdl2"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.show-sdl2 '#:run-show-sdl2-tests)))
