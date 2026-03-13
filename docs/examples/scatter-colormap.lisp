;;;; scatter-colormap.lisp — Scatter plot with colormap-mapped values
;;;; Run: sbcl --load examples/scatter-colormap.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 5.0d0))

;; Deterministic data — identical math in both Python and CL
(let* ((n 150)
       (x (loop for i from 0 below n collect (+ (* (sin (* i 0.1d0)) 50.0d0) 50.0d0)))
       (y (loop for i from 0 below n collect (+ (* (cos (* i 0.13d0)) 50.0d0) 50.0d0)))
       (colors-val (loop for i from 0 below n collect (+ (* (sin (* i 0.05d0)) 0.5d0) 0.5d0)))
       (sizes (loop for i from 0 below n collect (+ (* (+ (sin (* i 0.07d0)) 1.0d0) 100.0d0) 20.0d0)))
       ;; Compute explicit hex colors (viridis-like gradient: blue->green->yellow)
       ;; Same deterministic RGB formula as Python reference
       (colors-hex (loop for c in colors-val
                         collect (format nil "#~2,'0X~2,'0X~2,'0X"
                                         (floor (+ 68 (* c 120)))
                                         (floor (+ 1 (* c 180)))
                                         (floor (+ 84 (* (- 1 c) 160)))))))
  ;; Debug: print first 5 values
  (format t "~&x[:5]  = ~{~A~^, ~}~%" (subseq x 0 5))
  (format t "~&y[:5]  = ~{~A~^, ~}~%" (subseq y 0 5))
  (format t "~&c[:5]  = ~{~A~^, ~}~%" (subseq colors-hex 0 5))
  (format t "~&s[:5]  = ~{~A~^, ~}~%" (subseq sizes 0 5))
  (scatter x y :c colors-hex :s sizes :alpha 0.8d0))

(xlabel "X")
(ylabel "Y")
(title "Scatter with Colormap")

(savefig "examples/scatter-colormap.png")
(savefig "examples/scatter-colormap.svg")
(savefig "examples/scatter-colormap.pdf")
(format t "~&Saved to examples/scatter-colormap.{png,svg,pdf}~%")

(uiop:quit)
