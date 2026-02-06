;;;; cl-matplotlib-containers — Figure, Axes, Artist hierarchy

(asdf:defsystem #:cl-matplotlib-containers
  :description "Container hierarchy for cl-matplotlib: Figure, Axes, Artist"
  :version "0.0.1"
  :depends-on (#:cl-matplotlib-rendering)
  :serial t
  :pathname "src/containers/"
  :components ())
