;;;; simple-line.lisp — A basic line plot
;;;; Run: sbcl --load examples/simple-line.lisp

(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(let ((plt (find-package :cl-matplotlib.pyplot)))
  (flet ((plt (sym &rest args)
           (apply (symbol-function (find-symbol (string-upcase sym) plt)) args)))

    (plt "figure" :figsize '(8.0d0 6.0d0))

    ;; y = x^2
    (let* ((xs (loop for x from -10 to 10 collect (coerce x 'double-float)))
           (ys (mapcar (lambda (x) (* x x)) xs)))
      (plt "plot" xs ys :color "steelblue" :linewidth 2.0 :label "y = x^2"))

    ;; y = 2x + 10
    (let* ((xs (loop for x from -10 to 10 collect (coerce x 'double-float)))
           (ys (mapcar (lambda (x) (+ (* 2.0d0 x) 10.0d0)) xs)))
      (plt "plot" xs ys :color "tomato" :linewidth 2.0
                         :linestyle :dashed :label "y = 2x + 10"))

    (plt "xlabel" "x")
    (plt "ylabel" "y")
    (plt "title" "Simple Line Plot")
    (plt "legend")
    (plt "grid" :visible t)

    (let ((out "examples/simple-line.png"))
      (plt "savefig" out)
      (format t "~&Saved to ~A~%" out))))

(uiop:quit)
