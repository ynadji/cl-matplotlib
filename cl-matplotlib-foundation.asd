;;;; cl-matplotlib-foundation — Core utilities, rc-params, color database

(asdf:defsystem #:cl-matplotlib-foundation
  :description "Foundation layer for cl-matplotlib: cbook utilities, rc-params, API helpers, color database"
  :version "0.1.0"
  :depends-on (#:trivial-garbage #:uiop)
  :serial t
  :pathname "src/"
  :components ((:file "packages")
               (:module "foundation"
                :serial t
                :components ((:file "cbook")
                             (:file "api")
                             (:file "rcsetup")
                             (:file "rcparams")
                             (:file "matplotlibrc-parser")
                             (:file "colors-database")))))
