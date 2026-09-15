;;;; show-web-demo.lisp — start a web show server on a fixed port for
;;;; the integration test (tests/integration/test_show_web.py) or for
;;;; manual browser testing over SSH.
;;;;
;;;; Usage:
;;;;   SHOW_WEB_PORT=8977 SHOW_WEB_NO_BROWSER=1 \
;;;;     ros run -- --load tools/show-web-demo.lisp
;;;;
;;;; Shows two figures as tabs of one page: figure 1 (lines) without
;;;; blocking, then figure 2 (scatter) with :block t. Exits when
;;;; figure 2's tab is closed or the last page disconnects.

(ql:quickload :cl-matplotlib-show-web :silent t)

(in-package :cl-user)

(setf mpl.show:*show-backend* :web)

;;; figure 1 — lines
(mpl.pyplot:figure)
(mpl.pyplot:plot '(0.0 1.0 2.0 3.0 4.0 5.0 6.0)
                 '(0.0 0.84 0.91 0.14 -0.76 -0.96 -0.28)
                 :label "sin")
(mpl.pyplot:plot '(0.0 1.0 2.0 3.0 4.0 5.0 6.0)
                 '(1.0 0.54 -0.42 -0.99 -0.65 0.28 0.96)
                 :label "cos")
(mpl.pyplot:plot '(0.0 6.0) '(0.0 0.0) :label "zero" :color "gray")   ; a line at a known pixel row for the pick test
(mpl.pyplot:xlabel "x")
(mpl.pyplot:ylabel "y")
(mpl.pyplot:title "show-web demo")
(mpl.pyplot:legend)
(mpl.pyplot:show)

;;; figure 2 — scatter, the blocking one
(mpl.pyplot:figure)
(mpl.pyplot:scatter '(1.0 2.0 3.0 4.0 5.0) '(5.0 3.0 4.0 1.0 2.0) :label "points")
(mpl.pyplot:title "second figure")
(mpl.pyplot:legend)

(format t "~&; demo: blocking until figure 2 is closed~%")
(mpl.pyplot:show :block t)
(format t "~&; demo: figure 2 closed, exiting~%")
(mpl.show.web:stop-server)
(uiop:quit 0)
