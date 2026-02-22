;;;; violin-test.lisp — Example violin plot for visual testing
;;;; Renders a violin plot with 3 datasets

(ql:quickload :cl-matplotlib-pyplot :silent t)

(use-package :cl-matplotlib.pyplot)

;; Generate reproducible data (seeded pseudo-random)
(let ((state (make-random-state nil)))
  (setf *random-state* state))

(let* ((data1 (loop repeat 200
                    collect (+ 50.0d0 (* 10.0d0 (- (random 2.0d0) 1.0d0)))))
       (data2 (loop repeat 200
                    collect (+ 65.0d0 (* 15.0d0 (- (random 2.0d0) 1.0d0)))))
       (data3 (loop repeat 200
                    collect (+ 45.0d0 (* 8.0d0 (- (random 2.0d0) 1.0d0))))))
  (figure :figsize '(8.0d0 6.0d0))
  (violinplot (list data1 data2 data3))
  (title "Violin Plot Example")
  (xlabel "Group")
  (ylabel "Value")
  (savefig "examples/violin-test.png" :dpi 100))

(uiop:quit)
