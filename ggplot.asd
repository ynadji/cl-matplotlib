;;;; ggplot — Grammar of Graphics for Common Lisp on cl-matplotlib

(asdf:defsystem #:ggplot
  :description "Grammar of Graphics (ggplot2/plotnine-style) on top of cl-matplotlib"
  :version "0.1.0"
  :depends-on (#:cl-matplotlib-pyplot #:float-features)
  :serial t
  :pathname "src/ggplot/"
  :components ((:file "packages")
               (:file "utils")
               (:file "protocol")
               (:file "aes")
               (:file "palettes")
               (:file "components")
               (:file "plot")
               (:file "scales")
               (:file "stats")
               (:file "positions")
               (:file "geoms")
               (:file "themes")
               (:file "coords")
               (:file "facets")
               (:file "build")
               (:file "render")
               (:file "ggsave")
               (:file "qplot"))
  :in-order-to ((asdf:test-op (asdf:test-op #:ggplot/tests))))

(asdf:defsystem #:ggplot/tests
  :description "Tests for ggplot"
  :depends-on (#:ggplot #:fiveam)
  :pathname "tests/"
  :components ((:file "test-gg-core"))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call '#:ggplot.tests '#:run-gg-tests)))
