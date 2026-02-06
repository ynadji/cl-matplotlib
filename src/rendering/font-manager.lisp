;;;; font-manager.lisp — Font discovery, matching, and management
;;;; Ported from matplotlib's font_manager.py
;;;; Pure CL implementation — uses zpb-ttf for TTF loading.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Font weight / style / family constants (from font_manager.py)
;;; ============================================================

(defparameter *font-scalings*
  '(("xx-small" . 0.579d0)
    ("x-small"  . 0.694d0)
    ("small"    . 0.833d0)
    ("medium"   . 1.0d0)
    ("large"    . 1.200d0)
    ("x-large"  . 1.440d0)
    ("xx-large" . 1.728d0)
    ("larger"   . 1.2d0)
    ("smaller"  . 0.833d0))
  "Mapping of named font sizes to scaling factors relative to medium (1.0).")

(defparameter *weight-dict*
  '(("ultralight" . 100) ("light" . 200) ("normal" . 400) ("regular" . 400)
    ("book" . 400) ("medium" . 500) ("roman" . 500)
    ("semibold" . 600) ("demibold" . 600) ("demi" . 600)
    ("bold" . 700) ("heavy" . 800) ("extra bold" . 800) ("black" . 900))
  "Mapping of weight names to numeric values.")

(defparameter *weight-regexes*
  '(("thin" . 100) ("extralight" . 200) ("ultralight" . 200)
    ("demilight" . 350) ("semilight" . 350) ("light" . 300)
    ("book" . 380) ("regular" . 400) ("normal" . 400)
    ("medium" . 500) ("demibold" . 600) ("demi" . 600) ("semibold" . 600)
    ("extrabold" . 800) ("superbold" . 800) ("ultrabold" . 800)
    ("bold" . 700) ("ultrablack" . 1000) ("superblack" . 1000)
    ("extrablack" . 1000) ("black" . 900) ("heavy" . 900))
  "Ordered weight regex matches (order matters: more specific first).")

(defparameter *font-family-aliases*
  '("serif" "sans-serif" "sans serif" "cursive" "fantasy" "monospace" "sans")
  "Generic font family alias names.")

(defparameter *default-font-families*
  '(("serif"      . ("DejaVu Serif" "Times New Roman" "Times"))
    ("sans-serif"  . ("DejaVu Sans" "Liberation Sans" "Arial" "Helvetica"))
    ("sans"        . ("DejaVu Sans" "Liberation Sans" "Arial" "Helvetica"))
    ("monospace"   . ("DejaVu Sans Mono" "Liberation Mono" "Courier New" "Courier"))
    ("cursive"     . ("Apple Chancery" "Textile"))
    ("fantasy"     . ("Western" "Impact")))
  "Default fallback families for generic font family names.")

;;; ============================================================
;;; System font directories
;;; ============================================================

(defparameter *system-font-directories*
  (list "/usr/share/fonts/"
        "/usr/local/share/fonts/"
        "/usr/X11R6/lib/X11/fonts/TTF/"
        (namestring (merge-pathnames ".fonts/" (user-homedir-pathname)))
        (namestring (merge-pathnames ".local/share/fonts/" (user-homedir-pathname))))
  "Directories to scan for system fonts (X11/Linux).")

;;; ============================================================
;;; Font entry — metadata for a discovered font
;;; ============================================================

(defstruct font-entry
  "Metadata for a discovered font file."
  (fname "" :type string)
  (name "" :type string)
  (style "normal" :type string)
  (variant "normal" :type string)
  (weight 400 :type (or string integer))
  (stretch "normal" :type string)
  (size "scalable" :type string))

;;; ============================================================
;;; Font properties — query specification
;;; ============================================================

