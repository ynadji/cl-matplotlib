;;;; show-web-demo.lisp — start a web show server on a fixed port for
;;;; the integration test (tests/integration/test_show_web.py) or for
;;;; manual browser testing over SSH.
;;;;
;;;; Usage:
;;;;   SHOW_WEB_PORT=8977 SHOW_WEB_NO_BROWSER=1 \
;;;;     ros run -- --load tools/show-web-demo.lisp
;;;;
;;;; Blocks until the browser page (or the test) disconnects.

(ql:quickload :cl-matplotlib-show-web :silent t)

(in-package :cl-user)

(mpl.pyplot:figure)
(mpl.pyplot:plot '(0.0 1.0 2.0 3.0 4.0 5.0 6.0)
                 '(0.0 0.84 0.91 0.14 -0.76 -0.96 -0.28)
                 :label "sin")
(mpl.pyplot:plot '(0.0 1.0 2.0 3.0 4.0 5.0 6.0)
                 '(1.0 0.54 -0.42 -0.99 -0.65 0.28 0.96)
                 :label "cos")
(mpl.pyplot:xlabel "x")
(mpl.pyplot:ylabel "y")
(mpl.pyplot:title "show-web demo")
(mpl.pyplot:legend)

(setf mpl.show:*show-backend* :web)
(format t "~&; demo: blocking until the page disconnects~%")
(mpl.pyplot:show :block t)
(format t "~&; demo: page closed, exiting~%")
(uiop:quit 0)
