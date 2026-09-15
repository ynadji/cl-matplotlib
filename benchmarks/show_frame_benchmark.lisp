;;;; show_frame_benchmark.lisp — interactive frame times.
;;;; Run: ros run -- --load benchmarks/show_frame_benchmark.lisp --quit
;;;; Prints ms per interactive frame (interactor-render-rgba, i.e. what a
;;;; zoom/pan/rotate costs) for a few representative figures.

(require :asdf)
(asdf:load-system :cl-matplotlib-show)

(defun ms (thunk &key (n 10))
  (funcall thunk)                       ; warm up
  (let ((t0 (get-internal-real-time)))
    (dotimes (i n) (funcall thunk))
    (/ (- (get-internal-real-time) t0) (/ internal-time-units-per-second 1000.0) n)))

(defun bench (name build)
  (mpl.pyplot:close-figure :all)
  (funcall build)
  (let ((it (mpl.show:make-interactor (mpl.pyplot:gcf))))
    (format t "~&~24A rgba ~7,1F ms   png ~7,1F ms~%" name
            (ms (lambda () (mpl.show:interactor-render-rgba it)))
            (ms (lambda () (mpl.show:interactor-render-png it))))))

(bench "empty axes" (lambda () (mpl.pyplot:figure)))
(bench "line, title, legend"
       (lambda ()
         (mpl.pyplot:figure)
         (mpl.pyplot:plot (loop for i below 200 collect (/ i 10.0))
                          (loop for i below 200 collect (sin (/ i 10.0))) :label "sin")
         (mpl.pyplot:title "frame timing")
         (mpl.pyplot:legend)))
(bench "scatter 5k"
       (lambda ()
         (mpl.pyplot:figure)
         (let ((s 7))
           (flet ((r () (setf s (mod (+ (* s 1103515245) 12345) (expt 2 31))) (/ s (float (expt 2 31)))))
             (mpl.pyplot:scatter (loop repeat 5000 collect (r)) (loop repeat 5000 collect (r)) :s 9.0)))))
(bench "surface 40x40 (3d)"
       (lambda ()
         (let* ((n 40)
                (x (make-array (list n n) :element-type 'double-float))
                (y (make-array (list n n) :element-type 'double-float))
                (z (make-array (list n n) :element-type 'double-float)))
           (dotimes (i n)
             (dotimes (j n)
               (let* ((xv (- (* 10.0d0 (/ j (1- n))) 5.0d0)) (yv (- (* 10.0d0 (/ i (1- n))) 5.0d0))
                      (r (sqrt (+ (* xv xv) (* yv yv)))))
                 (setf (aref x i j) xv (aref y i j) yv (aref z i j) (if (zerop r) 1d0 (/ (sin r) r))))))
           (mpl.pyplot:subplots 1 1 :projection :3d)
           (mpl.pyplot:plot-surface x y z :cmap "viridis"))))
(uiop:quit)
