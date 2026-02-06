;;;; poc.lisp — Phase 0 Vecto Rendering Proof-of-Concept
;;;; Tests: solid line, dashed line, filled polygon with alpha,
;;;;        clipped region, text labels, embedded raster image
;;;;
;;;; Usage: sbcl --load poc.lisp --eval '(render-poc "/tmp/cl-matplotlib-poc.png")' --quit

(eval-when (:compile-toplevel :load-toplevel :execute)
  (ql:quickload '(:vecto :zpb-ttf :zpng) :silent t))

(defpackage #:cl-matplotlib-poc
  (:use #:cl)
  (:export #:render-poc #:render-dash-test))

(in-package #:cl-matplotlib-poc)

;;; ============================================================
;;; Constants matching the Python reference image layout
;;; ============================================================

(defparameter *width* 640)
(defparameter *height* 480)
(defparameter *font-path* "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf")

;;; ============================================================
;;; Coordinate mapping: matplotlib data coords -> pixel coords
;;; matplotlib axes area: roughly x=[80,580], y=[60,420] in pixels
;;; data range: x=[0,1], y=[0,1]
;;; ============================================================

(defun data-x (x)
  "Map data x [0,1] to pixel x."
  (+ 80.0 (* x 500.0)))

(defun data-y (y)
  "Map data y [0,1] to pixel y.
   Vecto's Y=0 is top, so we invert."
  (- 420.0 (* y 360.0)))

;;; ============================================================
;;; 1. Draw white background
;;; ============================================================

(defun draw-background ()
  "Fill canvas with white background."
  (vecto:set-rgb-fill 1.0 1.0 1.0)
  (vecto:rectangle 0 0 *width* *height*)
  (vecto:fill-path))

;;; ============================================================
;;; 2. Draw axes frame (gray rectangle outline)
;;; ============================================================

(defun draw-axes-frame ()
  "Draw a rectangular axes frame."
  (vecto:set-rgb-stroke 0.0 0.0 0.0)
  (vecto:set-line-width 1.0)
  (vecto:set-dash-pattern #() 0)  ; solid
  (vecto:move-to 80 60)
  (vecto:line-to 580 60)
  (vecto:line-to 580 420)
  (vecto:line-to 80 420)
  (vecto:line-to 80 60)
  (vecto:stroke))

;;; ============================================================
;;; 3. Solid red line: (0,0) -> (1,1) with round caps, width 3
;;; ============================================================

(defun draw-solid-line ()
  "Draw a solid red diagonal line from bottom-left to top-right."
  (vecto:set-rgb-stroke 1.0 0.0 0.0)
  (vecto:set-line-width 3.0)
  (vecto:set-line-cap :round)
  (vecto:set-dash-pattern #() 0)  ; ensure solid line
  (vecto:move-to (data-x 0.0) (data-y 0.0))
  (vecto:line-to (data-x 1.0) (data-y 1.0))
  (vecto:stroke))

;;; ============================================================
;;; 4. Dashed blue line: (0,1) -> (1,0) with width 2
;;; ============================================================

(defun draw-dashed-line ()
  "Draw a dashed blue diagonal line from top-left to bottom-right."
  (vecto:set-rgb-stroke 0.0 0.0 1.0)
  (vecto:set-line-width 2.0)
  (vecto:set-line-cap :butt)
  ;; Dash pattern: 8 on, 4 off (in user-space units)
  (vecto:set-dash-pattern #(8 4) 0)
  (vecto:move-to (data-x 0.0) (data-y 1.0))
  (vecto:line-to (data-x 1.0) (data-y 0.0))
  (vecto:stroke)
  ;; Reset to solid
  (vecto:set-dash-pattern #() 0))

;;; ============================================================
;;; 5. Filled polygon with alpha transparency: green rectangle
;;;    vertices: (0.2,0.2), (0.8,0.2), (0.8,0.8), (0.2,0.8)
;;; ============================================================

(defun draw-filled-polygon ()
  "Draw a semi-transparent green filled rectangle."
  (vecto:set-rgba-fill 0.0 0.5 0.0 0.5)  ; green with alpha=0.5
  (vecto:move-to (data-x 0.2) (data-y 0.2))
  (vecto:line-to (data-x 0.8) (data-y 0.2))
  (vecto:line-to (data-x 0.8) (data-y 0.8))
  (vecto:line-to (data-x 0.2) (data-y 0.8))
  (vecto:line-to (data-x 0.2) (data-y 0.2))
  (vecto:fill-path))

;;; ============================================================
;;; 6. Clipped region: draw a circle clipped to a rectangle
;;; ============================================================

(defun draw-clipped-region ()
  "Draw a yellow circle clipped to a small rectangle.
   This tests Vecto's clip-path capability."
  (vecto:with-graphics-state
    ;; Define clipping rectangle: data coords (0.6,0.6)-(0.95,0.95)
    (vecto:rectangle (data-x 0.6) (data-y 0.95) 
                     (- (data-x 0.95) (data-x 0.6))
                     (- (data-y 0.6) (data-y 0.95)))
    (vecto:clip-path)
    (vecto:end-path-no-op)
    ;; Now draw a large circle centered at (0.75, 0.75) — only
    ;; the part inside the clip rect will appear
    (vecto:set-rgba-fill 1.0 0.8 0.0 0.8)  ; yellow-orange
    (vecto:centered-ellipse-path (data-x 0.75) (data-y 0.75) 80 80)
    (vecto:fill-path)
    ;; Draw circle outline in full (will also be clipped)
    (vecto:set-rgb-stroke 0.8 0.0 0.0)
    (vecto:set-line-width 2.0)
    (vecto:centered-ellipse-path (data-x 0.75) (data-y 0.75) 80 80)
    (vecto:stroke)))

;;; ============================================================
;;; 7. Text label using zpb-ttf via Vecto's font system
;;; ============================================================

(defun draw-text-label ()
  "Draw text label 'Test' at approximately data (0.5, 0.5)."
  (let ((font (vecto:get-font *font-path*)))
    (vecto:set-font font 24)  ; 24pt
    (vecto:set-rgba-fill 0.0 0.0 0.0 1.0)  ; black text
    (vecto:draw-string (data-x 0.42) (data-y 0.52) "Test")))

;;; ============================================================
;;; 8. Embedded raster image (pixel blitting into Vecto canvas)
;;;    Create a small 32x32 checkerboard pattern and blit it
;;; ============================================================

(defun blit-image-to-canvas (image-data canvas-data
                             img-w img-h
                             canvas-w canvas-h
                             dest-x dest-y)
  "Blit an RGBA image (flat array, row-major, 4 bytes/pixel)
   into the Vecto canvas data at position (dest-x, dest-y).
   Simple alpha-over compositing."
  (declare (type (simple-array (unsigned-byte 8) (*)) image-data canvas-data)
           (type fixnum img-w img-h canvas-w canvas-h dest-x dest-y))
  (loop for sy from 0 below img-h
        for dy = (+ dest-y sy)
        when (and (>= dy 0) (< dy canvas-h))
          do (loop for sx from 0 below img-w
                   for dx = (+ dest-x sx)
                   when (and (>= dx 0) (< dx canvas-w))
                     do (let* ((si (* 4 (+ sx (* sy img-w))))
                               (di (* 4 (+ dx (* dy canvas-w))))
                               (sr (aref image-data (+ si 0)))
                               (sg (aref image-data (+ si 1)))
                               (sb (aref image-data (+ si 2)))
                               (sa (aref image-data (+ si 3)))
                               (dr (aref canvas-data (+ di 0)))
                               (dg (aref canvas-data (+ di 1)))
                               (db (aref canvas-data (+ di 2)))
                               (da (aref canvas-data (+ di 3))))
                          ;; Alpha-over compositing (premultiplied)
                          (let* ((a (/ sa 255.0))
                                 (inv-a (- 1.0 a)))
                            (setf (aref canvas-data (+ di 0))
                                  (min 255 (round (+ (* sr a) (* dr inv-a)))))
                            (setf (aref canvas-data (+ di 1))
                                  (min 255 (round (+ (* sg a) (* dg inv-a)))))
                            (setf (aref canvas-data (+ di 2))
                                  (min 255 (round (+ (* sb a) (* db inv-a)))))
                            (setf (aref canvas-data (+ di 3))
                                  (min 255 (round (+ (* sa a) (* da inv-a))))))))))

(defun make-checkerboard (w h cell-size)
  "Create a WxH RGBA checkerboard pattern with given cell size."
  (let ((data (make-array (* w h 4) :element-type '(unsigned-byte 8)
                                     :initial-element 0)))
    (loop for y from 0 below h
          do (loop for x from 0 below w
                   for i = (* 4 (+ x (* y w)))
                   for checker = (logxor (floor x cell-size) (floor y cell-size))
                   do (if (evenp checker)
                          (setf (aref data (+ i 0)) 255   ; magenta
                                (aref data (+ i 1)) 0
                                (aref data (+ i 2)) 255
                                (aref data (+ i 3)) 200)
                          (setf (aref data (+ i 0)) 0     ; cyan
                                (aref data (+ i 1)) 255
                                (aref data (+ i 2)) 255
                                (aref data (+ i 3)) 200))))
    data))

(defun draw-embedded-image (canvas-image)
  "Blit a small checkerboard into the canvas at data position (0.05, 0.7)."
  (let* ((img-w 32)
         (img-h 32)
         (cell-size 8)
         (checker (make-checkerboard img-w img-h cell-size))
         (canvas-data (zpng:image-data canvas-image))
         (dx (round (data-x 0.05)))
         (dy (round (data-y 0.95))))
    (blit-image-to-canvas checker canvas-data
                          img-w img-h
                          *width* *height*
                          dx dy)))

;;; ============================================================
;;; 9. Draw axis labels and title
;;; ============================================================

(defun draw-labels ()
  "Draw axis labels and title."
  (let ((font (vecto:get-font *font-path*)))
    (vecto:set-font font 14)
    (vecto:set-rgba-fill 0.0 0.0 0.0 1.0)
    ;; X-axis label
    (vecto:draw-string 290 445 "X axis")
    ;; Title
    (vecto:set-font font 18)
    (vecto:draw-string 180 40 "cl-matplotlib Phase 0 PoC")))

;;; ============================================================
;;; Main entry point
;;; ============================================================

(defun render-poc (output-path)
  "Render the full proof-of-concept image to OUTPUT-PATH."
  (format t "~&Rendering PoC to ~A ...~%" output-path)
  (vecto:with-canvas (:width *width* :height *height*)
    ;; 1. White background
    (draw-background)
    ;; 2. Axes frame
    (draw-axes-frame)
    ;; 3. Solid red line (round caps, width=3)
    (draw-solid-line)
    ;; 4. Dashed blue line (width=2)
    (draw-dashed-line)
    ;; 5. Filled polygon with alpha
    (draw-filled-polygon)
    ;; 6. Clipped region
    (draw-clipped-region)
    ;; 7. Text label
    (draw-text-label)
    ;; 8. Embedded raster image (pixel blit)
    (draw-embedded-image (vecto::image vecto::*graphics-state*))
    ;; 9. Labels/title
    (draw-labels)
    ;; Save
    (vecto:save-png output-path))
  (format t "~&PoC rendered successfully to ~A~%" output-path)
  output-path)

;;; Also generate a separate dash-test image for evidence
(defun render-dash-test (output-path)
  "Render a dedicated dash pattern test image."
  (format t "~&Rendering dash test to ~A ...~%" output-path)
  (vecto:with-canvas (:width 400 :height 300)
    ;; White background
    (vecto:set-rgb-fill 1.0 1.0 1.0)
    (vecto:rectangle 0 0 400 300)
    (vecto:fill-path)
    
    ;; Title
    (let ((font (vecto:get-font *font-path*)))
      (vecto:set-font font 16)
      (vecto:set-rgba-fill 0.0 0.0 0.0 1.0)
      (vecto:draw-string 100 25 "Dash Pattern Tests"))
    
    ;; Test 1: Solid line
    (vecto:set-rgb-stroke 0.0 0.0 0.0)
    (vecto:set-line-width 3.0)
    (vecto:set-dash-pattern #() 0)
    (vecto:move-to 50 60)
    (vecto:line-to 350 60)
    (vecto:stroke)
    
    ;; Test 2: Simple dash (10 on, 5 off)
    (vecto:set-rgb-stroke 1.0 0.0 0.0)
    (vecto:set-line-width 3.0)
    (vecto:set-dash-pattern #(10 5) 0)
    (vecto:move-to 50 100)
    (vecto:line-to 350 100)
    (vecto:stroke)
    
    ;; Test 3: Dash-dot (10 on, 3 off, 2 on, 3 off)
    (vecto:set-rgb-stroke 0.0 0.0 1.0)
    (vecto:set-line-width 3.0)
    (vecto:set-dash-pattern #(10 3 2 3) 0)
    (vecto:move-to 50 140)
    (vecto:line-to 350 140)
    (vecto:stroke)
    
    ;; Test 4: Fine dots (2 on, 4 off)
    (vecto:set-rgb-stroke 0.0 0.6 0.0)
    (vecto:set-line-width 3.0)
    (vecto:set-line-cap :round)
    (vecto:set-dash-pattern #(2 6) 0)
    (vecto:move-to 50 180)
    (vecto:line-to 350 180)
    (vecto:stroke)
    
    ;; Test 5: Long dash with phase offset
    (vecto:set-rgb-stroke 0.5 0.0 0.5)
    (vecto:set-line-width 3.0)
    (vecto:set-line-cap :butt)
    (vecto:set-dash-pattern #(15 5) 7)  ; phase offset of 7
    (vecto:move-to 50 220)
    (vecto:line-to 350 220)
    (vecto:stroke)
    
    ;; Test 6: Dashed diagonal with round join
    (vecto:set-rgb-stroke 0.8 0.4 0.0)
    (vecto:set-line-width 4.0)
    (vecto:set-line-join :round)
    (vecto:set-dash-pattern #(8 4) 0)
    (vecto:move-to 50 250)
    (vecto:line-to 200 270)
    (vecto:line-to 350 250)
    (vecto:stroke)
    
    ;; Reset
    (vecto:set-dash-pattern #() 0)
    
    ;; Labels
    (let ((font (vecto:get-font *font-path*)))
      (vecto:set-font font 10)
      (vecto:set-rgba-fill 0.3 0.3 0.3 1.0)
      (vecto:draw-string 5 56 "solid")
      (vecto:draw-string 5 96 "dash")
      (vecto:draw-string 5 136 "dashdot")
      (vecto:draw-string 5 176 "dotted")
      (vecto:draw-string 5 216 "phase")
      (vecto:draw-string 5 250 "polyline"))
    
    (vecto:save-png output-path))
  (format t "~&Dash test rendered to ~A~%" output-path)
  output-path)
