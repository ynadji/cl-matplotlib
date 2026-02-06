;;;; test-font-manager.lisp — Tests for font management, text-to-path, AFM parser
;;;; Phase 3d — FiveAM test suite

(defpackage #:cl-matplotlib.tests.font
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rendering
                ;; Font Manager
                #:font-entry #:make-font-entry
                #:font-entry-fname #:font-entry-name #:font-entry-style #:font-entry-weight
                #:font-properties #:make-font-properties
                #:font-properties-family #:font-properties-style
                #:font-properties-weight #:font-properties-size
                #:font-manager #:*font-manager* #:ensure-font-manager #:reset-font-manager
                #:find-font #:findfont #:load-font #:load-font-by-path
                #:find-system-fonts #:shipped-font-directory #:shipped-font-files
                #:get-glyph-advance-width #:get-font-units-per-em
                #:get-font-ascender #:get-font-descender
                #:font-units-to-points #:get-text-extents
                #:normalize-weight #:resolve-font-family
                #:*font-scalings* #:*weight-dict* #:*font-family-aliases*
                #:*default-font-families* #:*system-font-directories*
                ;; Text-to-Path
                #:text-to-path #:text-to-compound-path
                #:layout-multiline-text #:get-text-width-height-descent
                ;; AFM Parser
                #:afm-font #:parse-afm-file
                #:afm-char-metrics #:afm-char-metrics-width
                #:afm-char-metrics-name #:afm-char-metrics-bbox
                #:afm-get-fontname #:afm-get-fullname #:afm-get-familyname
                #:afm-get-weight #:afm-get-angle
                #:afm-get-ascender #:afm-get-descender
                #:afm-get-capheight #:afm-get-xheight #:afm-get-bbox
                #:afm-get-char-width #:afm-get-width-from-name
                #:afm-get-kern-dist #:afm-get-str-bbox-and-descent
                #:afm-unicode-to-type1-name)
  (:import-from #:cl-matplotlib.primitives
                #:mpl-path #:mpl-path-vertices #:mpl-path-codes
                #:path-length #:bbox-width #:bbox-height
                #:bbox-x0 #:bbox-y0 #:bbox-x1 #:bbox-y1)
  (:export #:run-font-tests))

(in-package #:cl-matplotlib.tests.font)

(def-suite font-suite :description "Font management, text-to-path, and AFM parser tests")
(in-suite font-suite)

(defun run-font-tests ()
  "Run all font tests and report results."
  (run! 'font-suite))

;;; ============================================================
;;; Helper to get the shipped DejaVu Sans font path
;;; ============================================================

(defun dejavu-font-path ()
  "Return the path to the shipped DejaVu Sans font."
  (let ((dir (shipped-font-directory)))
    (when dir
      (merge-pathnames "DejaVuSans.ttf" dir))))

;;; ============================================================
;;; Font Manager Tests
;;; ============================================================

(test shipped-font-exists
  "Shipped DejaVu Sans font file exists."
  (let ((path (dejavu-font-path)))
    (is-true path "shipped-font-directory returned NIL")
    (is-true (probe-file path) "DejaVuSans.ttf not found at shipped location")))

(test shipped-font-files-returns-list
  "shipped-font-files returns a non-empty list."
  (let ((files (shipped-font-files)))
    (is-true (listp files))
    (is-true (> (length files) 0) "No shipped font files found")))

(test font-manager-creation
  "Font manager can be created."
  (let ((fm (make-instance 'font-manager)))
    (is-true fm "font-manager creation failed")))

(test ensure-font-manager-works
  "ensure-font-manager creates a singleton."
  (let ((cl-matplotlib.rendering::*font-manager* nil))
    (let ((fm (ensure-font-manager)))
      (is-true fm "ensure-font-manager returned NIL")
      (is (eq fm (ensure-font-manager)) "ensure-font-manager not idempotent"))))

(test normalize-weight-keyword
  "normalize-weight converts keywords to integers."
  (is (= 400 (normalize-weight :normal)))
  (is (= 700 (normalize-weight :bold)))
  (is (= 200 (normalize-weight :light))))

(test normalize-weight-string
  "normalize-weight converts strings to integers."
  (is (= 400 (normalize-weight "normal")))
  (is (= 700 (normalize-weight "bold")))
  (is (= 900 (normalize-weight "black"))))

(test normalize-weight-integer
  "normalize-weight passes integers through."
  (is (= 400 (normalize-weight 400)))
  (is (= 700 (normalize-weight 700))))

(test resolve-font-family-generic
  "resolve-font-family expands generic family names."
  (let ((families (resolve-font-family "sans-serif")))
    (is-true (listp families))
    (is-true (> (length families) 0))
    (is (string= "DejaVu Sans" (first families)))))

(test resolve-font-family-specific
  "resolve-font-family passes through specific family names."
  (let ((families (resolve-font-family "My Custom Font")))
    (is (= 1 (length families)))
    (is (string= "My Custom Font" (first families)))))

(test find-font-dejavu
  "find-font can locate DejaVu Sans."
  (let ((fm (make-instance 'font-manager)))
    (let ((path (find-font fm :family "DejaVu Sans")))
      (is-true path "find-font returned NIL for DejaVu Sans")
      (is-true (search "DejaVu" path) "Path doesn't contain DejaVu"))))

(test find-font-sans-serif
  "find-font resolves 'sans-serif' to a font."
  (let ((fm (make-instance 'font-manager)))
    (let ((path (find-font fm :family "sans-serif")))
      (is-true path "find-font returned NIL for sans-serif"))))

(test find-font-fallback
  "find-font falls back to DejaVu for unknown font."
  (let ((fm (make-instance 'font-manager)))
    (let ((path (find-font fm :family "NonExistentFontXYZ123")))
      (is-true path "find-font returned NIL for unknown font (should fallback)"))))

(test make-font-properties-defaults
  "make-font-properties creates with correct defaults."
  (let ((fp (make-font-properties)))
    (is (equal '("sans-serif") (font-properties-family fp)))
    (is (string= "normal" (font-properties-style fp)))
    (is (= 400 (font-properties-weight fp)))
    (is (= 10.0d0 (font-properties-size fp)))))

(test make-font-properties-bold
  "make-font-properties converts weight 'bold' to 700."
  (let ((fp (make-font-properties :weight "bold")))
    (is (= 700 (font-properties-weight fp)))))

;;; ============================================================
;;; Font Loading Tests
;;; ============================================================

(test load-font-dejavu
  "load-font can load DejaVu Sans."
  (let ((cl-matplotlib.rendering::*font-manager* nil))
    (let ((font (load-font "DejaVu Sans")))
      (is-true font "load-font returned NIL")
      ;; Check it's a zpb-ttf font-loader
      (is-true (zpb-ttf:family-name font) "No family name"))))

(test load-font-by-path-works
  "load-font-by-path loads a font from explicit path."
  (let ((cl-matplotlib.rendering::*font-manager* nil)
        (path (namestring (dejavu-font-path))))
    (let ((font (load-font-by-path path)))
      (is-true font "load-font-by-path returned NIL")
      (is (string= "DejaVu Sans" (zpb-ttf:family-name font))))))

;;; ============================================================
;;; Font Metrics Tests
;;; ============================================================

(test glyph-advance-width-positive
  "get-glyph-advance-width returns positive value for 'A'."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((width (get-glyph-advance-width font #\A)))
          (is (> width 0) "Advance width for 'A' should be positive, got ~A" width))
      (zpb-ttf:close-font-loader font))))

(test font-units-per-em
  "get-font-units-per-em returns a positive integer."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((upm (get-font-units-per-em font)))
          (is (> upm 0) "Units per em should be positive, got ~A" upm))
      (zpb-ttf:close-font-loader font))))

(test font-ascender-positive
  "get-font-ascender returns a positive value."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((asc (get-font-ascender font)))
          (is (> asc 0) "Ascender should be positive, got ~A" asc))
      (zpb-ttf:close-font-loader font))))

(test font-descender-negative
  "get-font-descender returns a negative value."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((desc (get-font-descender font)))
          (is (< desc 0) "Descender should be negative, got ~A" desc))
      (zpb-ttf:close-font-loader font))))

(test text-extents-hello
  "get-text-extents returns positive width/height for 'Hello'."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((extents (get-text-extents "Hello" font 12)))
          (is (> (bbox-width extents) 0) "Width should be positive")
          (is (> (bbox-height extents) 0) "Height should be positive"))
      (zpb-ttf:close-font-loader font))))

(test text-extents-empty
  "get-text-extents handles empty string."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((extents (get-text-extents "" font 12)))
          (is-true extents "Should return a bbox even for empty string"))
      (zpb-ttf:close-font-loader font))))

(test text-width-height-descent
  "get-text-width-height-descent returns 3 values."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (multiple-value-bind (w h d)
            (get-text-width-height-descent "Hello" font 12)
          (is (> w 0) "Width should be positive")
          (is (> h 0) "Height should be positive")
          (is (>= d 0) "Descent should be non-negative"))
      (zpb-ttf:close-font-loader font))))

(test font-units-to-points-conversion
  "font-units-to-points converts correctly."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let* ((upm (get-font-units-per-em font))
               (pts (font-units-to-points upm font 12)))
          (is (= 12.0d0 pts) "1 em at 12pt should be 12pt, got ~A" pts))
      (zpb-ttf:close-font-loader font))))

