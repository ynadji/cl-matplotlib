(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)
(use-package :cl-matplotlib.pyplot)

(figure :figsize '(8.0d0 6.0d0))
(let* ((xs (list 1.0d0 2.0d0))
       (ys (list 3.0d0 4.0d0))
       (pc (scatter xs ys :s 25.0 :color "red")))
  (format t "PC type: ~A~%" (type-of pc))
  (format t "PC DPI: ~A~%" (cl-matplotlib.rendering:path-collection-dpi pc))
  (let ((transforms (cl-matplotlib.rendering::collection-get-transforms pc)))
    (format t "Transforms: ~A~%" (if transforms (length transforms) 0))
    (when transforms
      (let* ((tr (first transforms))
             (result (cl-matplotlib.primitives:transform-point tr (list 0.5d0 0.0d0))))
        (format t "Scale test (0.5, 0) -> (~,4f, ~,4f)~%" (aref result 0) (aref result 1))
        (format t "Expected: 0.5 * sqrt(25) * 100/72 = ~,4f~%" (* 0.5d0 (sqrt 25.0d0) (/ 100.0d0 72.0d0)))))))

(uiop:quit)
