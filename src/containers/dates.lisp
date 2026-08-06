;;;; dates.lisp — date handling for axes: conversions, calendar-aware
;;;; locators, strftime-style formatters, and the unit-converter registry.
;;;;
;;;; Axis representation: double-float DAYS SINCE 1970-01-01T00:00:00 UTC,
;;;; matplotlib's (>= 3.3) date2num epoch, so locator/formatter behavior
;;;; can be verified numerically against matplotlib. All calendar math is
;;;; done in Common Lisp universal time at GMT (host timezone independent).
;;;;
;;;; The calendar-break engine originated in the ggplot layer
;;;; (src/ggplot/scales.lisp) and was lifted here so both layers share it;
;;;; gg re-imports these functions.

(in-package #:cl-matplotlib.containers)

(defconstant +seconds-per-day+ 86400)

(defconstant +unix-epoch-ut+ 2208988800
  "Universal time of 1970-01-01T00:00:00 UTC.")

;;; ============================================================
;;; Conversions
;;; ============================================================

(defun ut-to-num (ut)
  "Universal time -> axis number (days since the 1970 epoch)."
  (/ (- (float ut 1.0d0) +unix-epoch-ut+) +seconds-per-day+))

(defun num-to-ut (num)
  "Axis number (days since 1970) -> universal time (rounded to seconds)."
  (+ (round (* num +seconds-per-day+)) +unix-epoch-ut+))

(defun date-to-num (timestamp)
  "local-time TIMESTAMP -> axis number (days since the 1970 epoch),
including sub-second precision."
  (+ (/ (float (local-time:timestamp-to-unix timestamp) 1.0d0)
        +seconds-per-day+)
     (/ (local-time:nsec-of timestamp) (* 1.0d9 +seconds-per-day+))))

(defun num-to-date (num)
  "Axis number -> local-time timestamp (UTC)."
  (local-time:unix-to-timestamp (round (* num +seconds-per-day+))))

;;; ============================================================
;;; strftime-style formatting (GMT)
;;; ============================================================

(defparameter *month-abbrevs*
  #("Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec"))
(defparameter *month-names*
  #("January" "February" "March" "April" "May" "June" "July" "August"
    "September" "October" "November" "December"))

(defun format-date (ut fmt)
  "Format universal-time UT with strftime-style directives:
%Y year, %y 2-digit year, %m month (2-digit), %d day (2-digit),
%e day (no pad), %b abbreviated month, %B full month,
%H hour, %M minute, %S second, %% literal percent."
  (multiple-value-bind (sec min hour day month year)
      (decode-universal-time ut 0)
    (with-output-to-string (out)
      (loop with i = 0
            while (< i (length fmt))
            do (let ((ch (char fmt i)))
                 (if (and (char= ch #\%) (< (1+ i) (length fmt)))
                     (progn
                       (case (char fmt (1+ i))
                         (#\Y (format out "~D" year))
                         (#\y (format out "~2,'0D" (mod year 100)))
                         (#\m (format out "~2,'0D" month))
                         (#\d (format out "~2,'0D" day))
                         (#\e (format out "~D" day))
                         (#\b (write-string (aref *month-abbrevs* (1- month)) out))
                         (#\B (write-string (aref *month-names* (1- month)) out))
                         (#\H (format out "~2,'0D" hour))
                         (#\M (format out "~2,'0D" min))
                         (#\S (format out "~2,'0D" sec))
                         (#\% (write-char #\% out))
                         (t (write-char #\% out)
                            (write-char (char fmt (1+ i)) out)))
                       (incf i 2))
                     (progn (write-char ch out) (incf i)))))
      out)))

;;; ============================================================
;;; Calendar-aware break generation
;;; ============================================================

(defun date-add-months (year month n)
  "(values year month) N months after YEAR-MONTH."
  (let ((total (+ (* year 12) (1- month) n)))
    (values (floor total 12) (1+ (mod total 12)))))

(defun date-break-uts (lo-ut hi-ut spec)
  "Universal times of calendar breaks covering [LO-UT, HI-UT].
SPEC is (unit n) with unit one of :year :month :week :day :hour :minute
:second. Sequences anchor at the first unit boundary AT/AFTER lo and step
by N from there (plotnine/matplotlib phase: Jan..Dec data with 6-month
breaks shows Dec/Jun ticks anchored inside the expanded range)."
  (multiple-value-bind (s mi h d mo y) (decode-universal-time lo-ut 0)
    (declare (ignorable s mi h))
    (destructuring-bind (unit n) spec
      (ecase unit
        (:year
         (let ((y0 (if (>= (encode-universal-time 0 0 0 1 1 y 0)
                           (- lo-ut +seconds-per-day+))
                       y
                       (1+ y))))
           (loop for yy from y0 by n
                 for ut = (encode-universal-time 0 0 0 1 1 yy 0)
                 while (<= ut (+ hi-ut +seconds-per-day+))
                 collect ut)))
        (:month
         (multiple-value-bind (y0 m0)
             (if (>= (encode-universal-time 0 0 0 1 mo y 0)
                     (- lo-ut +seconds-per-day+))
                 (values y mo)
                 (date-add-months y mo 1))
           (loop with yy = y0 and mm = m0
                 for ut = (encode-universal-time 0 0 0 1 mm yy 0)
                 while (<= ut (+ hi-ut +seconds-per-day+))
                 collect ut
                 do (multiple-value-setq (yy mm) (date-add-months yy mm n)))))
        ((:week :day)
         (let ((step (* n (if (eq unit :week) 7 1) +seconds-per-day+))
               (start (encode-universal-time 0 0 0 d mo y 0)))
           (loop for ut = start then (+ ut step)
                 while (<= ut hi-ut)
                 when (>= ut lo-ut) collect ut)))
        ((:hour :minute :second)
         (let* ((step (* n (ecase unit (:hour 3600) (:minute 60) (:second 1))))
                ;; anchor at the first step boundary at/after lo within
                ;; the containing day/hour/minute
                (base (ecase unit
                        (:hour (encode-universal-time 0 0 0 d mo y 0))
                        (:minute (encode-universal-time 0 0 h d mo y 0))
                        (:second (encode-universal-time 0 mi h d mo y 0))))
                (start (+ base (* (ceiling (- lo-ut base) step) step))))
           (loop for ut = start then (+ ut step)
                 while (<= ut hi-ut)
                 collect ut)))))))

(defun auto-date-spec (span-days)
  "Break interval spec for a span of SPAN-DAYS (AutoDateLocator-style)."
  (cond ((> span-days 1460) (list :year 1))
        ((> span-days 730) (list :month 6))
        ((> span-days 240) (list :month 3))
        ((> span-days 60) (list :month 1))
        ((> span-days 14) (list :week 1))
        ((> span-days 3) (list :day 1))
        ((> span-days 1/2) (list :hour 6))
        ((> span-days 1/8) (list :hour 1))
        ((> span-days 1/48) (list :minute 15))
        ((> span-days 1/720) (list :minute 1))
        (t (list :second 1))))

(defun auto-date-fmt (spec)
  "Default strftime format for a break interval SPEC."
  (ecase (first spec)
    (:year "%Y")
    (:month "%Y-%m")
    ((:week :day) "%b %e")
    ((:hour :minute) "%H:%M")
    (:second "%H:%M:%S")))

;;; ============================================================
;;; Locators (immutable per-config: all parameters are initargs, so the
;;; axis tick-memoization key on object identity stays valid)
;;; ============================================================

(defclass date-locator (locator)
  ((spec :initarg :spec :initform nil :reader date-locator-spec
         :documentation "Break spec (unit n), or NIL for automatic
selection from the view span."))
  (:documentation "Ticks at calendar boundaries. Axis values are days
since the 1970 epoch."))

(defmethod locator-tick-values ((loc date-locator) vmin vmax)
  (let* ((lo-ut (num-to-ut (min vmin vmax)))
         (hi-ut (num-to-ut (max vmin vmax)))
         (spec (or (date-locator-spec loc)
                   (auto-date-spec (abs (- vmax vmin))))))
    (mapcar #'ut-to-num (date-break-uts lo-ut hi-ut spec))))

(defclass auto-date-locator (date-locator) ()
  (:documentation "date-locator with automatic interval selection."))

(defun %interval-locator (unit interval)
  (make-instance 'date-locator :spec (list unit interval)))

(defun year-locator (&optional (interval 1))
  (%interval-locator :year interval))
(defun month-locator (&optional (interval 1))
  (%interval-locator :month interval))
(defun week-locator (&optional (interval 1))
  (%interval-locator :week interval))
(defun day-locator (&optional (interval 1))
  (%interval-locator :day interval))
(defun hour-locator (&optional (interval 1))
  (%interval-locator :hour interval))
(defun minute-locator (&optional (interval 1))
  (%interval-locator :minute interval))

;;; ============================================================
;;; Formatters
;;; ============================================================

(defgeneric tick-formatter-offset-string (formatter)
  (:documentation "Contextual offset drawn once at the axis end (e.g.
\"2024-Mar\" when tick labels are day numbers). NIL for none.")
  (:method ((formatter tick-formatter)) nil))

(defclass date-formatter (tick-formatter)
  ((fmt :initarg :fmt :initform "%Y-%m-%d" :reader date-formatter-fmt))
  (:documentation "Fixed strftime-style date formatter."))

(defmethod tick-formatter-call ((formatter date-formatter) value &optional pos)
  (declare (ignore pos))
  (format-date (num-to-ut value) (date-formatter-fmt formatter)))

(defclass concise-date-formatter (tick-formatter)
  ((offset :initform nil :accessor %concise-offset))
  (:documentation "matplotlib-style ConciseDateFormatter: per-tick labels
show only the varying field; ticks where a coarser field rolls over show
that field instead; the shared coarser context becomes the offset string
drawn at the axis end."))

(defmethod tick-formatter-format-ticks ((formatter concise-date-formatter)
                                        values)
  (let ((decoded (mapcar (lambda (v)
                           (multiple-value-list
                            (decode-universal-time (num-to-ut v) 0)))
                         values)))
    ;; decoded entry: (sec min hour day month year ...)
    (flet ((field (entry i) (nth i entry))
           (varies (i) (let ((vals (mapcar (lambda (e) (nth i e)) decoded)))
                         (and vals (not (every (lambda (v) (eql v (first vals)))
                                               vals))))))
      (let* ((sec 0) (minute 1) (hour 2) (day 3) (month 4) (year 5)
             ;; level = the coarsest field that varies
             (level (cond ((varies year) :year)
                          ((varies month) :month)
                          ((varies day) :day)
                          ((or (varies hour) (varies minute)) :time)
                          ((varies sec) :second)
                          (t :day))))
        (setf (%concise-offset formatter)
              (when decoded
                (let ((e (first (last decoded))))
                  (ecase level
                    ;; matplotlib omits the offset when the first tick
                    ;; already shows the coarser field (year/month levels)
                    (:year nil)
                    (:month nil)
                    (:day (format nil "~D-~A" (field e year)
                                  (aref *month-abbrevs* (1- (field e month)))))
                    ((:time :second)
                     (format nil "~D-~A-~2,'0D" (field e year)
                             (aref *month-abbrevs* (1- (field e month)))
                             (field e day)))))))
        (loop for e in decoded
              for first-p = t then nil
              collect
              (ecase level
                (:year (format nil "~D" (field e year)))
                (:month
                 ;; January (or the first tick) shows the year
                 (if (or first-p (= (field e month) 1))
                     (format nil "~D" (field e year))
                     (aref *month-abbrevs* (1- (field e month)))))
                (:day
                 ;; day 1 (or the first tick) shows the month
                 (if (or first-p (= (field e day) 1))
                     (aref *month-abbrevs* (1- (field e month)))
                     (format nil "~2,'0D" (field e day))))
                (:time
                 ;; midnight shows the date
                 (if (and (zerop (field e hour)) (zerop (field e minute)))
                     (format nil "~A-~2,'0D"
                             (aref *month-abbrevs* (1- (field e month)))
                             (field e day))
                     (format nil "~2,'0D:~2,'0D"
                             (field e hour) (field e minute))))
                (:second
                 (format nil "~2,'0D:~2,'0D:~2,'0D"
                         (field e hour) (field e minute)
                         (field e sec)))))))))

(defmethod tick-formatter-call ((formatter concise-date-formatter) value
                                &optional pos)
  (declare (ignore pos))
  ;; single-value path: full date
  (format-date (num-to-ut value) "%Y-%m-%d"))

(defmethod tick-formatter-offset-string ((formatter concise-date-formatter))
  (%concise-offset formatter))

;;; ============================================================
;;; Unit-converter registry
;;; ============================================================

(defvar *unit-converters* '()
  "List of (:name k :predicate fn :convert fn :scale keyword) plists.
Plotting entry points probe the first data element against each predicate;
on match the whole sequence is converted with :convert and the axis scale
set to :scale (only if it is still the default linear).")

(defun register-unit-converter (name &key predicate convert (scale :linear))
  "Register (or replace) a data-unit converter. Extension point: register
a predicate + converter for your own temporal or unit-carrying types."
  (setf *unit-converters*
        (cons (list :name name :predicate predicate :convert convert
                    :scale scale)
              (remove name *unit-converters*
                      :key (lambda (c) (getf c :name)))))
  name)

(defun find-unit-converter (value)
  "The first registered converter whose predicate accepts VALUE, or NIL."
  (find-if (lambda (c) (funcall (getf c :predicate) value))
           *unit-converters*))

(register-unit-converter
 :local-time-timestamp
 :predicate (lambda (v) (typep v 'local-time:timestamp))
 :convert #'date-to-num
 :scale :date)
