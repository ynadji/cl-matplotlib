;;;; test-spectral.lisp — Welch PSD / spectral plot types.
;;;; Numeric expectations verified against matplotlib.mlab.

(defpackage #:cl-matplotlib.tests.spectral
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                #:make-figure #:add-subplot
                #:psd #:csd #:magnitude-spectrum #:specgram)
  (:export #:run-spectral-tests))

(in-package #:cl-matplotlib.tests.spectral)

(def-suite spectral-suite :description "Spectral plot machinery")
(in-suite spectral-suite)

(defun %sine (freq n fs)
  (loop for i from 0 below n
        collect (sin (/ (* 2 pi freq i) fs))))

(test welch-psd-matches-matplotlib
  ;; mlab.psd of a 10 Hz unit sine, NFFT 256, Fs 100:
  ;; peak 0.6911410479672978 at 10.15625 Hz (verified numerically)
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (multiple-value-bind (pxx freqs)
        (psd ax (%sine 10.0d0 1024 100.0d0) :nfft 256 :fs 100.0d0)
      (let* ((peak (reduce #'max pxx))
             (k (position peak pxx)))
        (is (< (abs (- peak 0.6911410479672978d0)) 1d-9))
        (is (< (abs (- (elt freqs k) 10.15625d0)) 1d-9))
        (is (= 129 (length pxx)))))))

(test magnitude-spectrum-matches-matplotlib
  ;; mlab.magnitude_spectrum of a 10 Hz sine over 512 samples:
  ;; peak 0.48728330778116136 at 9.9609375 Hz
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (multiple-value-bind (mags freqs)
        (magnitude-spectrum ax (%sine 10.0d0 512 100.0d0) :fs 100.0d0)
      (let* ((peak (reduce #'max mags))
             (k (position peak mags)))
        (is (< (abs (- peak 0.48728330778116136d0)) 1d-9))
        (is (< (abs (- (elt freqs k) 9.9609375d0)) 1d-9))
        (is (= 257 (length mags)))))))

(test csd-of-identical-signals-is-psd
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1))
         (x (%sine 10.0d0 1024 100.0d0)))
    (multiple-value-bind (pxy) (csd ax x x :nfft 256 :fs 100.0d0)
      ;; auto-spectrum: imaginary parts vanish
      (is (< (reduce #'max pxy :key (lambda (c) (abs (imagpart c))))
             1d-12)))))

(test specgram-smoke
  (let* ((fig (make-figure))
         (ax (add-subplot fig 1 1 1)))
    (finishes (specgram ax (%sine 10.0d0 1024 100.0d0)
                        :nfft 128 :fs 100.0d0 :noverlap 64))))

(defun run-spectral-tests ()
  (let ((results (run 'spectral-suite)))
    (explain! results)
    (unless (results-status results)
      (error "spectral tests failed"))
    results))
