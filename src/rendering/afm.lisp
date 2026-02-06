;;;; afm.lisp — Adobe Font Metrics file parser
;;;; Ported from matplotlib's _afm.py
;;;; Pure CL implementation — no external dependencies.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; AFM data structures
;;; ============================================================

(defstruct afm-char-metrics
  "Metrics for a single character in an AFM file."
  (width 0.0d0 :type double-float)
  (name "" :type string)
  (bbox nil :type (or null list)))  ; (llx lly urx ury) as integers

(defstruct (afm-font (:constructor %make-afm-font))
  "Parsed Adobe Font Metrics file."
  (header (make-hash-table :test 'equal) :type hash-table)
  (metrics-by-code (make-hash-table) :type hash-table)     ; code → afm-char-metrics
  (metrics-by-name (make-hash-table :test 'equal) :type hash-table) ; name → afm-char-metrics
  (kern-pairs (make-hash-table :test 'equal) :type hash-table))     ; (name1 . name2) → value

;;; ============================================================
;;; AFM parsing utilities
;;; ============================================================

(defun afm-to-int (s)
  "Convert string S to integer, handling floats by truncation."
  (truncate (afm-to-float s)))

(defun afm-to-float (s)
  "Convert string S to float, handling comma as decimal separator."
  (let ((clean (substitute #\. #\, (string-trim '(#\Space #\Tab #\Return) s))))
    (float (read-from-string clean) 1.0d0)))

(defun afm-to-bool (s)
  "Convert string S to boolean."
  (let ((lower (string-downcase (string-trim '(#\Space #\Tab #\Return) s))))
    (not (or (string= lower "false") (string= lower "0") (string= lower "no")))))

(defun afm-to-list-of-ints (s)
  "Parse a space-separated string of numbers into a list of integers."
  (let ((parts (split-afm-whitespace (string-trim '(#\Space #\Tab #\Return) s))))
    (mapcar #'afm-to-int parts)))

(defun split-afm-whitespace (s)
  "Split string S by whitespace."
  (let ((result '())
        (start nil))
    (loop for i from 0 below (length s)
          for c = (char s i)
          do (if (or (char= c #\Space) (char= c #\Tab))
                 (when start
                   (push (subseq s start i) result)
                   (setf start nil))
                 (unless start
                   (setf start i))))
    (when start
      (push (subseq s start) result))
    (nreverse result)))

;;; ============================================================
;;; AFM header parser
;;; ============================================================

(defun parse-afm-header (stream)
  "Parse the AFM header up to StartCharMetrics.
Returns a hash table of header key-value pairs."
  (let ((header (make-hash-table :test 'equal))
        (first-line t)
        ;; Converters for known keys
        (float-keys '("StartFontMetrics" "ItalicAngle" "UnderlinePosition"
                       "UnderlineThickness" "CapHeight" "Capheight"
                       "XHeight" "Ascender" "Descender" "StdHW" "StdVW"))
        (string-keys '("FontName" "FullName" "FamilyName" "Weight" "Version"
                        "EncodingScheme" "CharacterSet"))
        (int-keys '("StartCharMetrics" "Characters"))
        (bool-keys '("IsFixedPitch"))
        (bbox-keys '("FontBBox")))
    (loop for line = (read-line stream nil nil)
          while line
          do (let ((trimmed (string-right-trim '(#\Return #\Newline) line)))
               (when (and (> (length trimmed) 0)
                          (not (starts-with-p trimmed "Comment")))
                 (multiple-value-bind (key val)
                     (split-afm-key-value trimmed)
                   (when first-line
                     (unless (string= key "StartFontMetrics")
                       (error "Not an AFM file (first key: ~A)" key))
                     (setf first-line nil))
                   (cond
                     ((member key string-keys :test #'string=)
                      (setf (gethash key header) (string-trim '(#\Space) val)))
                     ((member key float-keys :test #'string=)
                      (handler-case
                          (setf (gethash key header) (afm-to-float val))
                        (error () nil)))
                     ((member key int-keys :test #'string=)
                      (handler-case
                          (setf (gethash key header) (afm-to-int val))
                        (error () nil)))
                     ((member key bool-keys :test #'string=)
                      (setf (gethash key header) (afm-to-bool val)))
                     ((member key bbox-keys :test #'string=)
                      (handler-case
                          (setf (gethash key header) (afm-to-list-of-ints val))
                        (error () nil))))
                   (when (string= key "StartCharMetrics")
                     (return))))))
    header))

(defun split-afm-key-value (line)
  "Split an AFM line into key and value at first space."
  (let ((pos (position #\Space line)))
    (if pos
        (values (subseq line 0 pos) (subseq line (1+ pos)))
        (values line ""))))

(defun starts-with-p (string prefix)
  "Return T if STRING starts with PREFIX."
  (and (>= (length string) (length prefix))
       (string= string prefix :end1 (length prefix))))

;;; ============================================================
;;; Character metrics parser
;;; ============================================================

(defun parse-afm-char-metrics (stream)
  "Parse character metrics section.
Returns (values metrics-by-code metrics-by-name)."
  (let ((by-code (make-hash-table))
        (by-name (make-hash-table :test 'equal)))
    (loop for line = (read-line stream nil nil)
          while line
          do (let ((trimmed (string-right-trim '(#\Return #\Newline) line)))
               (when (starts-with-p trimmed "EndCharMetrics")
                 (return))
               (when (> (length trimmed) 0)
                 ;; Parse: C 32 ; WX 278 ; N space ; B 0 0 0 0 ;
                 (let ((parts (split-afm-semicolons trimmed))
                       (code nil) (wx nil) (name nil) (bbox nil))
                   (dolist (part parts)
                     (let* ((p (string-trim '(#\Space #\Tab) part))
                            (tokens (split-afm-whitespace p)))
                       (when tokens
                         (let ((key (first tokens)))
                           (cond
                             ((string= key "C")
                              (setf code (afm-to-int (second tokens))))
                             ((string= key "WX")
                              (setf wx (afm-to-float (second tokens))))
                             ((string= key "N")
                              (setf name (second tokens)))
                             ((string= key "B")
                              (setf bbox (mapcar #'afm-to-int (rest tokens)))))))))
                   (when (and wx name)
                     (let ((metrics (make-afm-char-metrics :width wx :name name :bbox bbox)))
                       ;; Handle Euro/minus special cases
                       (cond
                         ((string= name "Euro") (setf code 128))
                         ((string= name "minus") (setf code #x2212)))
                       (when (and code (/= code -1))
                         (setf (gethash code by-code) metrics))
                       (setf (gethash name by-name) metrics)))))))
    (values by-code by-name)))

(defun split-afm-semicolons (s)
  "Split string S by semicolons."
  (loop for start = 0 then (1+ pos)
        for pos = (position #\; s :start start)
        collect (subseq s start (or pos (length s)))
        while pos))

;;; ============================================================
;;; Kern pairs parser
;;; ============================================================

(defun parse-afm-kern-pairs (stream)
  "Parse kern pairs section.
Returns a hash table mapping (name1 . name2) → kern value."
  (let ((kern (make-hash-table :test 'equal)))
    ;; First line should be StartKernPairs (or we're already past it)
    (loop for line = (read-line stream nil nil)
          while line
          do (let ((trimmed (string-right-trim '(#\Return #\Newline) line)))
               (when (starts-with-p trimmed "EndKernPairs")
                 (return))
               (when (> (length trimmed) 0)
                 (let ((tokens (split-afm-whitespace trimmed)))
                   (when (and (>= (length tokens) 4)
                              (string= (first tokens) "KPX"))
                     (let ((c1 (second tokens))
                           (c2 (third tokens))
                           (val (afm-to-float (fourth tokens))))
                       (setf (gethash (cons c1 c2) kern) val)))))))
    kern))

;;; ============================================================
;;; Optional sections parser
;;; ============================================================

(defun parse-afm-optional (stream)
  "Parse optional sections (kern data, composites).
Returns kern pairs hash table."
  (let ((kern (make-hash-table :test 'equal)))
    (loop for line = (read-line stream nil nil)
          while line
          do (let ((trimmed (string-right-trim '(#\Return #\Newline) line)))
               (when (starts-with-p trimmed "StartKernPairs")
                 (setf kern (parse-afm-kern-pairs stream)))
               ;; Skip composites and other sections
               ))
    kern))

;;; ============================================================
;;; Main AFM parser entry point
;;; ============================================================

(defun parse-afm-file (pathname)
  "Parse an AFM file and return an AFM-FONT struct.
PATHNAME is a string or pathname to the .afm file."
  (with-open-file (stream pathname :direction :input
                                    :element-type 'character
                                    :external-format :latin-1)
    (let ((header (parse-afm-header stream)))
      (multiple-value-bind (by-code by-name)
          (parse-afm-char-metrics stream)
        (let ((kern (parse-afm-optional stream)))
          (%make-afm-font :header header
                          :metrics-by-code by-code
                          :metrics-by-name by-name
                          :kern-pairs kern))))))

;;; ============================================================
;;; AFM font accessors (matching matplotlib's AFM class)
;;; ============================================================

(defun afm-get-fontname (afm)
  "Return the PostScript font name."
  (gethash "FontName" (afm-font-header afm) "Unknown"))

(defun afm-get-fullname (afm)
  "Return the full font name."
  (or (gethash "FullName" (afm-font-header afm))
      (afm-get-fontname afm)))

(defun afm-get-familyname (afm)
  "Return the font family name."
  (or (gethash "FamilyName" (afm-font-header afm))
      (afm-get-fullname afm)))

(defun afm-get-weight (afm)
  "Return the font weight string."
  (gethash "Weight" (afm-font-header afm) "Medium"))

(defun afm-get-angle (afm)
  "Return the italic angle."
  (gethash "ItalicAngle" (afm-font-header afm) 0.0d0))

(defun afm-get-ascender (afm)
  "Return the font ascender."
  (gethash "Ascender" (afm-font-header afm) 0.0d0))

(defun afm-get-descender (afm)
  "Return the font descender."
  (gethash "Descender" (afm-font-header afm) 0.0d0))

(defun afm-get-capheight (afm)
  "Return the cap height."
  (or (gethash "CapHeight" (afm-font-header afm))
      (gethash "Capheight" (afm-font-header afm))
      0.0d0))

(defun afm-get-xheight (afm)
  "Return the x-height."
  (gethash "XHeight" (afm-font-header afm) 0.0d0))

(defun afm-get-bbox (afm)
  "Return the font bounding box as a list (llx lly urx ury)."
  (gethash "FontBBox" (afm-font-header afm) '(0 0 0 0)))

(defun afm-get-char-width (afm char-code)
  "Get the width of a character by its code point."
  (let ((metrics (gethash char-code (afm-font-metrics-by-code afm))))
    (if metrics
        (afm-char-metrics-width metrics)
        0.0d0)))

(defun afm-get-width-from-name (afm name)
  "Get the width of a character from its PostScript name."
  (let ((metrics (gethash name (afm-font-metrics-by-name afm))))
    (if metrics
        (afm-char-metrics-width metrics)
        0.0d0)))

(defun afm-get-kern-dist (afm name1 name2)
  "Return the kerning distance between NAME1 and NAME2."
  (gethash (cons name1 name2) (afm-font-kern-pairs afm) 0.0d0))

(defun afm-get-str-bbox-and-descent (afm text)
  "Return bounding box and descent for TEXT.
Returns (values left miny total-width height descent)."
  (if (zerop (length text))
      (values 0.0d0 0.0d0 0.0d0 0.0d0 0.0d0)
      (let ((total-width 0.0d0)
            (last-name nil)
            (miny 1.0d9)
            (maxy 0.0d0)
            (left 0.0d0))
        (loop for c across text
              when (char/= c #\Newline)
              do (let* ((code (char-code c))
                        ;; Simple Unicode → Type1 name mapping
                        (name (afm-unicode-to-type1-name code))
                        (metrics (or (gethash name (afm-font-metrics-by-name afm))
                                     (gethash "question" (afm-font-metrics-by-name afm)))))
                   (when metrics
                     (let ((wx (afm-char-metrics-width metrics))
                           (bbox (afm-char-metrics-bbox metrics)))
                       (incf total-width wx)
                       ;; Add kerning
                       (when last-name
                         (incf total-width (afm-get-kern-dist afm last-name name)))
                       ;; Track bbox
                       (when bbox
                         (let ((b (second bbox))
                               (h (fourth bbox)))
                           (setf left (min left (float (first bbox) 1.0d0)))
                           (setf miny (min miny (float b 1.0d0)))
                           (setf maxy (max maxy (float (+ b h) 1.0d0))))))
                     (setf last-name name))))
        (values left miny total-width (- maxy miny) (- miny)))))

;;; ============================================================
;;; Basic Unicode → Type1 name mapping
;;; ============================================================

(defparameter *unicode-to-type1*
  (let ((ht (make-hash-table)))
    ;; ASCII printable characters
    (setf (gethash 32 ht) "space"
          (gethash 33 ht) "exclam"
          (gethash 34 ht) "quotedbl"
          (gethash 35 ht) "numbersign"
          (gethash 36 ht) "dollar"
          (gethash 37 ht) "percent"
          (gethash 38 ht) "ampersand"
          (gethash 39 ht) "quoteright"
          (gethash 40 ht) "parenleft"
          (gethash 41 ht) "parenright"
          (gethash 42 ht) "asterisk"
          (gethash 43 ht) "plus"
          (gethash 44 ht) "comma"
          (gethash 45 ht) "hyphen"
          (gethash 46 ht) "period"
          (gethash 47 ht) "slash"
          (gethash 48 ht) "zero"
          (gethash 49 ht) "one"
          (gethash 50 ht) "two"
          (gethash 51 ht) "three"
          (gethash 52 ht) "four"
          (gethash 53 ht) "five"
          (gethash 54 ht) "six"
          (gethash 55 ht) "seven"
          (gethash 56 ht) "eight"
          (gethash 57 ht) "nine"
          (gethash 58 ht) "colon"
          (gethash 59 ht) "semicolon"
          (gethash 60 ht) "less"
          (gethash 61 ht) "equal"
          (gethash 62 ht) "greater"
          (gethash 63 ht) "question"
          (gethash 64 ht) "at")
    ;; Uppercase A-Z
    (loop for code from 65 to 90
          do (setf (gethash code ht) (string (code-char code))))
    (setf (gethash 91 ht) "bracketleft"
          (gethash 92 ht) "backslash"
          (gethash 93 ht) "bracketright"
          (gethash 94 ht) "asciicircum"
          (gethash 95 ht) "underscore"
          (gethash 96 ht) "quoteleft")
    ;; Lowercase a-z
    (loop for code from 97 to 122
          do (setf (gethash code ht) (string (code-char code))))
    (setf (gethash 123 ht) "braceleft"
          (gethash 124 ht) "bar"
          (gethash 125 ht) "braceright"
          (gethash 126 ht) "asciitilde")
    ht)
  "Mapping from Unicode code points to PostScript/Type1 glyph names.")

(defun afm-unicode-to-type1-name (code)
  "Convert a Unicode code point to a Type1 glyph name."
  (or (gethash code *unicode-to-type1*)
      (format nil "uni~4,'0X" code)))
