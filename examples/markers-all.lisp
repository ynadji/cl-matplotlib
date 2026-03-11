;;;; markers-all.lisp — Grid showing multiple marker types
;;;; Run: sbcl --load examples/markers-all.lisp
(require :asdf)
(asdf:load-system :cl-matplotlib-pyplot)

(defpackage #:example (:use #:cl #:cl-matplotlib.pyplot))
(in-package #:example)

(figure :figsize '(8.0d0 6.0d0))

(let* ((markers '(:circle :square :triangle-up :triangle-down
                  :triangle-left :triangle-right :diamond :pentagon
                  :hexagon :thin-diamond :plus-filled :x-filled
                  :plus :x :star :vline :hline :point))
       (names '("circle" "square" "triangle_up" "triangle_down"
                "triangle_left" "triangle_right" "diamond" "pentagon"
                "hexagon" "thin_diamond" "plus_filled" "x_filled"
                "plus" "x" "star" "vline" "hline" "point"))
       (n (length markers))
       (cols 6)
       (rows (ceiling n cols)))
  (loop for i from 0 below n
        for m in markers
        for name in names
        do (multiple-value-bind (row col) (floor i cols)
             (plot (list col) (list (- rows row 1))
                   :marker m :linewidth 0.0d0
                   :markersize 12.0d0 :markeredgecolor "black" :markeredgewidth 0.5d0
                   :color "steelblue")
             (text (+ col 0.15d0) (coerce (- rows row 1) 'double-float) name
                   :va :center :fontsize 7.0d0))))

(axis :off)

(xlim -0.5d0 8.0d0)
(ylim -0.5d0 3.5d0)
(title "Marker Types")

(savefig "examples/markers-all.png")
(savefig "examples/markers-all.svg")
(savefig "examples/markers-all.pdf")
(format t "~&Saved to examples/markers-all.{png,svg,pdf}~%")

(uiop:quit)
