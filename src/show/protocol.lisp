;;;; protocol.lisp — the show adapter protocol and pyplot hook.
;;;; Display backends (web, SDL2, CAPI) register themselves here at load
;;;; time; (show) resolves the backend and dispatches. pyplot never
;;;; depends on any of this — loading this system sets
;;;; mpl.pyplot:*show-hook*.

(in-package #:cl-matplotlib.show)

(defgeneric show-figure (adapter figure &key block)
  (:documentation "Display FIGURE with ADAPTER. When BLOCK is true,
return only after the user closes the window/page (adapters that cannot
block should document the deviation)."))

(defvar *adapters* '()
  "Registered adapters: list of (name priority available-fn make-fn).")

(defun register-show-adapter (name make-fn &key (available-fn (constantly t))
                                                (priority 0))
  "Register a show adapter under the keyword NAME. MAKE-FN returns the
adapter instance; AVAILABLE-FN says whether the backend can work in this
environment (e.g. SDL2 needs a display); highest PRIORITY wins for
*show-backend* :auto."
  (setf *adapters*
        (cons (list name priority available-fn make-fn)
              (remove name *adapters* :key #'first))))

(defvar *show-backend* :auto
  "Which display backend (show) uses: :auto picks the highest-priority
available registered adapter; a keyword (:web, :sdl2, :capi) forces one;
an adapter instance is used directly.")

(defun %resolve-adapter ()
  "Return the adapter instance selected by *show-backend*: for :auto, the
highest-priority registered adapter whose availability check passes; for
a keyword, that named adapter; otherwise *show-backend* is itself an
adapter instance and is returned as-is. Signals an error when :auto finds
no available backend or a named backend is not registered."
  (cond
    ((eq *show-backend* :auto)
     (let ((live (sort (remove-if-not (lambda (e) (funcall (third e)))
                                      (copy-list *adapters*))
                       #'> :key #'second)))
       (unless live
         (error "No show backend available.~@
                 Load one first, e.g. (ql:quickload :cl-matplotlib-show-web)."))
       (funcall (fourth (first live)))))
    ((keywordp *show-backend*)
     (let ((entry (assoc *show-backend* *adapters*)))
       (unless entry
         (error "Show backend ~S is not registered (loaded backends: ~{~S~^, ~})."
                *show-backend* (mapcar #'first *adapters*)))
       (funcall (fourth entry))))
    (t *show-backend*)))

(defun show (&optional (figure (mpl.pyplot:gcf)) &key block)
  "Display FIGURE (default: the current pyplot figure) with the backend
selected by *show-backend*."
  (show-figure (%resolve-adapter) figure :block block))

;;; Wire pyplot's (show) to us. pyplot itself has no dependency on this
;;; system; the hook is the seam.
(setf mpl.pyplot:*show-hook*
      (lambda (figure &key block) (show figure :block block)))
