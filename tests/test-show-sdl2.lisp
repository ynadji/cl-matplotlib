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

(defun run-show-sdl2-tests ()
  "Run all cl-matplotlib-show-sdl2 tests and report results."
  (let ((results (run 'show-sdl2-suite)))
    (explain! results)
    (unless (results-status results)
      (error "show-sdl2 tests failed!"))))