;;; ============================================================
;;; Text-to-Path Tests
;;; ============================================================

(test text-to-path-single-char
  "text-to-path returns a path for a single character."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((paths (text-to-path "A" font 12)))
          (is-true (listp paths) "Should return a list")
          (is (> (length paths) 0) "Should have at least one path")
          (is (typep (first paths) 'mpl-path) "Should be an mpl-path"))
      (zpb-ttf:close-font-loader font))))

(test text-to-path-hello
  "text-to-path returns paths for 'Hello'."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((paths (text-to-path "Hello" font 12)))
          (is-true (listp paths))
          ;; Each visible character should produce a path
          ;; (some chars like space may not produce paths)
          (is (> (length paths) 0) "Should have paths for 'Hello'"))
      (zpb-ttf:close-font-loader font))))

(test text-to-path-space-only
  "text-to-path returns empty list for space-only string."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((paths (text-to-path " " font 12)))
          (is-true (listp paths))
          ;; Space has no outlines
          (is (= 0 (length paths)) "Space should produce no paths"))
      (zpb-ttf:close-font-loader font))))

(test text-to-path-empty
  "text-to-path returns empty list for empty string."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((paths (text-to-path "" font 12)))
          (is-true (listp paths))
          (is (= 0 (length paths))))
      (zpb-ttf:close-font-loader font))))

