;;;; cl-matplotlib-show-emacs — display figures inside Emacs over SLIME/SLY.
;;;; No window system, no server: the figure is rendered to SVG text and
;;;; shown in an Emacs image buffer through swank/slynk's eval-in-emacs.

(asdf:defsystem #:cl-matplotlib-show-emacs
  :description "Emacs display backend for cl-matplotlib — SVG image buffer via SLIME/SLY eval-in-emacs"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-show)
  :serial t
  :pathname "src/show/emacs/"
  :components ((:file "emacs-adapter"))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-show-emacs/tests))))

(asdf:defsystem #:cl-matplotlib-show-emacs/tests
  :description "Tests for cl-matplotlib-show-emacs (no Emacs connection needed)"
  :depends-on (#:cl-matplotlib-show-emacs #:fiveam)
  :pathname "tests/"
  :components ((:file "test-show-emacs"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.show-emacs '#:run-show-emacs-tests)))
