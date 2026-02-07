;;;; cl-matplotlib-containers — Figure, Axes, layout engines
;;;; Phase 4a: Figure, FigureCanvas, savefig pipeline, layout engines
;;;; Phase 4b: Axes with plot, scatter, bar — MVP complete

(asdf:defsystem #:cl-matplotlib-containers
  :description "Container hierarchy for cl-matplotlib: Figure, Axes, layout engines"
  :version "0.2.0"
  :depends-on (#:cl-matplotlib-backends)
  :serial t
  :components ((:module "src/containers"
                :components ((:file "layout-engine")
                             (:file "figure")
                             (:file "ticker")
                             (:file "scale")
                             (:file "spines")
                             (:file "axis")
                             (:file "axes-base")
                             (:file "axes")
                             (:file "legend-handler")
                             (:file "legend")
                             (:file "colorbar")
                             (:file "gridspec")))
               (:module "src/algorithms"
                :components ((:file "marching-squares")))
                (:module "src/plotting"
                 :components ((:file "contour")
                              (:file "image"))))
  :in-order-to ((asdf:test-op (asdf:test-op #:cl-matplotlib-containers/tests))))

(asdf:defsystem #:cl-matplotlib-containers/tests
  :description "Tests for cl-matplotlib-containers"
  :depends-on (#:cl-matplotlib-containers #:fiveam)
  :pathname "tests/"
  :components ((:file "test-figure")
               (:file "test-axes")
               (:file "test-axis")
               (:file "test-scale")
               (:file "test-legend")
               (:file "test-colorbar")
               (:file "test-gridspec")
                (:file "test-contour")
                (:file "test-image"))
   :perform (asdf:test-op (o c)
                (uiop:symbol-call '#:cl-matplotlib.tests.figure '#:run-figure-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.axes '#:run-axes-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.axis '#:run-axis-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.scale '#:run-scale-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.legend '#:run-legend-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.colorbar '#:run-colorbar-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.gridspec '#:run-gridspec-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.contour '#:run-contour-tests)
                (uiop:symbol-call '#:cl-matplotlib.tests.image '#:run-image-tests)))
