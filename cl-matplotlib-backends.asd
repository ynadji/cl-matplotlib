;;;; cl-matplotlib-backends — Vecto/cl-aa based rendering backends

(asdf:defsystem #:cl-matplotlib-backends
  :description "Backend implementations for cl-matplotlib (Vecto/cl-aa based)"
  :version "0.0.1"
  :depends-on (#:cl-matplotlib-rendering
               #:vecto
               #:zpb-ttf
               #:zpng)
  :serial t
  :pathname "src/backends/"
  :components ())
