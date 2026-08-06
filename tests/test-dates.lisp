;;;; test-dates.lisp — date conversions, calendar locators, formatters.
;;;; Expected strings verified against matplotlib.dates (AutoDateLocator +
;;;; ConciseDateFormatter) on the same tick sets.

(defpackage #:cl-matplotlib.tests.dates
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.containers
                #:ut-to-num #:num-to-ut #:date-to-num #:num-to-date
                #:format-date #:date-break-uts #:auto-date-spec
                #:date-locator #:auto-date-locator #:month-locator
                #:locator-tick-values
                #:date-formatter #:concise-date-formatter
                #:tick-formatter-call #:tick-formatter-format-ticks
                #:tick-formatter-offset-string
                #:find-unit-converter #:make-scale)
  (:export #:run-dates-tests))

(in-package #:cl-matplotlib.tests.dates)

(def-suite dates-suite :description "Date axis machinery")
(in-suite dates-suite)

(defun ut (y m d &optional (hh 0) (mm 0) (ss 0))
  (encode-universal-time ss mm hh d m y 0))

(test epoch-parity-with-matplotlib
  ;; matplotlib date2num: 1970-01-01 -> 0.0, 2024-03-15 -> 19797.0
  (is (= 0.0d0 (ut-to-num (ut 1970 1 1))))
  (is (= 19797.0d0 (ut-to-num (ut 2024 3 15))))
  (is (= (ut 2024 3 15) (num-to-ut 19797.0d0))))

(test local-time-round-trip
  (let* ((ts (local-time:encode-timestamp 0 0 30 12 15 3 2024
                                          :timezone local-time:+utc-zone+))
         (num (date-to-num ts)))
    (is (< (abs (- num (+ 19797.0d0 (/ 12.5d0 24)))) 1d-9))
    (is (local-time:timestamp= ts (num-to-date num)))))

(test format-date-directives
  (let ((v (ut 2024 3 7 9 5 3)))
    (is (string= "2024-03-07" (format-date v "%Y-%m-%d")))
    (is (string= "Mar 7" (format-date v "%b %e")))
    (is (string= "March 24" (format-date v "%B %y")))
    (is (string= "09:05:03" (format-date v "%H:%M:%S")))))

(test calendar-break-anchoring
  ;; month breaks anchor at the first month-start at/after lo
  (is (equal (list (ut 2022 12 1) (ut 2023 6 1) (ut 2023 12 1)
                   (ut 2024 6 1) (ut 2024 12 1))
             (date-break-uts (ut 2022 11 25) (ut 2024 12 15) '(:month 6))))
  ;; hour breaks anchor on the step grid within the day
  (is (equal (list (ut 2024 3 15 6) (ut 2024 3 15 12) (ut 2024 3 15 18))
             (date-break-uts (ut 2024 3 15 1) (ut 2024 3 15 23) '(:hour 6)))))

(test auto-spec-boundaries
  (is (equal '(:year 1) (auto-date-spec 2000)))
  (is (equal '(:month 1) (auto-date-spec 90)))
  (is (equal '(:day 1) (auto-date-spec 7)))
  (is (equal '(:hour 6) (auto-date-spec 0.9)))
  (is (equal '(:minute 15) (auto-date-spec (/ 2.0 24)))))

(test date-locator-tick-values
  (let* ((loc (month-locator 1))
         (ticks (locator-tick-values loc
                                     (ut-to-num (ut 2024 1 15))
                                     (ut-to-num (ut 2024 4 15)))))
    (is (equal (mapcar #'ut-to-num
                       (list (ut 2024 2 1) (ut 2024 3 1) (ut 2024 4 1)))
               ticks))))

(test concise-formatter-matches-matplotlib
  (let ((fmt (make-instance 'concise-date-formatter)))
    ;; monthly ticks over one year: first tick shows the year, no offset
    (let ((labels (tick-formatter-format-ticks
                   fmt (loop for m from 1 to 12
                             collect (ut-to-num (ut 2024 m 1))))))
      (is (equal '("2024" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug"
                   "Sep" "Oct" "Nov" "Dec")
                 labels))
      (is (null (tick-formatter-offset-string fmt))))
    ;; days within one month: day-1 tick shows the month, offset year-month
    (let ((labels (tick-formatter-format-ticks
                   fmt (loop for d from 1 to 13 by 2
                             collect (ut-to-num (ut 2024 3 d))))))
      (is (equal '("Mar" "03" "05" "07" "09" "11" "13") labels))
      (is (string= "2024-Mar" (tick-formatter-offset-string fmt))))
    ;; hours within one day: midnight shows the date, offset full date
    (let ((labels (tick-formatter-format-ticks
                   fmt (loop for h from 0 to 18 by 6
                             collect (ut-to-num (ut 2024 3 15 h))))))
      (is (equal '("Mar-15" "06:00" "12:00" "18:00") labels))
      (is (string= "2024-Mar-15" (tick-formatter-offset-string fmt))))))

(test date-formatter-fixed
  (let ((fmt (make-instance 'date-formatter :fmt "%b %d")))
    (is (string= "Mar 15" (tick-formatter-call
                           fmt (ut-to-num (ut 2024 3 15)))))))

(test unit-converter-registry
  (let ((ts (local-time:encode-timestamp 0 0 0 0 15 3 2024
                                         :timezone local-time:+utc-zone+)))
    (is (not (null (find-unit-converter ts))))
    (is (null (find-unit-converter 42)))
    (is (null (find-unit-converter "hello")))))

(test date-scale-installs-machinery
  (let ((scale (make-scale :date)))
    (is (typep scale 'cl-matplotlib.containers::date-scale))))

(test timestamps-plot-directly
  ;; end-to-end: local-time timestamps straight into plot(); the unit
  ;; converter should switch the x axis to the date scale
  (let* ((fig (cl-matplotlib.containers:make-figure))
         (ax (cl-matplotlib.containers:add-subplot fig 1 1 1))
         (dates (loop for m from 1 to 12
                      collect (local-time:encode-timestamp
                               0 0 0 0 1 m 2024
                               :timezone local-time:+utc-zone+)))
         (vals (loop for i from 0 below 12 collect (+ 10.0d0 (sin i)))))
    (finishes (cl-matplotlib.containers:plot ax dates vals))
    (is (string= "date"
                 (cl-matplotlib.containers::scale-name
                  (cl-matplotlib.containers::axis-scale
                   (cl-matplotlib.containers:axes-base-xaxis ax)))))
    (let ((path (format nil "/tmp/date-plot-test-~D.png" (get-universal-time))))
      (finishes (cl-matplotlib.containers:savefig fig path))
      (is-true (probe-file path))
      (when (probe-file path) (delete-file path)))))

(defun run-dates-tests ()
  (let ((results (run 'dates-suite)))
    (explain! results)
    (unless (results-status results)
      (error "dates tests failed"))
    results))
