;;;; test-show-sdl2.lisp — cl-matplotlib-show-sdl2 smoke test.
;;;; Needs a video driver: headless runs use SDL_VIDEODRIVER=dummy
;;;; (skipped with a warning when no driver is available). Exercises
;;;; init → window → renderer → streaming texture in the adapter's
;;;; format → upload of a real interactor frame → teardown.

(defpackage #:cl-matplotlib.tests.show-sdl2
  (:use #:cl #:fiveam)
  (:export #:run-show-sdl2-tests))

(in-package #:cl-matplotlib.tests.show-sdl2)

(def-suite show-sdl2-suite :description "cl-matplotlib-show-sdl2 test suite")
(in-suite show-sdl2-suite)

(defun %video-available-p ()
  (flet ((set-p (name)
           (let ((v (uiop:getenv name)))
             (and v (plusp (length v))))))
    (or (set-p "DISPLAY") (set-p "WAYLAND_DISPLAY") (set-p "SDL_VIDEODRIVER"))))

(test adapter-registered
  (is (typep mpl.show.sdl2::*sdl2-adapter* 'mpl.show.sdl2:sdl2-show-adapter))
  (is (assoc :sdl2 mpl.show::*adapters*)))

(test smoke-window-texture-upload
  (if (not (%video-available-p))
      (skip "no video driver (set SDL_VIDEODRIVER=dummy for headless runs)")
      (progn
        (mpl.pyplot:close-figure :all)
        (mpl.pyplot:figure)
        (mpl.pyplot:plot '(1 2 3 4) '(1 4 2 3))
        (let ((it (mpl.show:make-interactor (mpl.pyplot:gcf))))
          (multiple-value-bind (rgba w h) (mpl.show:interactor-render-rgba it)
            (finishes
              (sdl2:with-init (:video)
                (sdl2:with-window (win :title "smoke" :w w :h h
                                       :flags '(:hidden))
                  (sdl2:with-renderer (renderer win)
                    (let ((texture (sdl2:create-texture
                                    renderer mpl.show.sdl2::+texture-format+
                                    :streaming w h))
                          (fbuf (cffi:foreign-alloc :uint8 :count (* 4 w h))))
                      (unwind-protect
                           (progn
                             (mpl.show.sdl2::%upload-frame texture fbuf rgba w)
                             (sdl2:render-copy renderer texture)
                             (sdl2:render-present renderer))
                        (cffi:foreign-free fbuf)
                        (sdl2:destroy-texture texture)))))))
            ;; zoom + re-render still works after the SDL session
            (mpl.show:interactor-zoom it (floor w 2) (floor h 2) 1.5d0)
            (multiple-value-bind (rgba2 w2 h2) (mpl.show:interactor-render-rgba it)
              (is (= w w2))
              (is (= h h2))
              (is (not (equalp rgba rgba2)))))))))

;;; The multi-window loop, headless: windows mirror the window manager.

(defun %wait-until (fn &key (timeout 20))
  (let ((deadline (+ (get-internal-real-time) (* timeout internal-time-units-per-second))))
    (loop until (or (funcall fn) (> (get-internal-real-time) deadline))
          do (sleep 0.05))
    (funcall fn)))

(defun %view-count ()
  (hash-table-count mpl.show.sdl2::*views*))

(test multi-window-loop-mirrors-window-manager
  (if (not (%video-available-p))
      (skip "no video driver (set SDL_VIDEODRIVER=dummy for headless runs)")
      (let ((adapter mpl.show.sdl2::*sdl2-adapter*))
        (mpl.show:wm-close-all)
        (mpl.pyplot:close-figure :all)
        (is-true (%wait-until (lambda () (not (mpl.show.sdl2:loop-running-p)))))
        (let ((f1 (mpl.pyplot:figure)))
          (mpl.pyplot:plot '(1 2 3 4) '(1 4 2 3))
          ;; first non-blocking show starts the loop on a worker with one window
          (let ((w1 (mpl.show:show-figure adapter f1)))
            (is (typep w1 'mpl.show:figure-window))
            (is-true (%wait-until (lambda () (= 1 (%view-count)))))
            (is (mpl.show.sdl2:loop-running-p))
            ;; a second figure shown while the loop runs gets its own window
            (let ((f2 (mpl.pyplot:figure)))
              (mpl.pyplot:plot '(1 2 3) '(3 2 1))
              (mpl.show:show-figure adapter f2)
              (is-true (%wait-until (lambda () (= 2 (%view-count)))))
              (is (eq (mpl.show:wm-window-for-figure f2) (mpl.show:wm-active-window)))
              ;; pyplot's close-figure closes the current figure's window
              (mpl.pyplot:close-figure)
              (is-true (%wait-until (lambda () (= 1 (%view-count)))))
              (is (null (mpl.show:wm-window-for-figure f2)))
              ;; a repl edit + notify-changed is picked up without error
              (mpl.pyplot:plot '(1 2 3 4) '(2 2 2 2))
              (mpl.show:wm-notify-changed f1)
              (sleep 0.3)
              (is (= 1 (%view-count)))
              ;; closing the last window stops the loop
              (mpl.show:wm-close-all)
              (is-true (%wait-until (lambda () (not (mpl.show.sdl2:loop-running-p)))))
              (is (= 0 (%view-count)))))))))

(test blocking-show-returns-when-its-window-closes
  (if (not (%video-available-p))
      (skip "no video driver (set SDL_VIDEODRIVER=dummy for headless runs)")
      (let ((adapter mpl.show.sdl2::*sdl2-adapter*))
        (mpl.show:wm-close-all)
        (mpl.pyplot:close-figure :all)
        (is-true (%wait-until (lambda () (not (mpl.show.sdl2:loop-running-p)))))
        (let* ((fig (mpl.pyplot:figure))
               (done nil)
               (thread (bt:make-thread
                        (lambda ()
                          (mpl.show:show-figure adapter fig :block t)
                          (setf done t)))))
          (mpl.pyplot:plot '(1 2 3) '(1 2 3))
          (is-true (%wait-until (lambda () (= 1 (%view-count)))))
          (is (mpl.show.sdl2:loop-running-p))
          (is (null done))
          (mpl.show:wm-close (mpl.show:figure-window-id (mpl.show:wm-window-for-figure fig)))
          (bt:join-thread thread)
          (is (eq t done))
          (is-true (%wait-until (lambda () (not (mpl.show.sdl2:loop-running-p)))))
          (mpl.pyplot:close-figure :all)))))

(defun run-show-sdl2-tests ()
  "Run all cl-matplotlib-show-sdl2 tests and report results."
  (let ((results (run 'show-sdl2-suite)))
    (explain! results)
    (unless (results-status results)
      (error "show-sdl2 tests failed!"))))