(defstruct (font-properties (:constructor %make-font-properties))
  "Properties used to select/match a font."
  (family '("sans-serif") :type list)
  (style "normal" :type string)
  (variant "normal" :type string)
  (weight 400 :type (or integer string))
  (stretch "normal" :type string)
  (size 10.0d0 :type double-float))

(defun make-font-properties (&key (family '("sans-serif"))
                                   (style "normal")
                                   (variant "normal")
                                   (weight "normal")
                                   (stretch "normal")
                                   (size 10.0))
  "Create font properties for font matching."
  (let ((fam (if (stringp family) (list family) family))
        (wt (if (stringp weight)
                (let ((entry (assoc weight *weight-dict* :test #'string-equal)))
                  (if entry (cdr entry) 400))
                weight)))
    (%make-font-properties :family fam
                           :style (string-downcase style)
                           :variant (string-downcase variant)
                           :weight wt
                           :stretch (string-downcase stretch)
                           :size (float size 1.0d0))))

;;; ============================================================
;;; Font manager — singleton with font database
;;; ============================================================

(defclass font-manager ()
  ((ttf-list :initform nil :accessor fm-ttf-list
             :documentation "List of FontEntry objects for TTF fonts.")
   (afm-list :initform nil :accessor fm-afm-list
             :documentation "List of FontEntry objects for AFM fonts.")
   (fonts-by-family :initform (make-hash-table :test 'equal)
                    :accessor fm-fonts-by-family
                    :documentation "Hash: family-name → list of FontEntry.")
   (font-cache :initform (make-hash-table :test 'equal)
               :accessor fm-font-cache
               :documentation "Hash: font-path → zpb-ttf font-loader."))
  (:documentation "Manages font discovery, matching, and caching.
Ported from matplotlib's FontManager."))

(defvar *font-manager* nil
  "Global font manager singleton.")

;;; ============================================================
;;; Shipped font paths (bundled DejaVu Sans)
;;; ============================================================

(defun shipped-font-directory ()
  "Return the path to shipped fonts bundled with cl-matplotlib."
  (let ((system-dir (asdf:system-source-directory :cl-matplotlib-rendering)))
    (when system-dir
      (merge-pathnames "data/fonts/ttf/" system-dir))))

(defun shipped-font-files ()
  "Return list of font file paths shipped with cl-matplotlib."
  (let ((dir (shipped-font-directory)))
    (when (and dir (probe-file dir))
      (directory (merge-pathnames "*.ttf" dir)))))

;;; ============================================================
;;; Font discovery — scan directories for TTF files
;;; ============================================================

(defun list-font-files (directory &key (extensions '("ttf" "otf" "ttc")))
  "Recursively find font files in DIRECTORY matching EXTENSIONS."
  (let ((result '()))
    (when (and directory (probe-file directory))
      (dolist (ext extensions)
        (let ((pattern (merge-pathnames (make-pathname :name :wild :type ext)
                                         (pathname-as-directory directory))))
          (dolist (f (directory pattern))
            (push (namestring f) result)))
        ;; Also check subdirectories (one level deep for performance)
        (let ((subdir-pattern (merge-pathnames
                               (make-pathname :directory '(:relative :wild)
                                              :name :wild :type ext)
                               (pathname-as-directory directory))))
          (dolist (f (directory subdir-pattern))
            (push (namestring f) result)))
        ;; Two levels deep
        (let ((subdir-pattern2 (merge-pathnames
                                (make-pathname :directory '(:relative :wild :wild)
                                               :name :wild :type ext)
                                (pathname-as-directory directory))))
          (dolist (f (directory subdir-pattern2))
            (push (namestring f) result)))))
    (remove-duplicates result :test #'string=)))

(defun pathname-as-directory (pathname)
  "Ensure PATHNAME ends with a directory separator."
  (let ((p (pathname pathname)))
    (if (or (pathname-name p) (pathname-type p))
        (make-pathname :directory (append (or (pathname-directory p) '(:relative))
                                          (list (file-namestring p)))
                       :defaults p)
        p)))

(defun find-system-fonts ()
  "Find all TTF/OTF font files on the system."
  (let ((all-files '()))
    ;; System directories
    (dolist (dir *system-font-directories*)
      (dolist (f (list-font-files dir))
        (push f all-files)))
    ;; Shipped fonts
    (dolist (f (shipped-font-files))
      (push (namestring f) all-files))
    (remove-duplicates all-files :test #'string=)))

;;; ============================================================
;;; TTF font property extraction (via zpb-ttf)
;;; ============================================================

(defun extract-ttf-properties (font-path)
  "Extract font properties from a TTF file using zpb-ttf.
Returns a FONT-ENTRY or NIL on error."
  (handler-case
      (zpb-ttf:with-font-loader (loader font-path)
        (let* ((name (or (zpb-ttf:family-name loader) "Unknown"))
               (subfamily (or (zpb-ttf:subfamily-name loader) "Regular"))
               (subfamily-lower (string-downcase subfamily))
               ;; Style detection
               (style (cond
                        ((search "oblique" subfamily-lower) "oblique")
                        ((search "italic" subfamily-lower) "italic")
                        (t "normal")))
               ;; Weight detection
               (weight (or (detect-weight-from-name subfamily-lower) 400)))
          (make-font-entry :fname font-path
                           :name name
                           :style style
                           :weight weight)))
    (condition (c)
      (declare (ignore c))
      nil)))

(defun detect-weight-from-name (name-lower)
  "Detect numeric font weight from a lowercase style/subfamily name."
  (dolist (pair *weight-regexes*)
    (when (search (car pair) name-lower)
      (return-from detect-weight-from-name (cdr pair))))
  nil)

;;; ============================================================
;;; Font manager initialization
;;; ============================================================

(defmethod initialize-instance :after ((fm font-manager) &key)
  "Discover fonts and build the database."
  (build-font-database fm))

(defun build-font-database (fm)
  "Scan for fonts and populate the font manager database."
  (let ((font-files (find-system-fonts))
        (entries '())
        (by-family (fm-fonts-by-family fm)))
    (clrhash by-family)
    (dolist (path font-files)
      (let ((entry (extract-ttf-properties path)))
        (when entry
          (push entry entries)
          (let* ((family (string-downcase (font-entry-name entry)))
                 (existing (gethash family by-family)))
            (setf (gethash family by-family) (cons entry existing))))))
    (setf (fm-ttf-list fm) (nreverse entries))))

;;; ============================================================
;;; Font matching — CSS-like algorithm
;;; ============================================================

(defun normalize-weight (weight)
  "Convert weight to integer. Keywords/strings → numeric."
  (etypecase weight
    (integer weight)
    (keyword (let ((entry (assoc (string-downcase (symbol-name weight))
                                 *weight-dict* :test #'string-equal)))
               (if entry (cdr entry) 400)))
    (string (let ((entry (assoc weight *weight-dict* :test #'string-equal)))
              (if entry (cdr entry) 400)))))

(defun resolve-font-family (family-name)
  "Resolve a generic font family name to a list of specific families.
E.g., 'sans-serif' → ('DejaVu Sans' 'Liberation Sans' ...)."
  (let ((lower (string-downcase family-name)))
    (if (member lower *font-family-aliases* :test #'string=)
        (let ((entry (assoc lower *default-font-families* :test #'string=)))
          (if entry (cdr entry) (list family-name)))
        (list family-name))))

(defun score-font-match (entry family weight style)
  "Score how well ENTRY matches the requested properties.
Lower score = better match. 0 = perfect."
  (let ((score 0))
    ;; Family match
    (unless (string-equal (font-entry-name entry) family)
      (incf score 10000))
    ;; Style match (exact=0, mismatch=+1000)
    (unless (string-equal (font-entry-style entry) style)
      (incf score 1000))
    ;; Weight match (absolute difference)
    (let ((entry-weight (if (integerp (font-entry-weight entry))
                            (font-entry-weight entry)
                            (normalize-weight (font-entry-weight entry))))
          (target-weight weight))
      (incf score (abs (- entry-weight target-weight))))
    score))

(defun find-font (fm &key (family "sans-serif") (weight :normal) (style :normal))
  "Find the best matching font file for the given properties.
Returns font file path (string) or NIL."
  (let* ((target-weight (normalize-weight weight))
         (target-style (string-downcase (if (keywordp style)
                                            (symbol-name style)
                                            style)))
         (families (resolve-font-family family))
         (best-path nil)
         (best-score most-positive-fixnum))
    ;; Try each resolved family
    (dolist (fam families)
      (let ((fam-lower (string-downcase fam)))
        (dolist (entry (fm-ttf-list fm))
          (let ((score (score-font-match entry fam-lower target-weight target-style)))
            (when (< score best-score)
              (setf best-score score
                    best-path (font-entry-fname entry)))))))
    ;; If nothing found, try DejaVu Sans as ultimate fallback
    (unless best-path
      (let ((shipped (shipped-font-files)))
        (when shipped
          (setf best-path (namestring (first shipped))))))
    best-path))

(defun findfont (props &optional (fm *font-manager*))
  "Find the best matching font for FONT-PROPERTIES.
Returns a font file path (string)."
  (unless fm
    (setf fm (ensure-font-manager)))
  (find-font fm
             :family (first (font-properties-family props))
             :weight (font-properties-weight props)
             :style (font-properties-style props)))

;;; ============================================================
;;; Font loading — zpb-ttf font-loader cache
;;; ============================================================

(defun load-font (font-name &optional (fm *font-manager*))
  "Load a font by family name. Returns a zpb-ttf font-loader.
The font-loader is cached in the font manager."
  (unless fm
    (setf fm (ensure-font-manager)))
  (let ((path (find-font fm :family font-name)))
    (unless path
      (error "Font not found: ~A" font-name))
    (load-font-by-path path fm)))

(defun load-font-by-path (path &optional (fm *font-manager*))
  "Load a font from PATH. Returns a zpb-ttf font-loader.
The font-loader is cached."
  (unless fm
    (setf fm (ensure-font-manager)))
  (let ((cached (gethash path (fm-font-cache fm))))
    (if cached
        cached
        (let ((loader (zpb-ttf:open-font-loader path)))
          (setf (gethash path (fm-font-cache fm)) loader)
          loader))))

;;; ============================================================
;;; Font cache — serialize to disk
;;; ============================================================

(defun font-cache-path ()
  "Return the path for the font cache file."
  (merge-pathnames ".cache/cl-matplotlib/fontlist.cache"
                   (user-homedir-pathname)))

(defun save-font-cache (fm)
  "Serialize the font list to disk."
  (let ((path (font-cache-path)))
    (ensure-directories-exist path)
    (with-open-file (out path :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create)
      (dolist (entry (fm-ttf-list fm))
        (format out "~A|~A|~A|~A|~A~%"
                (font-entry-fname entry)
                (font-entry-name entry)
                (font-entry-style entry)
                (font-entry-weight entry)
                (font-entry-stretch entry))))))

(defun load-font-cache (fm)
  "Load the font list from disk cache. Returns T if cache was loaded."
  (let ((path (font-cache-path)))
    (when (probe-file path)
      (handler-case
          (with-open-file (in path :direction :input)
            (let ((entries '())
                  (by-family (fm-fonts-by-family fm)))
              (clrhash by-family)
              (loop for line = (read-line in nil nil)
                    while line
                    do (let ((parts (split-string-by-char line #\|)))
                         (when (>= (length parts) 5)
                           (let* ((fname (nth 0 parts))
                                  (name (nth 1 parts))
                                  (style (nth 2 parts))
                                  (weight-str (nth 3 parts))
                                  (weight (handler-case (parse-integer weight-str)
                                            (error () weight-str)))
                                  (entry (make-font-entry
                                          :fname fname :name name
                                          :style style :weight weight)))
                             ;; Only include if file still exists
                             (when (probe-file fname)
                               (push entry entries)
                               (let ((family (string-downcase name)))
                                 (push entry (gethash family by-family))))))))
              (setf (fm-ttf-list fm) (nreverse entries))
              t))
        (error () nil)))))

(defun split-string-by-char (string char)
  "Split STRING by CHAR into a list of substrings."
  (loop for start = 0 then (1+ pos)
        for pos = (position char string :start start)
        collect (subseq string start (or pos (length string)))
        while pos))

;;; ============================================================
;;; Global font manager initialization
;;; ============================================================

(defun ensure-font-manager ()
  "Return the global font manager, creating it if needed."
  (unless *font-manager*
    (setf *font-manager* (make-instance 'font-manager)))
  *font-manager*)

(defun reset-font-manager ()
  "Reset and rebuild the global font manager."
  (setf *font-manager* nil)
  (ensure-font-manager))

;;; ============================================================
;;; Font metrics — zpb-ttf wrappers
;;; ============================================================

(defun get-glyph-advance-width (font-loader char-code)
  "Get the advance width of a glyph in font units.
CHAR-CODE is a character or character code."
  (let* ((code (if (characterp char-code) (char-code char-code) char-code))
         (glyph (zpb-ttf:find-glyph code font-loader)))
    (if glyph
        (zpb-ttf:advance-width glyph)
        0)))

(defun get-font-units-per-em (font-loader)
  "Return the units-per-em value for the font."
  (zpb-ttf:units/em font-loader))

(defun get-font-ascender (font-loader)
  "Return the font ascender in font units."
  (zpb-ttf:ascender font-loader))

(defun get-font-descender (font-loader)
  "Return the font descender in font units (usually negative)."
  (zpb-ttf:descender font-loader))

(defun font-units-to-points (value font-loader size)
  "Convert font units to points at the given SIZE."
  (* (/ (float value 1.0d0) (float (get-font-units-per-em font-loader) 1.0d0))
     (float size 1.0d0)))

(defun get-text-extents (text font-loader size)
  "Get the bounding box of TEXT rendered at SIZE points.
Returns a BBOX (from cl-matplotlib.primitives)."
  (let* ((units-per-em (get-font-units-per-em font-loader))
         (scale (/ (float size 1.0d0) (float units-per-em 1.0d0)))
         (x-pos 0.0d0)
         (min-x 0.0d0)
         (max-x 0.0d0)
         (min-y (* (float (get-font-descender font-loader) 1.0d0) scale))
         (max-y (* (float (get-font-ascender font-loader) 1.0d0) scale))
         (prev-glyph nil))
    (loop for char across text
          for glyph = (zpb-ttf:find-glyph (char-code char) font-loader)
          do (when glyph
               ;; Kerning
               (when prev-glyph
                 (let ((kern (zpb-ttf:kerning-offset prev-glyph glyph font-loader)))
                   (when kern
                     (incf x-pos (* (float kern 1.0d0) scale)))))
               ;; Advance
               (let ((advance (* (float (zpb-ttf:advance-width glyph) 1.0d0) scale)))
                 (incf x-pos advance))
               ;; Track glyph bbox
               (let ((bb (zpb-ttf:bounding-box glyph)))
                 (when bb
                   (let ((gx-min (* (float (zpb-ttf:xmin bb) 1.0d0) scale))
                         (gy-min (* (float (zpb-ttf:ymin bb) 1.0d0) scale))
                         (gx-max (* (float (zpb-ttf:xmax bb) 1.0d0) scale))
                         (gy-max (* (float (zpb-ttf:ymax bb) 1.0d0) scale)))
                     (declare (ignore gx-min))
                     (setf min-y (min min-y gy-min))
                     (setf max-y (max max-y gy-max))
                     (setf max-x (max max-x (+ x-pos gx-max))))))
               (setf prev-glyph glyph))
             (setf prev-glyph nil))
    (setf max-x (max max-x x-pos))
    (cl-matplotlib.primitives:make-bbox min-x min-y max-x max-y)))
