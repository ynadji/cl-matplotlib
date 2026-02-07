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
                             (:file "colors-database"))))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-foundation/tests))))

(asdf:defsystem #:cl-matplotlib-foundation/tests
  :description "Tests for cl-matplotlib-foundation"
  :depends-on (#:cl-matplotlib-foundation #:fiveam)
  :pathname "tests/"
  :components ((:file "test-rcparams"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:cl-matplotlib.tests.rcparams '#:run-rcparams-tests)))
