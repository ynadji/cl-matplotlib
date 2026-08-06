;;;; palettes.lisp — color palettes matching plotnine/ggplot2 defaults

(in-package #:ggplot)

;;; ============================================================
;;; HCL (polar CIELUV) -> sRGB
;;; ============================================================
;;; ggplot2's discrete hue palette lives in HCL space: evenly spaced hues
;;; at fixed chroma 100 / luminance 65. Reference: colorspace's polarLUV
;;; with D65 white point. Verified: 3 levels -> #F8766D #00BA38 #619CFF.

(defconstant +wp-x+ 95.047d0)   ; D65 white point
(defconstant +wp-y+ 100.0d0)
(defconstant +wp-z+ 108.883d0)

(defun %hcl-to-srgb (h c l)
  "HCL (hue degrees, chroma, luminance) -> (values r g b) in [0,1]."
  (if (<= l 0.0d0)
      (values 0.0d0 0.0d0 0.0d0)
      (let* ((hr (* h (/ pi 180.0d0)))
             (u (* c (cos hr)))
             (v (* c (sin hr)))
             ;; LUV -> XYZ
             (denom (+ +wp-x+ (* 15.0d0 +wp-y+) (* 3.0d0 +wp-z+)))
             (u0 (/ (* 4.0d0 +wp-x+) denom))
             (v0 (/ (* 9.0d0 +wp-y+) denom))
             (y (* +wp-y+
                   (if (> l 7.999592d0)
                       (expt (/ (+ l 16.0d0) 116.0d0) 3)
                       (/ l 903.3d0))))
             (up (+ (/ u (* 13.0d0 l)) u0))
             (vp (+ (/ v (* 13.0d0 l)) v0))
             (x (* y (/ (* 9.0d0 up) (* 4.0d0 vp))))
             (z (* y (/ (- 12.0d0 (* 3.0d0 up) (* 20.0d0 vp)) (* 4.0d0 vp)))))
        ;; XYZ -> linear sRGB (D65)
        (let* ((x (/ x 100.0d0)) (y (/ y 100.0d0)) (z (/ z 100.0d0))
               (rl (+ (* 3.2404542d0 x) (* -1.5371385d0 y) (* -0.4985314d0 z)))
               (gl (+ (* -0.9692660d0 x) (* 1.8760108d0 y) (* 0.0415560d0 z)))
               (bl (+ (* 0.0556434d0 x) (* -0.2040259d0 y) (* 1.0572252d0 z))))
          (flet ((gamma (v)
                   (let ((v (max 0.0d0 (min 1.0d0 v))))
                     (if (<= v 0.0031308d0)
                         (* 12.92d0 v)
                         (- (* 1.055d0 (expt v (/ 1.0d0 2.4d0))) 0.055d0)))))
            (values (gamma rl) (gamma gl) (gamma bl)))))))

(defun %rgb-to-hex (r g b)
  (format nil "#~2,'0X~2,'0X~2,'0X"
          (round (* 255.0d0 (max 0.0d0 (min 1.0d0 r))))
          (round (* 255.0d0 (max 0.0d0 (min 1.0d0 g))))
          (round (* 255.0d0 (max 0.0d0 (min 1.0d0 b))))))

;;; ============================================================
;;; HLS palette — plotnine's default discrete palette
;;; ============================================================
;;; plotnine (via mizani hue_pal, color_space="hls") spaces hues evenly in
;;; HLS with lightness 0.6, saturation 0.65, first hue offset 0.01.
;;; Verified: 3 levels -> #DB5F57 #57DB5F #5F57DB.

(defun %hls-component (m1 m2 hue)
  (let ((hue (mod hue 1.0d0)))
    (cond ((< hue #.(/ 1.0d0 6.0d0)) (+ m1 (* (- m2 m1) hue 6.0d0)))
          ((< hue 0.5d0) m2)
          ((< hue #.(/ 2.0d0 3.0d0)) (+ m1 (* (- m2 m1) (- #.(/ 2.0d0 3.0d0) hue) 6.0d0)))
          (t m1))))

(defun %hls-to-rgb (h l s)
  (if (zerop s)
      (values l l l)
      (let* ((m2 (if (<= l 0.5d0) (* l (+ 1.0d0 s)) (- (+ l s) (* l s))))
             (m1 (- (* 2.0d0 l) m2)))
        (values (%hls-component m1 m2 (+ h #.(/ 1.0d0 3.0d0)))
                (%hls-component m1 m2 h)
                (%hls-component m1 m2 (- h #.(/ 1.0d0 3.0d0)))))))

(defun hls-palette (n &key (h 0.01d0) (l 0.6d0) (s 0.65d0))
  "plotnine's default discrete color palette: N evenly spaced HLS hues."
  (loop for i from 0 below n
        for hue = (mod (+ (/ (float i 1.0d0) n) h) 1.0d0)
        collect (multiple-value-bind (r g b) (%hls-to-rgb hue l s)
                  (%rgb-to-hex r g b))))

;;; ============================================================
;;; HCL hue palette — ggplot2's default (kept for theming options)
;;; ============================================================

(defun hue-palette (n &key (h-start 15.0d0) (h-end 375.0d0)
                         (chroma 100.0d0) (luminance 65.0d0)
                         (direction 1))
  "ggplot2/plotnine's default discrete color palette: N evenly spaced HCL
hues. When the hue range spans the full circle, the end hue is nudged so
the first and last colors don't coincide."
  (when (< n 1) (return-from hue-palette '()))
  (let* ((h-end (if (< (mod (- h-end h-start) 360.0d0) 1.0d0)
                    (- h-end (/ 360.0d0 n))
                    h-end)))
    (loop for i from 0 below n
          for h = (+ h-start (* direction i (if (= n 1)
                                                0.0d0
                                                (/ (- h-end h-start) (1- n)))))
          collect (multiple-value-bind (r g b)
                      (%hcl-to-srgb (mod h 360.0d0) chroma luminance)
                    (%rgb-to-hex r g b)))))
