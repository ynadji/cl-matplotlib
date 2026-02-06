;;;; cl-matplotlib — Pure Common Lisp matplotlib port
;;;; Main system definition

(asdf:defsystem #:cl-matplotlib
  :description "Pure Common Lisp implementation of matplotlib plotting library"
  :author "cl-matplotlib contributors"
  :license "BSD-3-Clause"
  :version "0.0.1"
  :depends-on (#:cl-matplotlib-foundation
               #:cl-matplotlib-primitives
               #:cl-matplotlib-rendering
               #:cl-matplotlib-containers
               #:cl-matplotlib-backends
               #:cl-matplotlib-pyplot)
  :serial t
  :components ((:file "src/packages")))
