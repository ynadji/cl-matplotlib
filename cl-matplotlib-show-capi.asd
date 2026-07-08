;;;; cl-matplotlib-show-capi — LispWorks CAPI display backend (stretch).
;;;; Only loadable on LispWorks; developed best-effort without a
;;;; LispWorks environment — see docs/interactive.md before relying on it.

(asdf:defsystem #:cl-matplotlib-show-capi
  :description "LispWorks CAPI display backend for cl-matplotlib (untested outside LispWorks)"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-show)
  :serial t
  :pathname "src/show/capi/"
  :components ((:file "capi-adapter")))