(test text-to-compound-path-works
  "text-to-compound-path returns a single path."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((path (text-to-compound-path "Hello" font 12)))
          (is (typep path 'mpl-path) "Should be an mpl-path")
          (is (> (path-length path) 0) "Compound path should have vertices"))
      (zpb-ttf:close-font-loader font))))

(test text-to-path-positioning
  "text-to-path places glyphs at correct x positions."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((paths-0 (text-to-path "A" font 12 0.0d0 0.0d0))
              (paths-100 (text-to-path "A" font 12 100.0d0 0.0d0)))
          ;; The second should be shifted right
          (when (and paths-0 paths-100)
            (let ((x0-min (aref (mpl-path-vertices (first paths-0)) 0 0))
                  (x100-min (aref (mpl-path-vertices (first paths-100)) 0 0)))
              (is (> x100-min x0-min) "Offset path should be further right"))))
      (zpb-ttf:close-font-loader font))))

;;; ============================================================
;;; Multi-line text layout tests
;;; ============================================================

(test multiline-layout-basic
  "layout-multiline-text returns entries for each line."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((layout (layout-multiline-text (format nil "Line 1~%Line 2") font 12)))
          (is (= 2 (length layout)) "Should have 2 lines"))
      (zpb-ttf:close-font-loader font))))

(test multiline-layout-single-line
  "layout-multiline-text handles single line."
  (let ((font (zpb-ttf:open-font-loader (namestring (dejavu-font-path)))))
    (unwind-protect
        (let ((layout (layout-multiline-text "Hello" font 12)))
          (is (= 1 (length layout)) "Should have 1 line"))
      (zpb-ttf:close-font-loader font))))

;;; ============================================================
;;; AFM Parser Tests
;;; ============================================================

(defun create-test-afm-file ()
  "Create a minimal AFM file for testing. Returns the path."
  (let ((path (merge-pathnames "test-font.afm" (uiop:temporary-directory))))
    (with-open-file (out path :direction :output
                              :if-exists :supersede
                              :if-does-not-exist :create)
      (format out "StartFontMetrics 4.1~%")
      (format out "FontName TestFont-Regular~%")
      (format out "FullName Test Font Regular~%")
      (format out "FamilyName Test Font~%")
      (format out "Weight Medium~%")
      (format out "ItalicAngle 0~%")
      (format out "IsFixedPitch false~%")
      (format out "FontBBox -166 -225 1000 931~%")
      (format out "UnderlinePosition -100~%")
      (format out "UnderlineThickness 50~%")
      (format out "CapHeight 718~%")
      (format out "XHeight 523~%")
      (format out "Ascender 800~%")
      (format out "Descender -200~%")
      (format out "StartCharMetrics 3~%")
      (format out "C 32 ; WX 278 ; N space ; B 0 0 0 0 ;~%")
      (format out "C 65 ; WX 667 ; N A ; B 14 0 654 718 ;~%")
      (format out "C 66 ; WX 667 ; N B ; B 74 0 627 718 ;~%")
      (format out "EndCharMetrics~%")
      (format out "StartKernData~%")
      (format out "StartKernPairs 1~%")
      (format out "KPX A B -50~%")
      (format out "EndKernPairs~%")
      (format out "EndKernData~%")
      (format out "EndFontMetrics~%"))
    path))

