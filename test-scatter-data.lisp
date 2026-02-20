(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)
(in-package #:cl-user)

;; Replicate the scatter example PRNG
(let ((seed 42))
  (defun my-random ()
    (setf seed (mod (+ (* seed 1103515245) 12345) (expt 2 31)))
    (/ (float seed 1.0d0) (float (expt 2 31) 1.0d0))))

(defun randn ()
  (let ((u1 (max 1d-10 (my-random)))
        (u2 (my-random)))
    (* (sqrt (* -2.0d0 (log u1)))
       (cos (* 2.0d0 pi u2)))))

(let* ((n 10)
       (xs (loop repeat n collect (randn)))
       (ys (loop for x in xs collect (+ (* 0.7d0 x) (* 0.5d0 (randn))))))
  (format t "First 10 data points:~%")
  (loop for x in xs for y in ys for i from 0 do
    (format t "  ~D: x=~,6f y=~,6f~%" i x y)))

(uiop:quit)
