;;;; spectral.lisp — spectral plot types: psd, csd, specgram,
;;;; magnitude-spectrum. FFT via bordeaux-fft; algorithms and
;;;; normalization mirror matplotlib.mlab's _spectral_helper (Welch).

(in-package #:cl-matplotlib.containers)

(defun %hann-window (n)
  "Hann window of length N (matplotlib window_hanning)."
  (let ((w (make-array n :element-type 'double-float)))
    (dotimes (i n w)
      (setf (aref w i)
            (* 0.5d0 (- 1.0d0 (cos (/ (* 2.0d0 pi i) (1- n)))))))))

(defun %segment-fft (x start nfft window)
  "Complex FFT of the windowed segment X[START, START+NFFT)."
  (let ((buf (make-array nfft :element-type '(complex double-float))))
    (dotimes (i nfft)
      (setf (aref buf i)
            (complex (* (float (elt x (+ start i)) 1.0d0) (aref window i))
                     0.0d0)))
    (bordeaux-fft:fft buf)))

(defun %welch-spectra (x y &key (nfft 256) (fs 2.0d0) (noverlap 0))
  "Welch cross-spectral density of X and Y (identical for auto-PSD when
X eq Y). Returns (values pxy freqs) with matplotlib's normalization:
1/(Fs * sum(win^2)), one-sided with all bins except DC/Nyquist doubled.
PXY is a vector of complex numbers (real for auto-spectra)."
  (let* ((n (length x))
         (window (%hann-window nfft))
         (win-norm (loop for i from 0 below nfft
                         sum (expt (aref window i) 2)))
         (step (- nfft noverlap))
         (nseg (max 1 (1+ (floor (- n nfft) step))))
         (nfreq (1+ (floor nfft 2)))
         (acc (make-array nfreq :initial-element #c(0.0d0 0.0d0))))
    (dotimes (seg nseg)
      (let* ((start (* seg step))
             (fx (%segment-fft x start nfft window))
             (fy (if (eq x y) fx (%segment-fft y start nfft window))))
        (dotimes (k nfreq)
          (incf (aref acc k)
                (* (conjugate (aref fx k)) (aref fy k))))))
    (let ((scale (/ 1.0d0 (* (float fs 1.0d0) win-norm nseg))))
      (dotimes (k nfreq)
        (let ((doubled (if (or (zerop k)
                               (and (evenp nfft) (= k (floor nfft 2))))
                           1.0d0
                           2.0d0)))
          (setf (aref acc k) (* (aref acc k) scale doubled)))))
    (values acc
            (loop for k from 0 below nfreq
                  collect (/ (* k (float fs 1.0d0)) nfft)))))

(defun %psd-y-ticks (ax db)
  "matplotlib ax.psd tick recipe: from the MARGINED view bounds
(data +/- 5%), fixed dB ticks every max(10*int(log10(range)), 1)
starting at floor(vmin); the final view pins the bottom to the first
tick and keeps the margined top."
  (let* ((dmin (reduce #'min db))
         (dmax (reduce #'max db))
         (margin (* 0.05d0 (max (- dmax dmin) 1d-12)))
         (vmin (- dmin margin))
         (vmax (+ dmax margin))
         (step (max (* 10 (truncate (log (max (- vmax vmin) 1d-12) 10))) 1))
         (ticks (loop for tick from (floor vmin) below (+ (ceiling vmax) 1)
                      by step
                      collect (float tick 1.0d0))))
    (axes-set-yticks ax ticks)
    (axes-set-ylim ax :min (min (first ticks) vmin) :max vmax)))

(defun psd (ax x &key (nfft 256) (fs 2.0d0) (noverlap 0)
                      (color nil) (linewidth 1.5) (label "") (zorder 2))
  "Power spectral density via Welch's method, plotted as 10 log10(Pxx)
with matplotlib's axis labels and grid.

Returns (values pxx freqs line)."
  (multiple-value-bind (pxy freqs)
      (%welch-spectra x x :nfft nfft :fs fs :noverlap noverlap)
    (let* ((pxx (map 'list (lambda (c) (realpart c)) pxy))
           (db (mapcar (lambda (p) (* 10.0d0 (log (max p 1d-300) 10.0d0)))
                       pxx))
           (lines (plot ax freqs db :color color :linewidth linewidth
                                    :label label :zorder zorder)))
      (axis-set-label-text (axes-base-xaxis ax) "Frequency")
      (axis-set-label-text (axes-base-yaxis ax) "Power Spectral Density (dB/Hz)")
      (axes-grid-toggle ax :visible t)
      (%psd-y-ticks ax db)
      (values pxx freqs (first lines)))))

(defun csd (ax x y &key (nfft 256) (fs 2.0d0) (noverlap 0)
                        (color nil) (linewidth 1.5) (label "") (zorder 2))
  "Cross spectral density magnitude of X and Y (10 log10 |Pxy|).

Returns (values pxy freqs line)."
  (multiple-value-bind (pxy freqs)
      (%welch-spectra x y :nfft nfft :fs fs :noverlap noverlap)
    (let* ((db (map 'list (lambda (c)
                            (* 10.0d0 (log (max (abs c) 1d-300) 10.0d0)))
                    pxy))
           (lines (plot ax freqs db :color color :linewidth linewidth
                                    :label label :zorder zorder)))
      (axis-set-label-text (axes-base-xaxis ax) "Frequency")
      (axis-set-label-text (axes-base-yaxis ax) "Cross Spectrum Magnitude (dB)")
      (axes-grid-toggle ax :visible t)
      (%psd-y-ticks ax (coerce db 'list))
      (values pxy freqs (first lines)))))

(defun magnitude-spectrum (ax x &key (fs 2.0d0) (color nil) (linewidth 1.5)
                                     (label "") (zorder 2))
  "Magnitude spectrum of a single windowed FFT over all of X
(matplotlib: |FFT(hann*x)| / sum(hann), one-sided, no doubling).

Returns (values magnitudes freqs line)."
  (let* ((n (length x))
         (window (%hann-window n))
         (win-sum (loop for i from 0 below n sum (aref window i)))
         (fx (%segment-fft x 0 n window))
         (nfreq (1+ (floor n 2)))
         (mags (loop for k from 0 below nfreq
                     collect (/ (abs (aref fx k)) win-sum)))
         (freqs (loop for k from 0 below nfreq
                      collect (/ (* k (float fs 1.0d0)) n)))
         (lines (plot ax freqs mags :color color :linewidth linewidth
                                    :label label :zorder zorder)))
    (axis-set-label-text (axes-base-xaxis ax) "Frequency")
    (axis-set-label-text (axes-base-yaxis ax) "Magnitude (energy)")
    (values mags freqs (first lines))))

(defun specgram (ax x &key (nfft 256) (fs 2.0d0) (noverlap 128) (cmap nil)
                           (vmin nil) (vmax nil))
  "Spectrogram: per-segment PSD columns displayed as an image with
time/frequency extent (matplotlib specgram).

Returns the image artist."
  (let* ((n (length x))
         (window (%hann-window nfft))
         (win-norm (loop for i from 0 below nfft
                         sum (expt (aref window i) 2)))
         (step (- nfft noverlap))
         (nseg (max 1 (1+ (floor (- n nfft) step))))
         (nfreq (1+ (floor nfft 2)))
         (z (make-array (list nfreq nseg) :element-type 'double-float))
         (scale (/ 1.0d0 (* (float fs 1.0d0) win-norm))))
    (dotimes (seg nseg)
      (let ((fx (%segment-fft x (* seg step) nfft window)))
        (dotimes (k nfreq)
          (let* ((doubled (if (or (zerop k)
                                  (and (evenp nfft) (= k (floor nfft 2))))
                              1.0d0
                              2.0d0))
                 (p (* (expt (abs (aref fx k)) 2) scale doubled)))
            ;; rows top-down: highest frequency first (origin :upper)
            (setf (aref z (- nfreq 1 k) seg)
                  (* 10.0d0 (log (max p 1d-300) 10.0d0)))))))
    (let* ((t0 (/ (* 0.5d0 nfft) (float fs 1.0d0)))
           (t1 (+ t0 (/ (* (1- nseg) step) (float fs 1.0d0))))
           (im (imshow ax z :cmap cmap :vmin vmin :vmax vmax
                            :origin :upper :aspect :auto
                            :extent (list t0 t1 0.0d0
                                          (/ (float fs 1.0d0) 2.0d0)))))
      (axis-set-label-text (axes-base-xaxis ax) "Time")
      (axis-set-label-text (axes-base-yaxis ax) "Frequency")
      im)))
