;;;; cl-matplotlib-rendering — Graphics context, renderer protocol

(asdf:defsystem #:cl-matplotlib-rendering
  :description "Rendering protocol for cl-matplotlib: GC, renderer base"
  :version "0.0.1"
  :depends-on (#:cl-matplotlib-primitives)
  :serial t
  :pathname "src/rendering/"
  :components ())