(test afm-parse-test-file
  "parse-afm-file successfully parses a test AFM file."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is-true afm "parse-afm-file returned NIL")
    ;; Clean up
    (delete-file path)))

(test afm-fontname
  "AFM fontname is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (string= "TestFont-Regular" (afm-get-fontname afm)))
    (delete-file path)))

(test afm-familyname
  "AFM family name is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (string= "Test Font" (afm-get-familyname afm)))
    (delete-file path)))

(test afm-weight
  "AFM weight is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (string= "Medium" (afm-get-weight afm)))
    (delete-file path)))

(test afm-angle
  "AFM italic angle is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (= 0.0d0 (afm-get-angle afm)))
    (delete-file path)))

(test afm-ascender-descender
  "AFM ascender and descender are correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (= 800.0d0 (afm-get-ascender afm)))
    (is (= -200.0d0 (afm-get-descender afm)))
    (delete-file path)))

(test afm-capheight
  "AFM cap height is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (= 718.0d0 (afm-get-capheight afm)))
    (delete-file path)))

(test afm-xheight
  "AFM x-height is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (= 523.0d0 (afm-get-xheight afm)))
    (delete-file path)))

(test afm-bbox
  "AFM font bounding box is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (equal '(-166 -225 1000 931) (afm-get-bbox afm)))
    (delete-file path)))

(test afm-char-width
  "AFM character width is correctly extracted."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (= 278.0d0 (afm-get-char-width afm 32)))  ; space
    (is (= 667.0d0 (afm-get-char-width afm 65)))  ; A
    (delete-file path)))

(test afm-width-from-name
  "AFM width from name works."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (= 667.0d0 (afm-get-width-from-name afm "A")))
    (is (= 278.0d0 (afm-get-width-from-name afm "space")))
    (delete-file path)))

(test afm-kern-dist
  "AFM kern pairs are correctly parsed."
  (let* ((path (create-test-afm-file))
         (afm (parse-afm-file path)))
    (is (= -50.0d0 (afm-get-kern-dist afm "A" "B")))
    (is (= 0.0d0 (afm-get-kern-dist afm "B" "A")))  ; No reverse kern
    (delete-file path)))

(test afm-unicode-to-type1-mapping
  "afm-unicode-to-type1-name maps correctly."
  (is (string= "A" (afm-unicode-to-type1-name 65)))
  (is (string= "space" (afm-unicode-to-type1-name 32)))
  (is (string= "exclam" (afm-unicode-to-type1-name 33)))
  (is (string= "uni0100" (afm-unicode-to-type1-name 256))))

;;; ============================================================
;;; Acceptance scenario from plan
;;; ============================================================

(test acceptance-font-loading-and-metrics
  "Acceptance scenario: font loading, glyph metrics, text extents, text-to-path."
  (let ((cl-matplotlib.rendering::*font-manager* nil))
    ;; Load DejaVu Sans TTF via zpb-ttf
    (let ((font (load-font "DejaVu Sans")))
      ;; Get glyph for "A" — Assert advance width > 0
      (let ((glyph-width (get-glyph-advance-width font (char-code #\A))))
        (is (> glyph-width 0) "Glyph advance width for 'A' should be > 0"))
      ;; Get text extents for "Hello" at 12pt — Assert width > 0, height > 0
      (let ((extents (get-text-extents "Hello" font 12)))
        (is (> (bbox-width extents) 0) "Text width should be > 0")
        (is (> (bbox-height extents) 0) "Text height should be > 0"))
      ;; Convert "Hello" to paths — Assert list of path objects returned
      (let ((paths (text-to-path "Hello" font 12 0 0)))
        (is-true (listp paths) "Should return a list")
        (is (> (length paths) 0) "Should have > 0 paths")
        (is (typep (first paths) 'mpl-path) "First element should be mpl-path")))))
