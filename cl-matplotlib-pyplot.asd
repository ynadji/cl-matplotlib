;;;; cl-matplotlib-pyplot — Top-level plotting API

(asdf:defsystem #:cl-matplotlib-pyplot
  :description "Top-level pyplot API for cl-matplotlib"
  :version "0.0.1"
  :depends-on (#:cl-matplotlib-containers
               #:cl-matplotlib-backends)
  :serial t
  :pathname "src/pyplot/"
  :components ())
