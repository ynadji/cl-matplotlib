(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)
(use-package :cl-matplotlib.pyplot)

;; Same PRNG as scatter example
(let ((seed 42))
  (defun my-random ()
    (setf seed (mod (+ (* seed 1103515245) 12345) (expt 2 31)))
    (/ (float seed 1.0d0) (float (expt 2 31) 1.0d0))))

(defun randn ()
  (let ((u1 (max 1d-10 (my-random)))
        (u2 (my-random)))
    (* (sqrt (* -2.0d0 (log u1)))
       (cos (* 2.0d0 pi u2)))))

(figure :figsize '(8.0d0 6.0d0))

(let* ((n 200)
       (xs (loop repeat n collect (randn)))
       (ys (loop for x in xs collect (+ (* 0.7d0 x) (* 0.5d0 (randn))))))
  (scatter xs ys :s 25.0 :color "darkorchid" :alpha 0.6 :label "data")
  
  ;; Get figure and axes from pyplot
  (let* ((fig (cl-matplotlib.pyplot:gcf))
         (axes-list (cl-matplotlib.containers:figure-axes fig))
         (ax (first axes-list))
         (trans (cl-matplotlib.containers:axes-base-trans-data ax)))
    (format t "xlim: ~A~%" (cl-matplotlib.containers:axes-get-xlim ax))
    (format t "ylim: ~A~%" (cl-matplotlib.containers:axes-get-ylim ax))
    ;; Transform first 5 data points
    (loop for x in xs for y in ys for i from 0 below 5 do
      (let ((result (cl-matplotlib.primitives:transform-point 
                     trans (list (float x 1.0d0) (float y 1.0d0)))))
        (format t "Point ~D: data=(~,4f, ~,4f) -> pixel=(~,1f, ~,1f)~%"
                i x y (aref result 0) (aref result 1))))))

(uiop:quit)
