;;;; test-show-emacs.lisp — cl-matplotlib-show-emacs tests.
;;;; Runs without Emacs: checks registration, the availability check,
;;;; the generated elisp form, and the error path when no SLIME/SLY
;;;; connection exists.

(defpackage #:cl-matplotlib.tests.show-emacs
  (:use #:cl #:fiveam)
  (:export #:run-show-emacs-tests))

(in-package #:cl-matplotlib.tests.show-emacs)

(def-suite show-emacs-suite :description "cl-matplotlib-show-emacs test suite")
(in-suite show-emacs-suite)

(defun %flatten (tree)
  "All atoms of TREE, in order."
  (cond ((null tree) '())
        ((atom tree) (list tree))
        (t (append (%flatten (car tree)) (%flatten (cdr tree))))))

(test adapter-registered
  (is (typep mpl.show.emacs::*emacs-adapter* 'mpl.show.emacs:emacs-show-adapter))
  (let ((entry (assoc :emacs mpl.show::*adapters*)))
    (is-true entry)
    (is (= 15 (second entry)))
    (is (eq mpl.show.emacs::*emacs-adapter* (funcall (fourth entry))))))

(test unavailable-without-connection
  "With no swank/slynk connection the adapter must not be selected by :auto."
  (if (mpl.show.emacs:emacs-connection-p)
      (skip "an Emacs connection is live in this image")
      (progn
        (is-false (mpl.show.emacs:emacs-connection-p))
        (let ((entry (assoc :emacs mpl.show::*adapters*)))
          (is-false (funcall (third entry)))))))

(test display-form-shape
  "The elisp form carries the SVG text and buffer name, and renders it via image-mode."
  (let* ((svg "<?xml version=\"1.0\"?><svg><text>café</text></svg>")
         (form (mpl.show.emacs::%display-form svg "*plot*"))
         (flat (%flatten form)))
    (is (eq 'let (first form)))
    (is (member svg flat :test #'equal))
    (is (member "*plot*" flat :test #'equal))
    ;; The elisp symbols are interned in the adapter's package; compare by name.
    (flet ((calls-p (name)
             (member name flat :key (lambda (x) (and (symbolp x) (symbol-name x)))
                               :test #'equal)))
      (is-true (calls-p "IMAGE-MODE"))
      (is-true (calls-p "SET-BUFFER-MULTIBYTE"))
      (is-true (calls-p "ENCODE-CODING-STRING"))
      (is-true (calls-p "DISPLAY-BUFFER")))
    ;; Printable with symbols unqualified: swank/slynk's process-form-for-emacs
    ;; downcases symbol names, so Emacs reads (image-mode) from (IMAGE-MODE).
    (let ((text (let ((*package* (find-package '#:cl-matplotlib.show.emacs)))
                  (prin1-to-string form))))
      (is-false (search "::" text))
      (is (search "(IMAGE-MODE)" text)))))

(test show-figure-errors-clearly-without-connection
  (if (mpl.show.emacs:emacs-connection-p)
      (skip "an Emacs connection is live in this image")
      (progn
        (mpl.pyplot:close-figure :all)
        (mpl.pyplot:figure)
        (mpl.pyplot:plot '(1 2 3) '(3 1 2))
        (signals error
          (mpl.show:show-figure mpl.show.emacs::*emacs-adapter* (mpl.pyplot:gcf)))
        (let ((mpl.show:*show-backend* :emacs))
          (signals error (mpl.show:show))))))

(test buffer-name-override
  (let ((a (make-instance 'mpl.show.emacs:emacs-show-adapter :buffer-name "*mine*")))
    (is (equal "*mine*" (mpl.show.emacs:adapter-buffer-name a))))
  (is (null (mpl.show.emacs:adapter-buffer-name mpl.show.emacs::*emacs-adapter*))))

(defun run-show-emacs-tests ()
  "Run all cl-matplotlib-show-emacs tests and report results."
  (let ((results (run 'show-emacs-suite)))
    (explain! results)
    (unless (results-status results)
      (error "show-emacs tests failed!"))))
