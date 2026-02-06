;;;; cl-matplotlib-primitives — Path, BBox, FontProperties

(asdf:defsystem #:cl-matplotlib-primitives
  :description "Geometry primitives for cl-matplotlib: paths, bboxes, fonts, transforms"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-foundation #:float-features #:trivial-garbage)
  :serial t
  :pathname "src/"
  :components ((:file "packages")
               (:module "primitives"
                :serial t
                :components ((:file "path-algorithms")
                             (:file "path")
                             (:file "transforms")
                             (:file "colors")
                             (:file "colormaps"))))
  :in-order-to ((test-op (test-op #:cl-matplotlib-primitives/tests))))

(asdf:defsystem #:cl-matplotlib-primitives/tests
  :description "Tests for cl-matplotlib-primitives"
  :depends-on (#:cl-matplotlib-primitives #:fiveam)
  :pathname "tests/"
  :components ((:file "test-path")
               (:file "test-transforms")
               (:file "test-colors"))
  :perform (test-op (o c)
             (uiop:symbol-call :fiveam :run!
                               (uiop:find-symbol* :path-tests :cl-matplotlib.primitives.tests))
             (uiop:symbol-call :fiveam :run!
                               (uiop:find-symbol* :transform-tests :cl-matplotlib.primitives.tests))
             (uiop:symbol-call :fiveam :run!
                               (uiop:find-symbol* :color-tests :cl-matplotlib.primitives.tests))))
