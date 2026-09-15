;;;; test-show-emacs.lisp — cl-matplotlib-show-emacs tests.
;;;; Runs without Emacs: checks registration, the availability check,
;;;; the generated elisp form and payloads, and the error path when no
;;;; SLIME/SLY connection exists.

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
  "The elisp form carries the payload and buffer name, and renders it via
image-mode: base64 PNG bytes decoded in Emacs by default, SVG text
inserted as UTF-8 when asked."
  (flet ((calls-p (flat name)
           (member name flat :key (lambda (x) (and (symbolp x) (symbol-name x)))
                             :test #'equal)))
    (let* ((b64 "iVBORw0KGgo=")
           (form (mpl.show.emacs::%display-form b64 "*plot*"))
           (flat (%flatten form)))
      (is (eq 'let (first form)))
      (is (member b64 flat :test #'equal))
      (is (member "*plot*" flat :test #'equal))
      (is-true (calls-p flat "IMAGE-MODE"))
      (is-true (calls-p flat "SET-BUFFER-MULTIBYTE"))
      (is-true (calls-p flat "BASE64-DECODE-STRING"))
      (is-false (calls-p flat "ENCODE-CODING-STRING"))
      (is-true (calls-p flat "DISPLAY-BUFFER"))
      ;; Printable with symbols unqualified: swank/slynk's process-form-for-emacs
      ;; downcases symbol names, so Emacs reads (image-mode) from (IMAGE-MODE).
      (let ((text (let ((*package* (find-package '#:cl-matplotlib.show.emacs)))
                    (prin1-to-string form))))
        (is-false (search "::" text))
        (is (search "(IMAGE-MODE)" text))))
    (let* ((svg "<?xml version=\"1.0\"?><svg><text>café</text></svg>")
           (flat (%flatten (mpl.show.emacs::%display-form svg "*plot*" :format :svg))))
      (is (member svg flat :test #'equal))
      (is-true (calls-p flat "ENCODE-CODING-STRING"))
      (is-false (calls-p flat "BASE64-DECODE-STRING")))))

(test figure-payload-formats
  "The PNG payload is base64 of a PNG file at the requested dpi, and the
figure's own dpi is restored; the SVG payload is the SVG document."
  (mpl.pyplot:close-figure :all)
  (mpl.pyplot:figure :figsize '(2.0d0 1.0d0))
  (mpl.pyplot:plot '(1 2 3) '(3 1 2))
  (let* ((fig (mpl.pyplot:gcf))
         (dpi (mpl.containers:figure-dpi fig))
         (png (cl-base64:base64-string-to-usb8-array
               (mpl.show.emacs::%figure-payload fig :format :png :dpi (* 2 dpi)))))
    ;; PNG signature
    (is (equalp #(137 80 78 71 13 10 26 10) (subseq png 0 8)))
    ;; IHDR width = 2 in × 2·dpi, big-endian at bytes 16..19
    (is (= (* 2 2 dpi) (logior (ash (aref png 16) 24) (ash (aref png 17) 16)
                               (ash (aref png 18) 8) (aref png 19))))
    (is (= dpi (mpl.containers:figure-dpi fig)))
    (let ((svg (mpl.show.emacs::%figure-payload fig :format :svg)))
      (is (stringp svg))
      (is (search "<svg" svg)))))

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
